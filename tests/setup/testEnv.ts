import { execSync } from "node:child_process";

process.env.NODE_ENV = "test";
process.env.DATABASE_URL = process.env.DATABASE_URL ?? "postgresql://localhost:5432/guiderx_mvp_test";

beforeAll(() => {
  execSync("make db-reset-test", { stdio: "inherit" });
});
