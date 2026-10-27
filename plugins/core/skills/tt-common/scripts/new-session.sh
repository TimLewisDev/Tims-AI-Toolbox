#!/usr/bin/env bash
# new-session.sh: open a fresh Claude Code session in a new terminal window or
# tab, started with a prompt such as /tt-execute-lite "<brief>". A skill cannot
# clear the session it runs in; this starts another one. Run it only when the
# engineer has said yes.
set -u

usage() {
	cat >&2 <<'EOF'
usage: new-session.sh [--print] [--name "<name>"] [--model <m>] [--effort <e>] <folder> "<prompt>"

Opens a new terminal in <folder> running: claude [--model <m>] [--effort <e>] [-n "<name>"] "<prompt>"
(an interactive session that starts with the prompt, so a slash command works;
--name sets the session's display name, shown in the prompt box and /resume;
--model and --effort start the session on that model and thinking effort. A
skill can't switch a running session, so a launch is how one is forced;
model-config.sh args builds the same flags from the `session` setting).

  Windows (Git Bash)  inside a JetBrains (Rider) terminal, a new tab in that terminal, typed in with
                      keystrokes (rider-tab.ps1; only when Rider has the Terminal focused);
                      otherwise Windows Terminal (wt.exe), else a cmd window.
                      TT_SESSION_TERMINAL=wt skips the Rider attempt.
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

here=$(cd "$(dirname "$0")" && pwd)
print=0; name=""; model=""; effort=""
while :; do
	case ${1:-} in
	--print) print=1; shift ;;
	--name) [ $# -ge 2 ] || usage; name=$2; shift 2 ;;
	--model) [ $# -ge 2 ] || usage; model=$2; shift 2 ;;
	--effort) [ $# -ge 2 ] || usage; effort=$2; shift 2 ;;
	*) break ;;
	esac
done
# a model or effort is a word (alias, id, level); "-" means leave it to claude
for v in "$model" "$effort"; do
	case $v in "" | - ) ;; *[!A-Za-z0-9._:/-]*) echo "new-session.sh: --model and --effort take a plain word, not '$v'" >&2; exit 2 ;; esac
done
flags=""
case $model in "" | - ) ;; *) flags="--model $model" ;; esac
case $effort in "" | - ) ;; *) flags="${flags:+$flags }--effort $effort" ;; esac
case ${1:-} in -h | --help) usage ;; esac
[ $# -eq 2 ] || usage
dir=$1; prompt=$2
[ -d "$dir" ] || { echo "new-session.sh: no such folder: $dir" >&2; exit 2; }
[ -n "$prompt" ] || usage
claude=$(command -v claude) || { echo "new-session.sh: no claude command on the PATH" >&2; exit 2; }
dir=$(cd "$dir" && pwd)

manual() {
	local q n=""
	q=$(printf '%s' "$prompt" | sed "s/'/'\\\\''/g")
	if [ -n "$name" ]; then
		n=$(printf '%s' "$name" | sed "s/'/'\\\\''/g")
		n="-n '$n' "
	fi
	printf 'Open a new terminal and run:\n  cd "%s" && claude %s%s'"'%s'"'\n' "$dir" "${flags:+$flags }" "$n" "$q"
}

if [ "$print" = 1 ]; then
	manual
	case $(uname -s) in
	MINGW* | MSYS* | CYGWIN*)
		if [ "${TERMINAL_EMULATOR:-}" = JetBrains-JediTerm ] && [ "${TT_SESSION_TERMINAL:-auto}" != wt ]; then
			echo "(inside a Rider terminal it would try a new Rider terminal tab through keystrokes, then fall back to:)"
		fi
		echo "(it would open a Windows Terminal tab through wt.exe, or a cmd window)" ;;
	Darwin) echo "(it would open Terminal.app)" ;;
	*) echo "(no terminal would be opened on this system)" ;;
	esac
	exit 0
fi

launcher=$(mktemp "${TMPDIR:-/tmp}/tt-session.XXXXXX")
{
	echo '#!/usr/bin/env bash'
	# no path conversion of a slash command such as /tt-workflow, whoever starts the launcher
	echo "export MSYS2_ARG_CONV_EXCL='*'"
	# the terminal tab's title, for terminals that take it from the program (Windows Terminal)
	[ -z "$name" ] || printf '%s\n' "printf '\\033]0;%s\\007' $(printf '%q' "$name")"
	printf 'cd %q || exit 1\n' "$dir"
	# flags is only words (checked above), so it is safe to leave unquoted
	if [ -n "$name" ]; then
		printf 'exec %q %s-n %q %q\n' "$claude" "${flags:+$flags }" "$name" "$prompt"
	else
		printf 'exec %q %s%q\n' "$claude" "${flags:+$flags }" "$prompt"
	fi
} >"$launcher"
chmod +x "$launcher"

case $(uname -s) in
MINGW* | MSYS* | CYGWIN*)
	export MSYS2_ARG_CONV_EXCL='*'
	dirw=$(cygpath -w "$dir"); launchw=$(cygpath -w "$launcher"); bashw=$(cygpath -w "$(command -v bash)")
	# Inside a Rider terminal, open the session in a new Rider terminal tab.
	if [ "${TERMINAL_EMULATOR:-}" = JetBrains-JediTerm ] && [ "${TT_SESSION_TERMINAL:-auto}" != wt ] && command -v powershell.exe >/dev/null 2>&1; then
		powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$(cygpath -w "$here/rider-tab.ps1")" "$launchw" "$bashw" "$name" >/dev/null 2>&1
		case $? in
		0) echo "opened a new Rider terminal tab in $dir"; exit 0 ;;
		3) # a tab is open with the command typed but nothing running: don't open a second session
			echo "a new Rider terminal tab was opened but the session did not start in it; check that tab"
			manual; exit 1 ;;
		esac
	fi
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
