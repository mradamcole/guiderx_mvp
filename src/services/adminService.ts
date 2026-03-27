import { PoolClient } from "pg";
import { pool } from "../db/pool";
import { withTransaction } from "../db/transaction";
import {
  AdminDbStatusResponse,
  AdminPaperCreatePayload,
  AdminPaperListQuery
} from "../validation/schemas";
import { ingestEvidenceWithClient } from "./ingestionService";

type CreatePaperResult = {
  paperId: string;
  studyIds: string[];
};

type ListPaperItem = {
  paperId: string;
  title: string;
  doi: string | null;
  url: string | null;
  retrievalDate: string | null;
  isPeerReviewed: boolean | null;
  altmetricScore: number | null;
  journalName: string | null;
  publisherName: string | null;
  authors: {
    name: string;
    orcid: string | null;
    authorOrder: number | null;
    isCorresponding: boolean;
  }[];
  studyCount: number;
};

export class AdminConflictError extends Error {
  constructor(message: string) {
    super(message);
    this.name = "AdminConflictError";
  }
}

export async function getDbStatus(): Promise<AdminDbStatusResponse> {
  const startNs = process.hrtime.bigint();
  await pool.query("SELECT 1");
  const elapsedNs = process.hrtime.bigint() - startNs;
  const latencyMs = Number(elapsedNs) / 1_000_000;

  const countsResult = await pool.query<{
    papers: string;
    studies: string;
    authors: string;
    outcomes: string;
  }>(`
    SELECT
      (SELECT COUNT(*)::text FROM Paper) AS papers,
      (SELECT COUNT(*)::text FROM Study) AS studies,
      (SELECT COUNT(*)::text FROM Author) AS authors,
      (SELECT COUNT(*)::text FROM Outcome) AS outcomes
  `);

  return {
    status: "ok",
    databaseConnected: true,
    latencyMs,
    counts: {
      papers: Number(countsResult.rows[0].papers),
      studies: Number(countsResult.rows[0].studies),
      authors: Number(countsResult.rows[0].authors),
      outcomes: Number(countsResult.rows[0].outcomes)
    }
  };
}

export async function listPapers(query: AdminPaperListQuery): Promise<ListPaperItem[]> {
  const papersResult = await pool.query<{
    paper_id: string;
    title: string;
    doi: string | null;
    url: string | null;
    retrieval_date: string | null;
    is_peer_reviewed: boolean | null;
    altmetric_score: number | null;
    journal_name: string | null;
    publisher_name: string | null;
    study_count: string;
  }>(
    `
    SELECT
      p.paper_id,
      p.title,
      p.doi,
      p.url,
      p.retrieval_date::text AS retrieval_date,
      p.is_peer_reviewed,
      p.altmetric_score,
      j.name AS journal_name,
      pub.name AS publisher_name,
      COUNT(psm.study_id)::text AS study_count
    FROM Paper p
    LEFT JOIN Journal j ON j.journal_id = p.journal_id
    LEFT JOIN Publisher pub ON pub.publisher_id = p.publisher_id
    LEFT JOIN PaperStudyMap psm ON psm.paper_id = p.paper_id
    WHERE
      $1::text IS NULL
      OR p.title ILIKE '%' || $1::text || '%'
      OR p.doi ILIKE '%' || $1::text || '%'
      OR j.name ILIKE '%' || $1::text || '%'
      OR pub.name ILIKE '%' || $1::text || '%'
      OR EXISTS (
        SELECT 1
        FROM PaperAuthor pa
        JOIN Author a ON a.author_id = pa.author_id
        WHERE pa.paper_id = p.paper_id
          AND a.name ILIKE '%' || $1::text || '%'
      )
    GROUP BY
      p.paper_id,
      p.title,
      p.doi,
      p.url,
      p.retrieval_date,
      p.is_peer_reviewed,
      p.altmetric_score,
      j.name,
      pub.name
    ORDER BY p.retrieval_date DESC NULLS LAST, p.paper_id DESC
    LIMIT $2
    OFFSET $3
    `,
    [query.search ?? null, query.limit, query.offset]
  );

  if (papersResult.rows.length === 0) {
    return [];
  }

  const paperIds = papersResult.rows.map((row) => row.paper_id);
  const authorsResult = await pool.query<{
    paper_id: string;
    name: string;
    orcid: string | null;
    author_order: number | null;
    is_corresponding: boolean;
  }>(
    `
    SELECT
      pa.paper_id,
      a.name,
      a.orcid,
      pa.author_order,
      pa.is_corresponding
    FROM PaperAuthor pa
    JOIN Author a ON a.author_id = pa.author_id
    WHERE pa.paper_id = ANY($1::uuid[])
    ORDER BY pa.paper_id, pa.author_order ASC NULLS LAST, a.name ASC
    `,
    [paperIds]
  );

  const authorsByPaper = new Map<string, ListPaperItem["authors"]>();
  for (const row of authorsResult.rows) {
    const list = authorsByPaper.get(row.paper_id) ?? [];
    list.push({
      name: row.name,
      orcid: row.orcid,
      authorOrder: row.author_order,
      isCorresponding: row.is_corresponding
    });
    authorsByPaper.set(row.paper_id, list);
  }

  return papersResult.rows.map((row) => ({
    paperId: row.paper_id,
    title: row.title,
    doi: row.doi,
    url: row.url,
    retrievalDate: row.retrieval_date,
    isPeerReviewed: row.is_peer_reviewed,
    altmetricScore: row.altmetric_score,
    journalName: row.journal_name,
    publisherName: row.publisher_name,
    studyCount: Number(row.study_count),
    authors: authorsByPaper.get(row.paper_id) ?? []
  }));
}

