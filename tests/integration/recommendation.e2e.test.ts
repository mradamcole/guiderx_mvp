import request from "supertest";
import { createApp } from "../../src/app";
import { pool } from "../../src/db/pool";
import { clearRecommendationGraph, createRecommendationFixture } from "../setup/dbTestUtils";

describe("evidence ingestion and recommendation e2e", () => {
  const app = createApp();

  beforeEach(async () => {
    await clearRecommendationGraph();
  });

  afterAll(async () => {
    await pool.end();
  });

  it("ingests evidence and generates a traceable recommendation instance", async () => {
    const ingestionResponse = await request(app).post("/api/ingestion/evidence").send({
      concept: {
        system: "Custom",
        code: "E2E_CONCEPT",
        displayText: "E2E Concept"
      },
      study: {
        name: "E2E Study",
        studyTypeName: "RCT",
        sampleSize: 100,
        sponsor: "GuideRx"
      },
      arm: {
        armType: "intervention",
        size: 50,
        productName: "E2E Product"
      },
      outcome: {
        effectSize: 0.42,
        effectType: "SMD",
        pValue: 0.01,
        timepoint: "12 weeks",
        summary: "Synthetic e2e outcome"
      }
    });

    expect(ingestionResponse.status).toBe(201);
    expect(ingestionResponse.body.data.outcomeId).toBeTruthy();

    const fixture = await createRecommendationFixture();

    const generateResponse = await request(app).post("/api/recommendations/generate").send({
      recommendationId: fixture.recommendationId,
      context: {
        age: 45,
        sex: "female",
        diagnoses: ["ICD11:8A80"],
        symptoms: ["pain"],
        currentMedications: ["med-a"],
        contraindications: ["history-psychosis"]
      },
      evidenceScore: 0.78,
      confidenceLevel: "Moderate",
      algorithmVersion: "e2e-v1",
      evidenceSummary: "Moderate certainty from synthetic test data",
      benefitSummary: "Pain reduction likely",
      riskSummary: "Monitor dizziness",
      certaintyExplanation: "Derived from controlled synthetic inputs",
      clinicalFindingIds: [fixture.clinicalFindingId],
      safetyAlerts: [
        {
          safetyRuleId: fixture.safetyRuleId,
          alertText: "Use caution with psychiatric history",
          severity: "warning"
        }
      ]
    });

    expect(generateResponse.status).toBe(201);
    expect(generateResponse.body.data.evidenceTraceCount).toBe(1);
    expect(generateResponse.body.data.safetyAlertCount).toBe(1);

    const instanceId = generateResponse.body.data.instanceId;
    const getResponse = await request(app).get(`/api/recommendations/instances/${instanceId}`);

    expect(getResponse.status).toBe(200);
    expect(getResponse.body.data.instance_id).toBe(instanceId);
    expect(getResponse.body.data.evidenceTrace).toHaveLength(1);
    expect(getResponse.body.data.safetyAlerts).toHaveLength(1);
  });
});
