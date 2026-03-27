import express from "express";
import { ZodError } from "zod";
import { ingestionRoutes } from "./routes/ingestionRoutes";
import { recommendationRoutes } from "./routes/recommendationRoutes";

export function createApp() {
  const app = express();

  app.use(express.json());

  app.get("/health", (_req, res) => {
    res.json({ status: "ok" });
  });

  app.use("/api/ingestion", ingestionRoutes);
  app.use("/api/recommendations", recommendationRoutes);

  app.use((error: unknown, _req: express.Request, res: express.Response, _next: express.NextFunction) => {
    if (error instanceof ZodError) {
      res.status(400).json({
        error: "ValidationError",
        details: error.issues
      });
      return;
    }

    const message = error instanceof Error ? error.message : "Internal server error";
    res.status(500).json({ error: "InternalServerError", message });
  });

  return app;
}
