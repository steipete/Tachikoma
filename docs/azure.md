---
summary: "Implementation plan for first-class Azure OpenAI support in Tachikoma"
read_when: "Working on provider plumbing, authentication, or endpoint wiring"
---

# Azure OpenAI Support — Implementation Plan

## Goals
- Interoperate with Azure OpenAI chat/completions and responses endpoints without requiring an external proxy.
- Match the ergonomics of LangChain/OpenAI SDK Azure helpers: env-var defaults, deployment-centric model identifiers, and automatic header/query shaping.
- Preserve existing `.openaiCompatible` behavior for true OpenAI-clone gateways.

## Azure API Reality Check
- Endpoint shape: `POST https://{resource}.openai.azure.com/openai/deployments/{deploymentId}/chat/completions?api-version=YYYY-MM-DD[-preview]`. citeturn0search3
- Auth: supports either `api-key` header or `Authorization: Bearer <token>` (Entra ID). citeturn0search1turn0search3
- Latest documented preview as of 2025‑11‑16: `2025-04-01-preview`; GA examples still show `2024-06-01`. citeturn0search5
- Breaking changes around data sources and api-version mismatches are common (e.g., json_schema needs ≥2024‑08‑01-preview). citeturn0search6
- Some toolchains hit 404s when they call `/responses` instead of `/chat/completions`; we must pick the right path for Azure. citeturn0search7

## Proposed API Surface
- Add `LanguageModel.azureOpenAI(deployment: String, resource: String? = nil, apiVersion: String? = nil, auth: AzureAuth = .environment)`.
- `AzureAuth` enum: `.apiKey`, `.bearerToken`, `.auto` (prefer bearer if present, fall back to api-key).
- Configuration fallbacks:
  - `AZURE_OPENAI_API_KEY`
  - `AZURE_OPENAI_BEARER_TOKEN` (or `AZURE_OPENAI_TOKEN`)
  - `AZURE_OPENAI_ENDPOINT` (full `https://{resource}.openai.azure.com`)
  - `AZURE_OPENAI_RESOURCE` (resource name; combine with default `https://{resource}.openai.azure.com`)
  - `AZURE_OPENAI_DEPLOYMENT`
  - `AZURE_OPENAI_API_VERSION` (default `2025-04-01-preview` until GA catches up)

## Wire Construction Rules
- Build base URL:
  - If `endpoint` provided, use it verbatim (supports sovereign clouds / APIM custom domains).
  - Else assemble `https://\(resource).openai.azure.com`.
- Path template:
  - Chat: `/openai/deployments/{deployment}/chat/completions`
  - Responses (optional future toggle): `/openai/deployments/{deployment}/responses`
- Query: always append `api-version`.
- Headers:
  - If bearer token available -> `Authorization: Bearer <token>`.
  - Else `api-key: <key>`.
  - `Content-Type: application/json`.

## Integration Points
1) **Model enum**: add `.azureOpenAI(deployment: String, resource: String? = nil, apiVersion: String? = nil)` to `LanguageModel`.
2) **Provider factory**: add `AzureOpenAIProvider` under `Providers/Compatible` (or extend `OpenAICompatibleProvider` with an Azure mode flag).
3) **Helper**: factor Azure-specific URL/header builder into `OpenAICompatibleHelper` (minimal code duplication).
4) **Configuration loading**: map env vars above into `TachikomaConfiguration` with precedence: explicit config → env → credentials file.
5) **Usage tracking**: add Azure to token accounting with same multiplier as OpenAI-compatible.

## Tests
- Unit: URL + header construction with permutations (api-key vs bearer, endpoint vs resource, custom api-version).
- Integration (mock server): assert requests hit `/chat/completions` with `api-version` query and correct auth header; return canned 200 to validate decode.
- Regression: ensure `.openaiCompatible` remains unchanged (no Azure defaults leak).

## Docs & Samples
- README: new “Azure OpenAI” section with env setup snippets and Swift usage:
  ```swift
  let text = try await generate(
      "Summarize CCPA in bullet points",
      using: .azureOpenAI(
          deployment: "gpt-4o",
          resource: "my-aoai",
          apiVersion: "2025-04-01-preview"
      )
  )
  ```
- Troubleshooting table: 401 (wrong header), 404 (wrong path or deployment), 400 (api-version too old for feature).

## Rollout
- Ship behind a minor version bump; no breaking changes to existing providers.
- Announce deprecation date for proxy-based Azure guidance once native provider is stable.
