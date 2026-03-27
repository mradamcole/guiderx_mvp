import { Router } from "express";
import {
  generateRecommendationInstance,
  getRecommendationInstance
} from "../services/recommendationService";
import { recommendationGenerationSchema, uuidSchema } from "../validation/schemas";

const router = Router();

router.post("/generate", async (req, res, next) => {
  try {
    const payload = recommendationGenerationSchema.parse(req.body);
    const result = await generateRecommendationInstance(payload);
    res.status(201).json({ data: result });
  } catch (error) {
    next(error);
  }
});

router.get("/instances/:instanceId", async (req, res, next) => {
  try {
    const instanceId = uuidSchema.parse(req.params.instanceId);
    const instance = await getRecommendationInstance(instanceId);
    if (!instance) {
      res.status(404).json({ error: "Recommendation instance not found" });
      return;
    }
    res.json({ data: instance });
  } catch (error) {
    next(error);
  }
});

export const recommendationRoutes = router;
