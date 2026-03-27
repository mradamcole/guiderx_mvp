import { pool } from "../../src/db/pool";
import { clearRecommendationGraph, createRecommendationFixture } from "../setup/dbTestUtils";

describe("database cascade and traceability constraints", () => {
  beforeEach(async () => {
    await clearRecommendationGraph();
  });

  it("cascades recommendation deletion to rule, instance, and evidence trace", async () => {
    const fixture = await createRecommendationFixture();

    await pool.query(
      `
      INSERT INTO RecommendationRule (recommendation_id, rule_type, logic_json, priority)
      VALUES ($1, 'inclusion', '{"age": {"min": 21}}', 1)
      `,
      [fixture.recommendationId]
    );

    const instanceResult = await pool.query<{ instance_id: string }>(
      `
      INSERT INTO RecommendationInstance (recommendation_id, evidence_score, confidence_level, algorithm_version)
      VALUES ($1, 0.82, 'Moderate', 'test-algo')
      RETURNING instance_id
      `,
      [fixture.recommendationId]
    );

    await pool.query(
      `
      INSERT INTO RecommendationExplanation (instance_id, evidence_summary)
      VALUES ($1, 'Moderate evidence from synthetic fixture')
      `,
      [instanceResult.rows[0].instance_id]
    );

    await pool.query(
      `
      INSERT INTO EvidenceTrace (recommendation_id, clinical_finding_id)
      VALUES ($1, $2)
      `,
      [fixture.recommendationId, fixture.clinicalFindingId]
    );

    await pool.query(`DELETE FROM Recommendation WHERE recommendation_id = $1`, [fixture.recommendationId]);

    const counts = await pool.query<{ table_name: string; row_count: string }>(
      `
      SELECT table_name, row_count
      FROM (
        SELECT 'RecommendationRule'::text AS table_name, COUNT(*)::text AS row_count FROM RecommendationRule
        UNION ALL
        SELECT 'RecommendationInstance', COUNT(*)::text FROM RecommendationInstance
        UNION ALL
        SELECT 'EvidenceTrace', COUNT(*)::text FROM EvidenceTrace
      ) x
      `
    );

    for (const row of counts.rows) {
      expect(Number(row.row_count)).toBe(0);
    }
  });
});
