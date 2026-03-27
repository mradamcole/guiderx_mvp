import { PoolClient } from "pg";
import { pool } from "../db/pool";
import { withTransaction } from "../db/transaction";
import { IngestionPayload } from "../validation/schemas";

type IngestionResult = {
  conceptId: string;
  studyId: string;
  armId: string;
  outcomeId: string;
  productId: string | null;
};

export async function ingestEvidence(payload: IngestionPayload): Promise<IngestionResult> {
  return withTransaction(pool, async (client: PoolClient) => {
    const concept = await client.query<{ concept_id: string }>(
      `
      INSERT INTO Concept (system, code, display_text)
      VALUES ($1, $2, $3)
      ON CONFLICT (system, code)
      DO UPDATE SET display_text = EXCLUDED.display_text
      RETURNING concept_id
      `,
      [payload.concept.system, payload.concept.code, payload.concept.displayText]
    );

    let studyTypeId: string | null = null;
    if (payload.study.studyTypeName) {
      const studyTypeResult = await client.query<{ study_type_id: string }>(
        `
        WITH inserted AS (
          INSERT INTO StudyType (name)
          SELECT $1::VARCHAR(100)
          WHERE NOT EXISTS (SELECT 1 FROM StudyType WHERE name = $1::VARCHAR(100))
          RETURNING study_type_id
        )
        SELECT study_type_id FROM inserted
        UNION ALL
        SELECT study_type_id FROM StudyType WHERE name = $1::VARCHAR(100)
        LIMIT 1
        `,
        [payload.study.studyTypeName]
      );
      studyTypeId = studyTypeResult.rows[0]?.study_type_id ?? null;
    }

    const study = await client.query<{ study_id: string }>(
      `
      INSERT INTO Study (name, study_type_id, sample_size, sponsor)
      VALUES ($1, $2, $3, $4)
      RETURNING study_id
      `,
      [payload.study.name, studyTypeId, payload.study.sampleSize ?? null, payload.study.sponsor ?? null]
    );

    let productId: string | null = null;
    if (payload.arm.productName) {
      const product = await client.query<{ product_id: string }>(
        `
        WITH inserted AS (
          INSERT INTO Product (name)
          SELECT $1::VARCHAR(255)
          WHERE NOT EXISTS (SELECT 1 FROM Product WHERE name = $1::VARCHAR(255))
          RETURNING product_id
        )
        SELECT product_id FROM inserted
        UNION ALL
        SELECT product_id FROM Product WHERE name = $1::VARCHAR(255)
        LIMIT 1
        `,
        [payload.arm.productName]
      );
      productId = product.rows[0]?.product_id ?? null;
    }

    const arm = await client.query<{ arm_id: string }>(
      `
      INSERT INTO Arm (study_id, arm_type, size, product_id)
      VALUES ($1, $2, $3, $4)
      RETURNING arm_id
      `,
      [study.rows[0].study_id, payload.arm.armType, payload.arm.size ?? null, productId]
    );

    const outcome = await client.query<{ outcome_id: string }>(
      `
      INSERT INTO Outcome (
        arm_id,
        concept_id,
        effect_size,
        effect_type,
        p_value,
        timepoint,
        summary
      )
      VALUES ($1, $2, $3, $4, $5, $6, $7)
      RETURNING outcome_id
      `,
      [
        arm.rows[0].arm_id,
        concept.rows[0].concept_id,
        payload.outcome.effectSize ?? null,
        payload.outcome.effectType ?? null,
        payload.outcome.pValue ?? null,
        payload.outcome.timepoint ?? null,
        payload.outcome.summary ?? null
      ]
    );

    return {
      conceptId: concept.rows[0].concept_id,
      studyId: study.rows[0].study_id,
      armId: arm.rows[0].arm_id,
      outcomeId: outcome.rows[0].outcome_id,
      productId
    };
  });
}
