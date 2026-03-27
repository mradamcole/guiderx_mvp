import { pool } from "../../src/db/pool";

export async function clearRecommendationGraph() {
  await pool.query(`
    TRUNCATE TABLE
      SafetyAlert,
      RecommendationExplanation,
      RecommendationInstance,
      RecommendationRule,
      EvidenceTrace,
      Recommendation,
      ClinicalFinding,
      SafetyRule,
      PatientContext,
      Product,
      Concept
    CASCADE
  `);
}

export async function createRecommendationFixture() {
  const conceptResult = await pool.query<{ concept_id: string }>(
    `
    INSERT INTO Concept (system, code, display_text)
    VALUES ('Custom', 'TEST_CONCEPT', 'Test Concept')
    RETURNING concept_id
    `
  );

  const productResult = await pool.query<{ product_id: string }>(
    `
    INSERT INTO Product (name, format, route, description)
    VALUES ('Test Product', 'oil', 'oral', 'Test Product Description')
    RETURNING product_id
    `
  );

  const recommendationResult = await pool.query<{ recommendation_id: string }>(
    `
    INSERT INTO Recommendation (concept_id, product_id, title, clinical_intent, recommendation_text, version)
    VALUES ($1, $2, 'Test Rec', 'reduce symptoms', 'Use carefully', 'v1')
    RETURNING recommendation_id
    `,
    [conceptResult.rows[0].concept_id, productResult.rows[0].product_id]
  );

  const findingResult = await pool.query<{ clinical_finding_id: string }>(
    `
    INSERT INTO ClinicalFinding (concept_id, product_id, effect_direction, aggregate_certainty)
    VALUES ($1, $2, 'benefit', 'Moderate')
    RETURNING clinical_finding_id
    `,
    [conceptResult.rows[0].concept_id, productResult.rows[0].product_id]
  );

  const safetyRuleResult = await pool.query<{ safety_rule_id: string }>(
    `
    INSERT INTO SafetyRule (product_id, concept_id, severity, rule_logic, description)
    VALUES ($1, $2, 'warning', '{"history": ["psychosis"]}', 'Test safety rule')
    RETURNING safety_rule_id
    `,
    [productResult.rows[0].product_id, conceptResult.rows[0].concept_id]
  );

  return {
    recommendationId: recommendationResult.rows[0].recommendation_id,
    clinicalFindingId: findingResult.rows[0].clinical_finding_id,
    safetyRuleId: safetyRuleResult.rows[0].safety_rule_id
  };
}
