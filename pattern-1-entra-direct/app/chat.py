"""Pattern 1 sample: chat against Azure OpenAI using an Entra ID bearer token.

このサンプルは Microsoft Foundry Models の **v1 エンドポイント** (`/openai/v1/`)
を呼び出すため、`openai.OpenAI` クライアントを直接使用する。
ポイントは以下の通り。

- AOAI アカウントは `disableLocalAuth=true` (API Key 無効)
- 認証は `DefaultAzureCredential` で取得したユーザー本人の Entra トークン
- v1 エンドポイントを使うため `api_version` は不要 (毎月の API バージョン更新も不要)
- `api_key=token_provider` (callable) を渡すことで openai SDK 側がトークンの
  自動取得・更新を担う。AzureOpenAI クライアントへの依存が不要になった

Usage:
    uv run chat.py "Hello, who are you?"
"""

from __future__ import annotations

import os
import sys

from azure.identity import DefaultAzureCredential, get_bearer_token_provider
from dotenv import load_dotenv
from openai import OpenAI


COGNITIVE_SERVICES_SCOPE = "https://cognitiveservices.azure.com/.default"

# 同じディレクトリの .env を読み込む。
# 既にシェルにセットされている値を上書きしないため override=False (デフォルト)。
# 例: `azd env get-values > .env` しておけば、`uv run chat.py` だけで動作する。
load_dotenv()


def _require_env(name: str) -> str:
    value = os.environ.get(name)
    if not value:
        raise SystemExit(
            f"環境変数 {name} が未設定です。`azd env get-values` を読み込んでから再実行してください。"
        )
    return value


def main() -> None:
    prompt = " ".join(sys.argv[1:]).strip() or "Azure OpenAI の概要を 2 文で説明してください。"

    endpoint = _require_env("AZURE_OPENAI_ENDPOINT").rstrip("/")
    deployment = _require_env("AZURE_OPENAI_DEPLOYMENT")

    credential = DefaultAzureCredential()
    token_provider = get_bearer_token_provider(credential, COGNITIVE_SERVICES_SCOPE)

    # v1 エンドポイント: AOAI リソース URL の末尾に /openai/v1/ を付与する。
    # api_key には token provider を渡すと openai SDK が自動でトークンを更新する。
    client = OpenAI(
        base_url=f"{endpoint}/openai/v1/",
        api_key=token_provider,
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
