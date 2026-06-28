#!/usr/bin/env python3
import json
import re
import sys


def strip_jsonc(source: str) -> str:
    out = []
    i = 0
    in_string = False
    escaped = False

    while i < len(source):
        ch = source[i]
        nxt = source[i + 1] if i + 1 < len(source) else ""

        if in_string:
            out.append(ch)
            if escaped:
                escaped = False
            elif ch == "\\":
                escaped = True
            elif ch == '"':
                in_string = False
            i += 1
            continue

        if ch == '"':
            in_string = True
            out.append(ch)
            i += 1
        elif ch == "/" and nxt == "/":
            i += 2
            while i < len(source) and source[i] not in "\r\n":
                i += 1
        elif ch == "/" and nxt == "*":
            i += 2
            while i + 1 < len(source) and source[i : i + 2] != "*/":
                i += 1
            i += 2
        else:
            out.append(ch)
            i += 1

    stripped = "".join(out)
    return re.sub(r",\s*([}\]])", r"\1", stripped)


def main() -> int:
    if len(sys.argv) != 2:
        print("usage: update-vscode-settings.py <settings.json>", file=sys.stderr)
        return 2

    path = sys.argv[1]
    text = open(path, encoding="utf-8").read()

    try:
        data = json.loads(strip_jsonc(text) or "{}")
    except json.JSONDecodeError as exc:
        print(f"Could not parse VS Code settings.json: {exc}", file=sys.stderr)
        return 1

    if not isinstance(data, dict):
        print("VS Code settings.json must contain a JSON object", file=sys.stderr)
        return 1

    data["continue.telemetryEnabled"] = False
    with open(path, "w", encoding="utf-8") as fh:
        json.dump(data, fh, indent=2, sort_keys=True)
        fh.write("\n")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
