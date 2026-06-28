#!/usr/bin/env python3
import argparse
import json


def parse_args():
    parser = argparse.ArgumentParser(description="Write LocalAIbundle install report")
    parser.add_argument("--output", required=True)
    parser.add_argument("--version", required=True)
    parser.add_argument("--timestamp", required=True)
    parser.add_argument("--profile", required=True)
    parser.add_argument("--model-tier", required=True)
    parser.add_argument("--arch", required=True)
    parser.add_argument("--cpu", required=True)
    parser.add_argument("--gpu-cores", required=True)
    parser.add_argument("--ram-gb", required=True, type=int)
    parser.add_argument("--completion-model", required=True)
    parser.add_argument("--chat-model", required=True)
    parser.add_argument("--embed-model", required=True)
    parser.add_argument("--total-model-size", required=True)
    parser.add_argument("--ollama-binary", default="")
    parser.add_argument("--ollama-version", default="")
    parser.add_argument("--ollama-server-running", action="store_true")
    parser.add_argument("--launchagent-ok", action="store_true")
    parser.add_argument("--vscode-installed", action="store_true")
    parser.add_argument("--continue-installed", action="store_true")
    parser.add_argument("--continue-config-ok", action="store_true")
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    report = {
        "version": args.version,
        "timestamp": args.timestamp,
        "profile": args.profile,
        "model_tier": args.model_tier,
        "hardware": {
            "arch": args.arch,
            "cpu": args.cpu,
            "gpu_cores": args.gpu_cores,
            "ram_gb": args.ram_gb,
        },
        "models": {
            "completion": args.completion_model,
            "chat": args.chat_model,
            "embedding": args.embed_model,
            "total_estimated_size": args.total_model_size,
        },
        "components": {
            "ollama_binary": args.ollama_binary,
            "ollama_version": args.ollama_version,
            "ollama_server_running": args.ollama_server_running,
            "launchagent_ok": args.launchagent_ok,
            "vscode_installed": args.vscode_installed,
            "continue_installed": args.continue_installed,
            "continue_config_ok": args.continue_config_ok,
        },
    }

    with open(args.output, "w", encoding="utf-8") as fh:
        json.dump(report, fh, indent=2)
        fh.write("\n")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
