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

export const adminDbStatusResponseSchema = z.object({
  status: z.literal("ok"),
  databaseConnected: z.boolean(),
  latencyMs: z.number().nonnegative(),
  counts: z.object({
    papers: z.number().int().nonnegative(),
    studies: z.number().int().nonnegative(),
    authors: z.number().int().nonnegative(),
    outcomes: z.number().int().nonnegative()
  })
});

export const adminPaperListQuerySchema = z.object({
  limit: z.coerce.number().int().positive().max(100).default(20),
  offset: z.coerce.number().int().nonnegative().default(0),
  search: z.string().trim().max(255).optional()
});

export const adminPaperSchema = z.object({
  title: z.string().min(1),
  doi: z.string().min(1).optional(),
  url: z.string().url().optional(),
  journalName: z.string().min(1).optional(),
  publisherName: z.string().min(1).optional(),
  isPeerReviewed: z.boolean().optional(),
  altmetricScore: z.number().int().nonnegative().optional()
});

export const adminPaperAuthorSchema = z.object({
  name: z.string().min(1),
  orcid: z.string().max(20).optional(),
  authorOrder: z.number().int().positive().optional(),
  isCorresponding: z.boolean().optional()
});

export const adminPaperCreateSchema = z.object({
  paper: adminPaperSchema,
  authors: z.array(adminPaperAuthorSchema).default([]),
  ingestions: z.array(ingestionPayloadSchema).min(1)
});

export const adminPaperExtractedDraftSchema = z.object({
  paper: adminPaperSchema.partial().extend({
    title: z.string().min(1).default(""),
    isPeerReviewed: z.boolean().default(true)
  }),
  authors: z.array(adminPaperAuthorSchema).default([]),
  ingestion: ingestionPayloadSchema.partial().extend({
    concept: ingestionPayloadSchema.shape.concept.partial().default({}),
    study: ingestionPayloadSchema.shape.study.partial().default({}),
    arm: ingestionPayloadSchema.shape.arm.partial().default({}),
    outcome: ingestionPayloadSchema.shape.outcome.partial().default({})
  }),
  confidence: z.number().min(0).max(1).optional(),
  notes: z.array(z.string()).default([])
});

export type IngestionPayload = z.infer<typeof ingestionPayloadSchema>;
export type RecommendationGenerationPayload = z.infer<typeof recommendationGenerationSchema>;
export type AdminDbStatusResponse = z.infer<typeof adminDbStatusResponseSchema>;
export type AdminPaperListQuery = z.infer<typeof adminPaperListQuerySchema>;
export type AdminPaperCreatePayload = z.infer<typeof adminPaperCreateSchema>;
export type AdminPaperExtractedDraft = z.infer<typeof adminPaperExtractedDraftSchema>;
