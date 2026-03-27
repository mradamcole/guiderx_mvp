import type { LlmProviderName, LlmRouteName } from "../config";

export type LlmMessageRole = "system" | "user" | "assistant";

export type LlmMessage = {
  role: LlmMessageRole;
  content: string;
};

export type LlmGenerateInput = {
  route?: LlmRouteName;
  messages: LlmMessage[];
  temperature?: number;
  maxTokens?: number;
};

export type LlmResolvedRoute = {
  routeName: LlmRouteName;
  provider: LlmProviderName;
  model: string;
  temperature: number;
  maxTokens: number;
};

export type LlmGenerateResult = {
  provider: LlmProviderName;
  model: string;
  text: string;
  raw: unknown;
};

export interface LlmProviderClient {
  readonly name: LlmProviderName;
  generate(input: LlmGenerateInput, route: LlmResolvedRoute): Promise<LlmGenerateResult>;
}
