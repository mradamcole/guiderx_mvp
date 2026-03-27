import { PoolClient } from "pg";
import { pool } from "../db/pool";
import { withTransaction } from "../db/transaction";
import { RecommendationGenerationPayload } from "../validation/schemas";

type RecommendationInstanceResult = {
  instanceId: string;
  contextId: string | null;
  evidenceTraceCount: number;
  safetyAlertCount: number;
};

export async function generateRecommendationInstance(
  payload: RecommendationGenerationPayload
): Promise<RecommendationInstanceResult> {
  return withTransaction(pool, async (client: PoolClient) => {
    let contextId: string | null = null;

    if (payload.context) {
      const contextResult = await client.query<{ context_id: string }>(
        `
        INSERT INTO PatientContext (
          age,
          sex,
          diagnoses,
          symptoms,
          current_medications,
          contraindications
        )
        VALUES ($1, $2, $3::jsonb, $4::jsonb, $5::jsonb, $6::jsonb)
        RETURNING context_id
        `,
        [
          payload.context.age ?? null,
          payload.context.sex ?? null,
          JSON.stringify(payload.context.diagnoses ?? []),
          JSON.stringify(payload.context.symptoms ?? []),
          JSON.stringify(payload.context.currentMedications ?? []),
          JSON.stringify(payload.context.contraindications ?? [])
        ]
      );
      contextId = contextResult.rows[0].context_id;
    }

    const instanceResult = await client.query<{ instance_id: string }>(
      `
      INSERT INTO RecommendationInstance (
        recommendation_id,
        context_id,
        evidence_score,
        confidence_level,
        algorithm_version
      )
      VALUES ($1, $2, $3, $4, $5)
      RETURNING instance_id
      `,
      [
        payload.recommendationId,
        contextId,
        payload.evidenceScore ?? null,
        payload.confidenceLevel ?? null,
        payload.algorithmVersion ?? null
      ]
    );

    const instanceId = instanceResult.rows[0].instance_id;

    await client.query(
      `
      INSERT INTO RecommendationExplanation (
        instance_id,
        evidence_summary,
        benefit_summary,
        risk_summary,
        certainty_explanation
      )
      VALUES ($1, $2, $3, $4, $5)
      `,
      [
        instanceId,
        payload.evidenceSummary ?? null,
        payload.benefitSummary ?? null,
        payload.riskSummary ?? null,
        payload.certaintyExplanation ?? null
      ]
    );

    for (const clinicalFindingId of payload.clinicalFindingIds) {
      await client.query(
        `
        INSERT INTO EvidenceTrace (recommendation_id, clinical_finding_id)
        VALUES ($1, $2)
        `,
        [payload.recommendationId, clinicalFindingId]
      );
    }

    for (const alert of payload.safetyAlerts) {
      await client.query(
        `
        INSERT INTO SafetyAlert (instance_id, safety_rule_id, alert_text, severity)
        VALUES ($1, $2, $3, $4)
        `,
        [instanceId, alert.safetyRuleId, alert.alertText, alert.severity]
      );
    }

    return {
      instanceId,
      contextId,
      evidenceTraceCount: payload.clinicalFindingIds.length,
      safetyAlertCount: payload.safetyAlerts.length
    };
  });
}

export async function getRecommendationInstance(instanceId: string) {
  const instanceResult = await pool.query(
    `
    SELECT
      ri.instance_id,
      ri.recommendation_id,
      ri.context_id,
      ri.generated_at,
      ri.evidence_score,
      ri.confidence_level,
      ri.algorithm_version,
      re.evidence_summary,
      re.benefit_summary,
      re.risk_summary,
      re.certainty_explanation
    FROM RecommendationInstance ri
    LEFT JOIN RecommendationExplanation re ON re.instance_id = ri.instance_id
    WHERE ri.instance_id = $1
    `,
    [instanceId]
  );

  if (instanceResult.rowCount === 0) {
    return null;
  }

  const alertsResult = await pool.query(
    `
    SELECT safety_rule_id, alert_text, severity
    FROM SafetyAlert
    WHERE instance_id = $1
    ORDER BY alert_id
    `,
    [instanceId]
  );

  const traceResult = await pool.query(
    `
    SELECT trace_id, recommendation_id, clinical_finding_id, generated_at
    FROM EvidenceTrace
    WHERE recommendation_id = $1
    ORDER BY generated_at
    `,
    [instanceResult.rows[0].recommendation_id]
  );

  return {
    ...instanceResult.rows[0],
    safetyAlerts: alertsResult.rows,
    evidenceTrace: traceResult.rows
  };
}
