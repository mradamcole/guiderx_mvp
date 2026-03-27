import express from "express";
import { ZodError } from "zod";
import { config } from "./config";
import { adminRoutes } from "./routes/adminRoutes";
import { ingestionRoutes } from "./routes/ingestionRoutes";
import { recommendationRoutes } from "./routes/recommendationRoutes";

export function createApp() {
  const app = express();

  app.use((req, res, next) => {
    res.setHeader("Access-Control-Allow-Origin", config.corsOrigin);
    res.setHeader("Vary", "Origin");
    res.setHeader("Access-Control-Allow-Methods", "GET,POST,PUT,PATCH,DELETE,OPTIONS");
    res.setHeader("Access-Control-Allow-Headers", "Content-Type, Authorization");
    if (req.method === "OPTIONS") {
      res.status(204).end();
      return;
    }
    next();
  });

  app.use(express.json());

  app.get("/health", (_req, res) => {
    res.json({ status: "ok" });
  });

  app.use("/api/ingestion", ingestionRoutes);
  app.use("/api/recommendations", recommendationRoutes);
  app.use("/api/admin", adminRoutes);

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
