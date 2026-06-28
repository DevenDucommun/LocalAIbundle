#!/usr/bin/env python3
import sys


def main() -> int:
    if len(sys.argv) != 5:
        print("usage: validate-config.py <config.yaml> <chat-model> <completion-model> <embed-model>", file=sys.stderr)
        return 2

    path, chat_model, completion_model, embed_model = sys.argv[1:5]
    text = open(path, encoding="utf-8").read().splitlines()
    errors = []

    def has_line(value: str) -> bool:
        return any(line.strip() == value for line in text)

    if not has_line("schema: v1"):
        errors.append("missing schema: v1")
    if not has_line("models:"):
        errors.append("missing models block")
    if not has_line("context:"):
        errors.append("missing context block")

    expected_models = {
        chat_model: {"chat", "edit", "apply"},
        completion_model: {"autocomplete"},
        embed_model: {"embed"},
    }

    models = {}
    current_model = None
    in_models = False
    in_roles = False

    for raw in text:
        stripped = raw.split("#", 1)[0].rstrip()
        if not stripped.strip():
            continue
        indent = len(stripped) - len(stripped.lstrip(" "))
        token = stripped.strip()

        if indent == 0:
            if token == "models:":
                in_models = True
                continue
            if in_models:
                break

        if not in_models:
            continue

        if indent == 2 and token.startswith("- "):
            current_model = None
            in_roles = False
        elif indent == 4 and token.startswith("model:"):
            current_model = token.split(":", 1)[1].strip().strip('"').strip("'")
            models.setdefault(current_model, set())
            in_roles = False
        elif indent == 4 and token == "roles:":
            in_roles = True
        elif in_roles and indent == 6 and token.startswith("- ") and current_model:
            models[current_model].add(token[2:].strip())
        elif indent <= 4:
            in_roles = False

    for model, roles in expected_models.items():
        if model not in models:
            errors.append(f"missing model: {model}")
            continue
        missing_roles = roles - models[model]
        if missing_roles:
            errors.append(f"{model} missing role(s): {', '.join(sorted(missing_roles))}")

    if errors:
        for error in errors:
            print(f"config validation error: {error}", file=sys.stderr)
        return 1

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
