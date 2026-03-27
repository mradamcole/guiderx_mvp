import { Router } from "express";
import { ingestEvidence } from "../services/ingestionService";
import { ingestionPayloadSchema } from "../validation/schemas";

const router = Router();

router.post("/evidence", async (req, res, next) => {
  try {
    const payload = ingestionPayloadSchema.parse(req.body);
    const result = await ingestEvidence(payload);
    res.status(201).json({ data: result });
  } catch (error) {
    next(error);
  }
});

export const ingestionRoutes = router;