export async function createPaper(payload: AdminPaperCreatePayload): Promise<CreatePaperResult> {
  try {
    return await withTransaction(pool, async (client) => {
      const journalId = payload.paper.journalName
        ? await upsertJournal(client, payload.paper.journalName)
        : null;
      const publisherId = payload.paper.publisherName
        ? await upsertPublisher(client, payload.paper.publisherName)
        : null;

      const paperResult = await client.query<{ paper_id: string }>(
        `
        INSERT INTO Paper (
          title,
          doi,
          url,
          journal_id,
          publisher_id,
          is_peer_reviewed,
          altmetric_score
        )
        VALUES ($1, $2, $3, $4, $5, $6, $7)
        RETURNING paper_id
        `,
        [
          payload.paper.title,
          payload.paper.doi ?? null,
          payload.paper.url ?? null,
          journalId,
          publisherId,
          payload.paper.isPeerReviewed ?? true,
          payload.paper.altmetricScore ?? null
        ]
      );

      const paperId = paperResult.rows[0].paper_id;

      for (const author of payload.authors) {
        const authorId = await resolveAuthor(client, author.name, author.orcid ?? null);
        await client.query(
          `
          INSERT INTO PaperAuthor (paper_id, author_id, author_order, is_corresponding)
          VALUES ($1, $2, $3, $4)
          ON CONFLICT (paper_id, author_id)
          DO UPDATE SET
            author_order = EXCLUDED.author_order,
            is_corresponding = EXCLUDED.is_corresponding
          `,
          [paperId, authorId, author.authorOrder ?? null, author.isCorresponding ?? false]
        );
      }

      const studyIds: string[] = [];
      for (let index = 0; index < payload.ingestions.length; index += 1) {
        const ingestion = payload.ingestions[index];
        const ingested = await ingestEvidenceWithClient(client, ingestion);
        studyIds.push(ingested.studyId);

        await client.query(
          `
          INSERT INTO PaperStudyMap (paper_id, study_id, relationship_type)
          VALUES ($1, $2, $3)
          ON CONFLICT (paper_id, study_id)
          DO UPDATE SET relationship_type = EXCLUDED.relationship_type
          `,
          [paperId, ingested.studyId, index === 0 ? "primary_publication" : "supporting_publication"]
        );
      }

      return { paperId, studyIds };
    });
  } catch (error) {
    if (isDoiConflict(error)) {
      throw new AdminConflictError("A paper with this DOI already exists.");
    }
    throw error;
  }
}

async function upsertJournal(client: PoolClient, name: string): Promise<string> {
  const result = await client.query<{ journal_id: string }>(
    `
    INSERT INTO Journal (name)
    VALUES ($1)
    ON CONFLICT (name)
    DO UPDATE SET name = EXCLUDED.name
    RETURNING journal_id
    `,
    [name]
  );
  return result.rows[0].journal_id;
}

async function upsertPublisher(client: PoolClient, name: string): Promise<string> {
  const result = await client.query<{ publisher_id: string }>(
    `
    INSERT INTO Publisher (name)
    VALUES ($1)
    ON CONFLICT (name)
    DO UPDATE SET name = EXCLUDED.name
    RETURNING publisher_id
    `,
    [name]
  );
  return result.rows[0].publisher_id;
}

async function resolveAuthor(client: PoolClient, name: string, orcid: string | null): Promise<string> {
  if (orcid) {
    const byOrcid = await client.query<{ author_id: string }>(
      `
      INSERT INTO Author (name, orcid)
      VALUES ($1, $2)
      ON CONFLICT (orcid)
      DO UPDATE SET name = EXCLUDED.name
      RETURNING author_id
      `,
      [name, orcid]
    );
    return byOrcid.rows[0].author_id;
  }

  const byName = await client.query<{ author_id: string }>(
    `
    WITH existing AS (
      SELECT author_id
      FROM Author
      WHERE name = $1
        AND orcid IS NULL
      ORDER BY author_id
      LIMIT 1
    ),
    inserted AS (
      INSERT INTO Author (name, orcid)
      SELECT $1, NULL
      WHERE NOT EXISTS (SELECT 1 FROM existing)
      RETURNING author_id
    )
    SELECT author_id FROM existing
    UNION ALL
    SELECT author_id FROM inserted
    LIMIT 1
    `,
    [name]
  );

  return byName.rows[0].author_id;
}

function isDoiConflict(error: unknown): boolean {
  if (!error || typeof error !== "object") {
    return false;
  }
  const maybeCode = (error as { code?: string }).code;
  const maybeConstraint = (error as { constraint?: string }).constraint;
  return maybeCode === "23505" && maybeConstraint === "paper_doi_key";
}

export type { CreatePaperResult, ListPaperItem };
