import { Router } from "express";
import multer from "multer";
import {
  createPaper,
  getDbStatus,
  listPapers,
  AdminConflictError
} from "../services/adminService";
import { extractDraftFromUpload } from "../services/paperExtractionService";
import { adminPaperCreateSchema, adminPaperListQuerySchema } from "../validation/schemas";

const router = Router();
const upload = multer({
  storage: multer.memoryStorage(),
  limits: {
    fileSize: 15 * 1024 * 1024
  }
});

router.get("/db-status", async (_req, res, next) => {
  try {
    const data = await getDbStatus();
    res.json({ data });
  } catch (error) {
    next(error);
  }
});

router.get("/papers", async (req, res, next) => {
  try {
    const query = adminPaperListQuerySchema.parse(req.query);
    const data = await listPapers(query);
    res.json({ data });
  } catch (error) {
    next(error);
  }
});

router.post("/papers", async (req, res, next) => {
  try {
    const payload = adminPaperCreateSchema.parse(req.body);
    const data = await createPaper(payload);
    res.status(201).json({ data });
  } catch (error) {
    if (error instanceof AdminConflictError) {
      res.status(409).json({ error: "ConflictError", message: error.message });
      return;
    }
    next(error);
  }
});

router.post("/papers/extract", upload.single("paper"), async (req, res, next) => {
  try {
    if (!req.file) {
      res.status(400).json({ error: "ValidationError", message: "Missing uploaded file in 'paper' field." });
      return;
    }

    const data = await extractDraftFromUpload(req.file);
    res.json({ data });
  } catch (error) {
    if (error instanceof multer.MulterError) {
      res.status(400).json({ error: "ValidationError", message: error.message });
      return;
    }
    next(error);
  }
});

export const adminRoutes = router;
