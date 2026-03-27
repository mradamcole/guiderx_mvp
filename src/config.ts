import dotenv from "dotenv";

dotenv.config();

export type LlmProviderName = "openai" | "anthropic";
export type LlmRouteName = "default" | "reasoning" | "classification" | "summarization";

type LlmRouteConfig = {
  provider: LlmProviderName;
  model: string;
  temperature: number;
  maxTokens: number;
};

const defaultDb = process.env.NODE_ENV === "test" ? "guiderx_mvp_test" : "guiderx_mvp";

/**
 * Centralized, non-secret application config.
 * Keep tunables here so they are source-controlled and discoverable.
*
* Model	Release Date	Input (per 1M)	Output (per 1M)	Key Strength
* GPT-5.4 Nano	Mar 2026	$0.20	$1.25	Latest tech, best budget reasoning.
* GPT-5 Nano	Aug 2025	$0.05	$0.40	Cheapest overall.
* GPT-5.4 Mini	Mar 2026	$0.75	$4.50	Best "all-rounder" for coding/logic.
* o4-mini	2025	$1.10	$4.40
 */
export const appConfig = {
  server: {
    port: 3000,
    corsOrigin: "http://localhost:5173"
  },
  llm: {
    requestTimeoutMs: 30000,
    maxRetries: 2,
    routes: {
      default: {
        provider: "openai",
        model: "gpt-5.4-mini",
        temperature: 0.2,
        maxTokens: 1200
      },
      reasoning: {
        provider: "openai",
        model: "gpt-4.1",
        temperature: 0.1,
        maxTokens: 2200
      },
      classification: {
        provider: "openai",
        model: "gpt-4.1-mini",
        temperature: 0,
        maxTokens: 300
      },
      summarization: {
        provider: "anthropic",
        model: "claude-3-5-haiku-latest",
        temperature: 0.2,
        maxTokens: 900
      }
    } satisfies Record<LlmRouteName, LlmRouteConfig>
  }
} as const;

/**
 * Runtime config can consume environment secrets, but avoids non-secret toggles in .env.
 */
export const config = {
  nodeEnv: process.env.NODE_ENV ?? "development",
  port: appConfig.server.port,
  corsOrigin: appConfig.server.corsOrigin,
  databaseUrl: process.env.DATABASE_URL ?? `postgresql://localhost:5432/${defaultDb}`,
  llm: {
    ...appConfig.llm,
    apiKeys: {
      openai: process.env.OPENAI_API_KEY,
      anthropic: process.env.ANTHROPIC_API_KEY
    }
  }
};

export type RuntimeConfig = typeof config;
