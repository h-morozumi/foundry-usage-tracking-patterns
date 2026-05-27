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

1. **Pattern 1: Entra ID + Diagnostic Logs** *(no APIM — concept / minimum viable setup)*
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

### OpenAI SDK Compatibility Policy (Important)

All sample apps across all patterns **MUST use the official `openai` Python SDK `AzureOpenAI` class as-is**. The repository's core design goal is that the client implementation reads the same way whether it talks to AOAI directly or through APIM (AI Gateway).

- ✅ **Allowed**: `openai` package (`AzureOpenAI`), `azure-identity` (for token providers such as `DefaultAzureCredential`)
- ❌ **Not allowed**: hand-rolled REST calls via a custom HTTP client, hand-written OpenAI API calls using `requests` / `httpx`, forked SDKs
- Per-pattern SDK usage:
  - **Pattern 1 / 2A / 2D**: pass an Entra Bearer via `AzureOpenAI(azure_ad_token_provider=...)`
  - **Pattern 2B**: identical to Pattern 2A / 2D from the client's perspective (Entra Bearer). The AOAI Key swap is fully contained inside APIM
  - **Pattern 2C**: use `AzureOpenAI(api_key=<APIM Subscription Key>, azure_endpoint=<APIM URL>)`. To preserve **zero SDK modifications**, the APIM API definition MUST set `subscriptionKeyParameterNames.header = "api-key"` (the SDK does not send the default `Ocp-Apim-Subscription-Key` header)
- If extra custom headers are needed, use the `default_headers` argument — never patch the SDK itself

### Repository Layout (planned)

Pattern 2 is the headline AI Gateway strategy: "introduce APIM as the AI Gateway." It is split into 4 sub-patterns (2A / 2B / 2C / 2D) by the authentication design on each leg (client ↔ APIM and APIM ↔ AOAI). Each is treated as an independent azd project.

```
.
├── AGENTS.md                  # This file
├── README.md                  # Top-level overview (Japanese)
├── pattern-1-entra-direct/
│   ├── azure.yaml             # azd project root for Pattern 1 (Entra Direct, no APIM)
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
│   ├── infra/                 # APIM + Key Vault + AOAI (Private Endpoint recommended)
│   ├── app/
│   └── README.md
├── pattern-2c-apim-subscription-key/
│   ├── azure.yaml             # azd project root for Pattern 2C (per-user Subscription Key)
│   ├── infra/                 # APIM + Key Vault + AOAI (Private)
│   ├── app/
│   └── README.md
└── pattern-2d-apim-entra-mi/        ★ GOAL / AI Gateway target
    ├── azure.yaml             # azd project root for Pattern 2D (Entra + APIM Managed Identity)
    ├── infra/                 # APIM(MI) + AOAI(API Key disabled, Private)
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
