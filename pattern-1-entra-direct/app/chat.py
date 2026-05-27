"""Pattern 1 sample: chat against Azure OpenAI using an Entra ID bearer token.

The key point of this pattern is that the AOAI account has local auth
disabled, so every call is made with the *user's own* Entra identity. That
identity then flows into the AOAI diagnostic logs, which makes per-user usage
attribution possible without any custom gateway.

Usage:
    uv run python chat.py "Hello, who are you?"
"""

from __future__ import annotations

import os
import sys

from azure.identity import DefaultAzureCredential, get_bearer_token_provider
from openai import AzureOpenAI


COGNITIVE_SERVICES_SCOPE = "https://cognitiveservices.azure.com/.default"


def _require_env(name: str) -> str:
    value = os.environ.get(name)
    if not value:
        raise SystemExit(
            f"環境変数 {name} が未設定です。`azd env get-values` を読み込んでから再実行してください。"
        )
    return value


def main() -> None:
    prompt = " ".join(sys.argv[1:]).strip() or "Azure OpenAI の概要を 2 文で説明してください。"

    endpoint = _require_env("AZURE_OPENAI_ENDPOINT")
    deployment = _require_env("AZURE_OPENAI_DEPLOYMENT")
    api_version = os.environ.get("AZURE_OPENAI_API_VERSION", "2024-10-21")

    credential = DefaultAzureCredential()
    token_provider = get_bearer_token_provider(credential, COGNITIVE_SERVICES_SCOPE)

    client = AzureOpenAI(
        azure_endpoint=endpoint,
        azure_ad_token_provider=token_provider,
        api_version=api_version,
    )

    response = client.chat.completions.create(
        model=deployment,
        messages=[
            {"role": "system", "content": "あなたは簡潔に答える日本語のアシスタントです。"},
            {"role": "user", "content": prompt},
        ],
    )

    message = response.choices[0].message.content
    usage = response.usage

    print("--- 応答 ---")
    print(message)
    print("--- 使用トークン ---")
    if usage is not None:
        print(f"prompt={usage.prompt_tokens} completion={usage.completion_tokens} total={usage.total_tokens}")
    else:
        print("(usage 情報なし)")


if __name__ == "__main__":
    main()
