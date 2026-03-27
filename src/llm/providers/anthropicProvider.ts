import { config } from "../../config";
import { LlmGenerateInput, LlmGenerateResult, LlmProviderClient, LlmResolvedRoute } from "../types";

export class AnthropicProvider implements LlmProviderClient {
  readonly name = "anthropic" as const;

  async generate(input: LlmGenerateInput, route: LlmResolvedRoute): Promise<LlmGenerateResult> {
    const apiKey = config.llm.apiKeys.anthropic;
    if (!apiKey) {
      throw new Error("ANTHROPIC_API_KEY is required for Anthropic LLM routes");
    }

    const controller = new AbortController();
    const timeout = setTimeout(() => controller.abort(), config.llm.requestTimeoutMs);

    try {
      const response = await fetch("https://api.anthropic.com/v1/messages", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "x-api-key": apiKey,
          "anthropic-version": "2023-06-01"
        },
        body: JSON.stringify({
          model: route.model,
          temperature: input.temperature ?? route.temperature,
          max_tokens: input.maxTokens ?? route.maxTokens,
          messages: input.messages
            .filter((message) => message.role !== "system")
            .map((message) => ({
              role: message.role,
              content: message.content
            })),
          system:
            input.messages.find((message) => message.role === "system")?.content ?? undefined
        }),
        signal: controller.signal
      });

      if (!response.ok) {
        const errorBody = await response.text();
        throw new Error(`Anthropic request failed (${response.status}): ${errorBody}`);
      }

      const payload = await response.json();
      const firstBlock = payload.content?.[0];
      const text = firstBlock?.type === "text" ? firstBlock.text : undefined;
      if (typeof text !== "string") {
        throw new Error("Anthropic response did not contain text content");
      }

      return {
        provider: this.name,
        model: route.model,
        text,
        raw: payload
      };
    } finally {
      clearTimeout(timeout);
    }
  }
}
