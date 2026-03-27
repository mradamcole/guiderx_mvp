import dotenv from "dotenv";

dotenv.config();

const defaultDb = process.env.NODE_ENV === "test" ? "guiderx_mvp_test" : "guiderx_mvp";

export const config = {
  nodeEnv: process.env.NODE_ENV ?? "development",
  port: Number(process.env.PORT ?? 3000),
  databaseUrl:
    process.env.DATABASE_URL ?? `postgresql://localhost:5432/${defaultDb}`
};
