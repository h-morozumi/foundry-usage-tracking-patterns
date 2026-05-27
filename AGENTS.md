# AGENTS.md

## Language Policy

**Think in English, output in Japanese.**

All internal reasoning, planning, and chain-of-thought must be conducted in English to maximize clarity and precision. However, every user-facing response, document, comment, and explanation must be written in Japanese (日本語). This applies to:

- Chat responses to the user
- Markdown documentation files (README, hands-on guides, etc.)
- Inline comments in source code (when appropriate)
- Commit messages and PR descriptions (unless the user specifies otherwise)

Code identifiers (variable names, function names, file names, etc.) should remain in English following standard programming conventions.

---

## Project Overview

This repository provides **hands-on documentation** for tracking per-user usage of Microsoft Foundry Models (including Azure OpenAI). It addresses a common customer pain point: when models are accessed via shared API keys, it is impossible to attribute usage to individual users.

### Patterns Covered

The repository ships **two families** of patterns. Pattern 1 is the conceptual baseline; Pattern 2 (all 2A/2B/2C/2D variants) is the **headline AI Gateway strategy** and the main deliverable.

1. **Pattern 1: Entra ID + Diagnostic Logs** *(APIM なし — concept / minimum viable setup)*
   - Authenticate users with Microsoft Entra ID directly against Azure OpenAI / Foundry
   - Capture per-user usage via Azure Monitor Diagnostic Logs

2. **Pattern 2: AI Gateway (Azure API Management)** ★ headline strategy
   - **2A: Bearer pass-through** — APIM forwards the user's Entra Bearer to AOAI as-is
   - **2B: Entra → AOAI Key exchange** — APIM authenticates the user with Entra, then calls AOAI with a key stored in Key Vault
   - **2C: per-user APIM Subscription Key** — each user/team gets its own APIM Subscription Key; APIM converts to an AOAI key. Designed for clients that cannot adopt Entra ID
   - **2D ★ AI Gateway: Entra + APIM Managed Identity** *(goal pattern)* — Users authenticate against a custom `api://ai-gateway` App Registration; APIM calls AOAI **keyless** via its System-Assigned Managed Identity. AOAI API Key is disabled. This is the target architecture customers should aim for.

---

## Tech Stack & Conventions

### Infrastructure as Code

- Use **`azd` (Azure Developer CLI)** for provisioning and deployment workflows
- Use **Bicep** for IaC templates
- **Always prefer AVM (Azure Verified Modules)** for Bicep modules. Do not hand-roll resources when an AVM module exists

### `azd` Project Granularity

- **One `azd` project per hands-on pattern directory.** Each `pattern-*/` directory is a self-contained `azd` project with its own `azure.yaml`, `infra/`, and `.azure/` state.
- Learners run `azd up` / `azd down` inside the pattern directory they are working on. They never deploy all patterns at once.
- Do NOT create a single root-level `azure.yaml` that aggregates multiple patterns. Keeping patterns isolated:
  - Lets learners try just the pattern they care about
  - Avoids deploying expensive resources (e.g., APIM in Pattern 2) when not needed
  - Keeps `azd` env state (`.azure/<env>/`) cleanly separated per pattern
  - Localizes deployment failures
- If a future need arises to share infrastructure across patterns (e.g., a shared Foundry resource), prefer referencing pre-existing resources via `azd env` variables and Bicep `existing` declarations rather than merging the `azd` projects.

### Sample Applications

