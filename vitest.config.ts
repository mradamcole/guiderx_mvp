import { defineConfig } from "vitest/config";

export default defineConfig({
  test: {
    include: ["tests/**/*.test.ts"],
    environment: "node",
    globals: true,
    setupFiles: ["tests/setup/testEnv.ts"],
    fileParallelism: false,
    hookTimeout: 30000,
    testTimeout: 30000
  }
});
