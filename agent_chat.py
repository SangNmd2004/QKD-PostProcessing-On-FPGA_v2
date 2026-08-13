import argparse
import os
import sys

from openai import OpenAI


BASE_URL = "https://integrate.api.nvidia.com/v1"
DEFAULT_MODEL = "z-ai/glm-5.2"


def build_client() -> OpenAI:
    api_key = os.getenv("NVIDIA_API_KEY") or os.getenv("OPENAI_API_KEY")
    if not api_key:
        raise SystemExit(
            "Missing API key. Set NVIDIA_API_KEY or OPENAI_API_KEY before running."
        )

    return OpenAI(base_url=BASE_URL, api_key=api_key)


def stream_reply(client: OpenAI, model: str, messages: list[dict[str, str]]) -> str:
    completion = client.chat.completions.create(
        model=model,
        messages=messages,
        temperature=1,
        top_p=1,
        max_tokens=16384,
        seed=42,
        stream=True,
    )

    assistant_text = []

    for chunk in completion:
        if not getattr(chunk, "choices", None):
            continue
        if len(chunk.choices) == 0 or getattr(chunk.choices[0], "delta", None) is None:
            continue

        delta = chunk.choices[0].delta
        if getattr(delta, "content", None) is not None:
            assistant_text.append(delta.content)
            print(delta.content, end="")
            sys.stdout.flush()

    print()
    return "".join(assistant_text)


def interactive_chat(client: OpenAI, model: str, initial_prompt: str | None) -> None:
    messages: list[dict[str, str]] = []

    if initial_prompt:
        messages.append({"role": "user", "content": initial_prompt})
        assistant_reply = stream_reply(client, model, messages)
        messages.append({"role": "assistant", "content": assistant_reply})

    while True:
        try:
            user_prompt = input("\nYou> ").strip()
        except (EOFError, KeyboardInterrupt):
            print()
            return

        if not user_prompt:
            continue
        if user_prompt.lower() in {"exit", "quit"}:
            return

        messages.append({"role": "user", "content": user_prompt})
        assistant_reply = stream_reply(client, model, messages)
        messages.append({"role": "assistant", "content": assistant_reply})


def main() -> None:
    parser = argparse.ArgumentParser(description="Simple NVIDIA/OpenAI-compatible chat agent")
    parser.add_argument("prompt", nargs="?", help="Optional initial prompt to send to the model")
    parser.add_argument("--model", default=DEFAULT_MODEL, help="Model name to use")
    args = parser.parse_args()

    client = build_client()
    interactive_chat(client, args.model, args.prompt)


if __name__ == "__main__":
    main()