- Language: **Python**
- Package/environment manager: **`uv`** (https://docs.astral.sh/uv/)
- **Do NOT use `pip`**, `pip-tools`, `poetry`, `pipenv`, or `conda`
- Manage dependencies via `pyproject.toml` and `uv.lock`
- Run scripts with `uv run` and add dependencies with `uv add`

### OpenAI SDK 互換性ポリシー（重要）

全パターンのサンプルアプリは **公式 `openai` Python SDK の `AzureOpenAI` クラスをそのまま使う** ことを必須要件とする。AOAI 直叩きでも APIM (AI Gateway) 経由でも、クライアント実装が同じ書き味で動くことが本リポジトリの設計目標。

- ✅ **使ってよい**: `openai` パッケージ (`AzureOpenAI`)、`azure-identity`（`DefaultAzureCredential` などのトークンプロバイダー用途）
- ❌ **使ってはいけない**: 独自 HTTP クライアントによる REST 直叩き、`requests` / `httpx` で OpenAI API を手書きする実装、フォーク版 SDK
- パターン別の SDK 使い方:
  - **Pattern 1 / 2A / 2D**: `AzureOpenAI(azure_ad_token_provider=...)` で Entra Bearer を渡す
  - **Pattern 2B**: クライアント観点では Pattern 2A / 2D と同じ（Entra Bearer）。AOAI Key 変換は APIM 内部で完結
  - **Pattern 2C**: `AzureOpenAI(api_key=<APIM Subscription Key>, azure_endpoint=<APIM URL>)` で動かす。**SDK 改修ゼロ** を成立させるため、APIM 側の API 定義で `subscriptionKeyParameterNames.header = "api-key"` を必ず設定する（既定の `Ocp-Apim-Subscription-Key` のままだと SDK が送らない）
- カスタムヘッダーを足したい場合は `default_headers` 引数を使い、SDK 本体には触らない

### Repository Layout (planned)

Pattern 2 は「APIM を AI Gateway として導入する」本命の戦略で、クライアント↔APIM 間と APIM↔AOAI 間の認証設計で 4 つのサブパターン（2A / 2B / 2C / 2D）に分けている。それぞれ独立した azd プロジェクトとして扱う。

```
.
├── AGENTS.md                  # This file
├── README.md                  # Top-level overview (Japanese)
├── pattern-1-entra-direct/
│   ├── azure.yaml             # azd project root for Pattern 1 (Entra Direct, APIM なし)
│   ├── infra/                 # Bicep (AVM-based)
│   ├── app/                   # Python sample (uv)
│   └── README.md
├── pattern-2a-apim-passthrough/
│   ├── azure.yaml             # azd project root for Pattern 2A (Bearer pass-through)
│   ├── infra/
│   ├── app/
│   └── README.md
├── pattern-2b-apim-key-exchange/
│   ├── azure.yaml             # azd project root for Pattern 2B (Entra → AOAI Key)
│   ├── infra/                 # APIM + Key Vault + AOAI (Private Endpoint 推奨)
│   ├── app/
│   └── README.md
├── pattern-2c-apim-subscription-key/
│   ├── azure.yaml             # azd project root for Pattern 2C (per-user Subscription Key)
│   ├── infra/                 # APIM + Key Vault + AOAI (Private)
│   ├── app/
│   └── README.md
└── pattern-2d-apim-entra-mi/        ★ 本命 / AI Gateway ゴール
    ├── azure.yaml             # azd project root for Pattern 2D (Entra + APIM Managed Identity)
    ├── infra/                 # APIM(MI) + AOAI(API Key 無効化, Private)
    ├── app/
    └── README.md
```

---

## Documentation Style

- Target audience: customers and field engineers performing the hands-on
- Provide step-by-step instructions with copy-pasteable commands
- Include prerequisites, expected output, and troubleshooting tips
- Use Mermaid diagrams to illustrate authentication and data flows
- Keep secrets out of the repository; reference Key Vault or environment variables

---

## Operating Principles for Agents

- Before adding a new Bicep resource, check whether an AVM module exists (`mcp_bicep_list_avm_metadata`)
- Before introducing a new Python dependency, confirm `uv` is the manager in use
- **Sample apps must use the official `openai` Python SDK (`AzureOpenAI` class) — do NOT hand-roll REST calls or fork the SDK.** If a pattern seems to require SDK changes, fix it on the APIM side instead (e.g., `subscriptionKeyParameterNames.header = "api-key"` for Pattern 2C)
- When editing infrastructure, validate Bicep (`mcp_bicep_build_bicep`) and follow Bicep best practices (`mcp_bicep_get_bicep_best_practices`)
- When unsure about Azure service behavior, consult Microsoft Learn (`mcp_microsoft-doc_microsoft_docs_search`) rather than guessing
