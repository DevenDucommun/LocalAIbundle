#!/usr/bin/env python3
import sys


def main() -> int:
    if len(sys.argv) != 4:
        print("usage: config-model-for-role.py <config.yaml> <role> <fallback>", file=sys.stderr)
        return 2

    path, wanted_role, fallback = sys.argv[1:4]
    try:
        lines = open(path, encoding="utf-8").read().splitlines()
    except OSError:
        print(fallback)
        return 0

    models = []
    current = None
    in_models = False
    in_roles = False

    for raw in lines:
        line = raw.split("#", 1)[0].rstrip()
        if not line.strip():
            continue
        indent = len(line) - len(line.lstrip(" "))
        stripped = line.strip()

        if indent == 0:
            if stripped == "models:":
                in_models = True
                continue
            if in_models:
                break

        if not in_models:
            continue

        if indent == 2 and stripped.startswith("- "):
            if current:
                models.append(current)
            current = {"model": None, "roles": []}
            in_roles = False
            continue

        if not current:
            continue

        if indent == 4 and stripped.startswith("model:"):
            current["model"] = stripped.split(":", 1)[1].strip().strip('"').strip("'")
            in_roles = False
        elif indent == 4 and stripped == "roles:":
            in_roles = True
        elif in_roles and indent == 6 and stripped.startswith("- "):
            current["roles"].append(stripped[2:].strip())
        elif indent <= 4:
            in_roles = False

    if current:
        models.append(current)

    for model in models:
        if wanted_role in model["roles"] and model["model"]:
            print(model["model"])
            return 0

    print(fallback)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
