import { z } from "zod";

export const uuidSchema = z.uuid();

export const ingestionPayloadSchema = z.object({
  concept: z.object({
    system: z.enum(["ICD11", "SNOMED-CT", "RxNorm", "Custom"]),
    code: z.string().min(1),
    displayText: z.string().min(1)
  }),
  study: z.object({
    name: z.string().min(1),
    studyTypeName: z.string().min(1).optional(),
    sampleSize: z.number().int().nonnegative().optional(),
    sponsor: z.string().optional()
  }),
  arm: z.object({
    armType: z.enum(["intervention", "placebo", "active_comparator"]),
    size: z.number().int().nonnegative().optional(),
    productName: z.string().min(1).optional()
  }),
  outcome: z.object({
    effectSize: z.number().optional(),
    effectType: z.enum(["RR", "OR", "SMD", "Mean Difference"]).optional(),
    pValue: z.number().min(0).max(1).optional(),
    timepoint: z.string().optional(),
    summary: z.string().optional()
  })
});

export const safetyAlertInputSchema = z.object({
  safetyRuleId: uuidSchema,
  alertText: z.string().min(1),
  severity: z.enum(["warning", "contraindicated"])
});

export const recommendationGenerationSchema = z.object({
  recommendationId: uuidSchema,
  context: z
    .object({
      age: z.number().int().nonnegative().optional(),
      sex: z.string().optional(),
      diagnoses: z.array(z.string()).optional(),
      symptoms: z.array(z.string()).optional(),
      currentMedications: z.array(z.string()).optional(),
      contraindications: z.array(z.string()).optional()
    })
    .optional(),
  evidenceScore: z.number().optional(),
  confidenceLevel: z.enum(["High", "Moderate", "Low", "Very Low"]).optional(),
  algorithmVersion: z.string().optional(),
  evidenceSummary: z.string().optional(),
  benefitSummary: z.string().optional(),
  riskSummary: z.string().optional(),
  certaintyExplanation: z.string().optional(),
  clinicalFindingIds: z.array(uuidSchema).default([]),
  safetyAlerts: z.array(safetyAlertInputSchema).default([])
});

export type IngestionPayload = z.infer<typeof ingestionPayloadSchema>;
export type RecommendationGenerationPayload = z.infer<typeof recommendationGenerationSchema>;
