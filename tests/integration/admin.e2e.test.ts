import request from "supertest";
import { createApp } from "../../src/app";
import { pool } from "../../src/db/pool";
import { llmRouter } from "../../src/llm";
import { clearAdminPaperGraph } from "../setup/dbTestUtils";

function buildPayload(overrides?: Partial<Record<string, unknown>>) {
  return {
    paper: {
      title: "Cannabis Trial for Neuropathic Pain",
      doi: "10.1000/grx-admin-001",
      journalName: "Clinical Evidence Journal",
      publisherName: "GuideRx Press",
      isPeerReviewed: true
    },
    authors: [{ name: "Ada Lovelace", authorOrder: 1 }],
    ingestions: [
      {
        concept: {
          system: "Custom",
          code: "ADMIN_CONCEPT_1",
          displayText: "Neuropathic pain"
        },
        study: {
          name: "ADMIN Study 1",
          studyTypeName: "RCT",
          sampleSize: 120,
          sponsor: "GuideRx"
        },
        arm: {
          armType: "intervention",
          size: 60,
          productName: "Admin Product A"
        },
        outcome: {
          effectSize: 0.35,
          effectType: "SMD",
          pValue: 0.02,
          timepoint: "8 weeks",
          summary: "Improved pain score versus comparator"
        }
      }
    ],
    ...overrides
  };
}

describe("admin console APIs", () => {
  const app = createApp();

  beforeEach(async () => {
    await clearAdminPaperGraph();
  });

  afterEach(() => {
    vi.restoreAllMocks();
  });

  it("returns database status with connectivity and key table counts", async () => {
    const response = await request(app).get("/api/admin/db-status");

    expect(response.status).toBe(200);
    expect(response.body.data.status).toBe("ok");
    expect(response.body.data.databaseConnected).toBe(true);
    expect(typeof response.body.data.latencyMs).toBe("number");
    expect(response.body.data.counts).toEqual(
      expect.objectContaining({
        papers: expect.any(Number),
        studies: expect.any(Number),
        authors: expect.any(Number),
        outcomes: expect.any(Number)
      })
    );
  });

  it("creates paper + ingestion rows and returns them from listing", async () => {
    const createResponse = await request(app).post("/api/admin/papers").send(buildPayload());

    expect(createResponse.status).toBe(201);
    expect(createResponse.body.data.paperId).toBeTruthy();
    expect(createResponse.body.data.studyIds).toHaveLength(1);

    const listResponse = await request(app).get("/api/admin/papers").query({
      limit: 10,
      offset: 0,
      search: "Neuropathic"
    });

    expect(listResponse.status).toBe(200);
    expect(listResponse.body.data).toHaveLength(1);
    expect(listResponse.body.data[0]).toEqual(
      expect.objectContaining({
        title: "Cannabis Trial for Neuropathic Pain",
        doi: "10.1000/grx-admin-001",
        journalName: "Clinical Evidence Journal",
        publisherName: "GuideRx Press",
        studyCount: 1
      })
    );
    expect(listResponse.body.data[0].authors[0].name).toBe("Ada Lovelace");
  });

  it("returns 409 when DOI already exists", async () => {
    const payload = buildPayload();
    const first = await request(app).post("/api/admin/papers").send(payload);
    expect(first.status).toBe(201);

    const second = await request(app).post("/api/admin/papers").send(
      buildPayload({
        paper: {
          title: "Another publication title",
          doi: "10.1000/grx-admin-001",
          journalName: "Clinical Evidence Journal",
          publisherName: "GuideRx Press"
        }
      })
    );

    expect(second.status).toBe(409);
    expect(second.body.error).toBe("ConflictError");
  });

  it("rolls back transaction if ingestion fails after paper insert", async () => {
    const overflowSampleSize = 3_000_000_000;
    const response = await request(app).post("/api/admin/papers").send(
      buildPayload({
        paper: {
          title: "Should Roll Back",
          doi: "10.1000/grx-admin-rollback-1",
          journalName: "Rollback Journal",
          publisherName: "Rollback Publisher"
        },
        ingestions: [
          {
            concept: {
              system: "Custom",
              code: "ROLLBACK_CONCEPT_1",
              displayText: "Rollback concept"
            },
            study: {
              name: "Rollback Study",
              sampleSize: overflowSampleSize
            },
            arm: { armType: "intervention" },
            outcome: {}
          }
        ]
      })
    );

    expect(response.status).toBe(500);

    const paperCount = await pool.query<{ count: string }>(
      `SELECT COUNT(*)::text AS count FROM Paper WHERE doi = '10.1000/grx-admin-rollback-1'`
    );
    const studyCount = await pool.query<{ count: string }>(
      `SELECT COUNT(*)::text AS count FROM Study WHERE name = 'Rollback Study'`
    );
    const mapCount = await pool.query<{ count: string }>(
      `SELECT COUNT(*)::text AS count FROM PaperStudyMap`
    );

    expect(Number(paperCount.rows[0].count)).toBe(0);
    expect(Number(studyCount.rows[0].count)).toBe(0);
    expect(Number(mapCount.rows[0].count)).toBe(0);
  });

  it("extracts draft fields from uploaded paper text", async () => {
    vi.spyOn(llmRouter, "generate").mockResolvedValue({
      provider: "openai",
      model: "test-model",
      text: JSON.stringify({
        paper: {
          title: "Extracted Paper Title",
          doi: "10.1000/extracted-001",
          journalName: "Extracted Journal"
        },
        authors: [{ name: "Extracted Author", authorOrder: 1 }],
        ingestion: {
          concept: { system: "Custom", code: "EXTRACT_CODE", displayText: "Extracted concept" },
          study: { name: "Extracted Study" },
          arm: { armType: "intervention", productName: "Extracted Product" },
          outcome: { summary: "Extracted outcome summary" }
        },
        confidence: 0.83,
        notes: ["Derived from abstract and methods"]
      }),
      raw: {}
    });

    const response = await request(app)
      .post("/api/admin/papers/extract")
      .attach(
        "paper",
        Buffer.from("Title: Extracted Paper Title\nDOI: 10.1000/extracted-001"),
        "paper.txt"
      );

    expect(response.status).toBe(200);
    expect(response.body.data.paper.title).toBe("Extracted Paper Title");
    expect(response.body.data.authors[0].name).toBe("Extracted Author");
    expect(response.body.data.ingestion.study.name).toBe("Extracted Study");
  });
});
