import { config } from "../../config";
import { LlmGenerateInput, LlmGenerateResult, LlmProviderClient, LlmResolvedRoute } from "../types";

export class OpenAiProvider implements LlmProviderClient {
  readonly name = "openai" as const;

  async generate(input: LlmGenerateInput, route: LlmResolvedRoute): Promise<LlmGenerateResult> {
    const apiKey = config.llm.apiKeys.openai;
    if (!apiKey) {
      throw new Error("OPENAI_API_KEY is required for OpenAI LLM routes");
    }

    const controller = new AbortController();
    const timeout = setTimeout(() => controller.abort(), config.llm.requestTimeoutMs);
    const maxTokens = input.maxTokens ?? route.maxTokens;
    const requestBody: Record<string, unknown> = {
      model: route.model,
      messages: input.messages,
      temperature: input.temperature ?? route.temperature
    };
    if (route.model.startsWith("gpt-5")) {
      requestBody.max_completion_tokens = maxTokens;
    } else {
      requestBody.max_tokens = maxTokens;
    }

    try {
      const response = await fetch("https://api.openai.com/v1/chat/completions", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          Authorization: `Bearer ${apiKey}`
        },
        body: JSON.stringify(requestBody),
        signal: controller.signal
      });

      if (!response.ok) {
        const errorBody = await response.text();
        throw new Error(`OpenAI request failed (${response.status}): ${errorBody}`);
      }

      const payload = await response.json();
      const text = payload.choices?.[0]?.message?.content;
      if (typeof text !== "string") {
        throw new Error("OpenAI response did not contain assistant text");
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
