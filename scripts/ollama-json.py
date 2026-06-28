#!/usr/bin/env python3
import json
import sys


def read_stdin_json():
    return json.load(sys.stdin)


def main() -> int:
    if len(sys.argv) < 2:
        print("usage: ollama-json.py <models|generate-stat|response|embedding-dims> [field]", file=sys.stderr)
        return 2

    command = sys.argv[1]
    data = read_stdin_json()

    if command == "models":
        for model in data.get("models", []):
            print(model.get("name", ""))
        return 0

    if command == "generate-stat":
        field = sys.argv[2] if len(sys.argv) > 2 else ""
        count = data.get("eval_count", 0)
        duration = data.get("eval_duration", 0) / 1e9
        if field == "tokens":
            print(count)
        elif field == "duration":
            print(f"{duration:.2f}")
        elif field == "speed":
            divisor = duration if duration > 0 else 1
            print(f"{count / divisor:.1f}")
        else:
            print(f"unknown generate-stat field: {field}", file=sys.stderr)
            return 2
        return 0

    if command == "response":
        limit = int(sys.argv[2]) if len(sys.argv) > 2 else 100
        print(data.get("response", "")[:limit])
        return 0

    if command == "embedding-dims":
        embeddings = data.get("embeddings", [[]])
        print(len(embeddings[0]) if embeddings else 0)
        return 0

    print(f"unknown command: {command}", file=sys.stderr)
    return 2


if __name__ == "__main__":
    raise SystemExit(main())
