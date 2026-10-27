#!/usr/bin/env bash
# Stand-in for the codex CLI: --version and a --help that lists no model choices.
case ${1:-} in
--version) echo "codex-cli 0.0.1" ;;
--help)
	cat <<'HELP'
Usage: codex [OPTIONS]

Options:
  -m, --model <MODEL>  Model the agent should use
  -h, --help           Print help
HELP
	;;
esac
