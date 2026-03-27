import { appConfig, config, LlmRouteName } from "../config";
import { AnthropicProvider } from "./providers/anthropicProvider";
import { OpenAiProvider } from "./providers/openAiProvider";
import { LlmGenerateInput, LlmGenerateResult, LlmProviderClient, LlmResolvedRoute } from "./types";

export class LlmRouter {
  private providers = new Map<string, LlmProviderClient>();

  constructor(providerClients: LlmProviderClient[]) {
    for (const provider of providerClients) {
      this.providers.set(provider.name, provider);
    }
  }

  resolveRoute(routeName: LlmRouteName = "default"): LlmResolvedRoute {
    const route = appConfig.llm.routes[routeName];
    if (!route) {
      throw new Error(`Unknown LLM route: ${routeName}`);
    }

    return {
      routeName,
      provider: route.provider,
      model: route.model,
      temperature: route.temperature,
      maxTokens: route.maxTokens
    };
  }

  async generate(input: LlmGenerateInput): Promise<LlmGenerateResult> {
    const resolvedRoute = this.resolveRoute(input.route ?? "default");
    const provider = this.providers.get(resolvedRoute.provider);
    if (!provider) {
      throw new Error(`No provider client registered for "${resolvedRoute.provider}"`);
    }

    const maxAttempts = Math.max(1, config.llm.maxRetries + 1);
    let latestError: unknown;

    for (let attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        return await provider.generate(input, resolvedRoute);
      } catch (error) {
        latestError = error;
        if (attempt === maxAttempts) {
          break;
        }
      }
    }

    throw latestError;
  }
}

export function createDefaultLlmRouter(): LlmRouter {
  return new LlmRouter([new OpenAiProvider(), new AnthropicProvider()]);
}
