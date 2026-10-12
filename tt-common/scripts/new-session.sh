#!/usr/bin/env bash
# new-session.sh: open a fresh Claude Code session in a new terminal window or
# tab, started with a prompt such as /tt-execute-lite "<brief>". A skill cannot
# clear the session it runs in; this starts another one. Run it only when the
# engineer has said yes.
set -u

usage() {
	cat >&2 <<'EOF'
usage: new-session.sh [--print] <folder> "<prompt>"

Opens a new terminal in <folder> running: claude "<prompt>"
(an interactive session that starts with the prompt, so a slash command works).

  Windows (Git Bash)  Windows Terminal (wt.exe), else a cmd window
  macOS               Terminal.app, through osascript
  elsewhere           nothing is opened; the command is printed

--print shows what would run and opens nothing. The prompt and the folder are
written into a small launcher script in the temp folder, so spaces and quotes
in paths and prompts survive every shell on the way.
Exit: 0 opened (or --print), 1 could not open a terminal (the command is
printed instead), 2 usage error or no claude command.
EOF
	exit 2
}

print=0
[ "${1:-}" = --print ] && { print=1; shift; }
case ${1:-} in -h | --help) usage ;; esac
[ $# -eq 2 ] || usage
dir=$1; prompt=$2
[ -d "$dir" ] || { echo "new-session.sh: no such folder: $dir" >&2; exit 2; }
[ -n "$prompt" ] || usage
claude=$(command -v claude) || { echo "new-session.sh: no claude command on the PATH" >&2; exit 2; }
dir=$(cd "$dir" && pwd)

manual() {
	local q
	q=$(printf '%s' "$prompt" | sed "s/'/'\\\\''/g")
	printf 'Open a new terminal and run:\n  cd "%s" && claude '"'%s'"'\n' "$dir" "$q"
}

if [ "$print" = 1 ]; then
	manual
	case $(uname -s) in
	MINGW* | MSYS* | CYGWIN*) echo "(it would open a Windows Terminal tab through wt.exe, or a cmd window)" ;;
	Darwin) echo "(it would open Terminal.app)" ;;
	*) echo "(no terminal would be opened on this system)" ;;
	esac
	exit 0
fi

launcher=$(mktemp "${TMPDIR:-/tmp}/tt-session.XXXXXX")
{
	echo '#!/usr/bin/env bash'
	printf 'cd %q || exit 1\n' "$dir"
	printf 'exec %q %q\n' "$claude" "$prompt"
} >"$launcher"
chmod +x "$launcher"

case $(uname -s) in
MINGW* | MSYS* | CYGWIN*)
	export MSYS2_ARG_CONV_EXCL='*'
	dirw=$(cygpath -w "$dir"); launchw=$(cygpath -w "$launcher"); bashw=$(cygpath -w "$(command -v bash)")
	if command -v wt.exe >/dev/null 2>&1; then
		wt.exe -d "$dirw" "$bashw" "$launchw" >/dev/null 2>&1 && { echo "opened a Windows Terminal tab in $dir"; exit 0; }
	fi
	cmd.exe /c start "" /D "$dirw" "$bashw" "$launchw" >/dev/null 2>&1 && { echo "opened a cmd window in $dir"; exit 0; }
	;;
Darwin)
	osascript -e "tell application \"Terminal\" to do script \"bash $(printf '%q' "$launcher")\"" -e 'tell application "Terminal" to activate' >/dev/null 2>&1 &&
		{ echo "opened Terminal in $dir"; exit 0; }
	;;
esac
manual
exit 1
