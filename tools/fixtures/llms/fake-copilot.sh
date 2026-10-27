#!/usr/bin/env bash
# Stand-in for the copilot CLI: --version and a --help that lists model choices.
case ${1:-} in
--version) echo "copilot 9.9.9" ;;
--help)
	cat <<'HELP'
Usage: copilot [options]

Options:
  --model <model>             Set the AI model to use (choices: "gpt-5", "claude-sonnet-4.5", "o4-mini")
  --reasoning-effort <level>  Reasoning effort (choices: "low", "medium", "high")
  -h, --help                  display help
HELP
	;;
esac
