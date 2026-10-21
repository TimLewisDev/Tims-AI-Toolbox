#!/usr/bin/env bash
# run-checks.sh: run a work unit's Agent checks from the ```checks block in
# its Task Breakdown unit block, save each check's output, and write the
# validation attempt for status-record.sh. Replaces a subagent for units whose
# Agent checks are all commands.
set -eu

usage() {
	cat >&2 <<'EOF'
usage: run-checks.sh <task breakdown.md> <WU> <log folder> [--repo <dir>] [--why <text>] [--timeout <seconds>]

Reads the unit block ("## <WU> —" up to its first card): its Validation
checklist ("- [ ] <check> (Agent | Engineer | Agent + Engineer)", numbered
in order) and its checks block:

  ```checks
  <n> | <expect> | <command>
  ```

  <n>       the Validation item the command checks
  <expect>  ok        exit status 0
            empty     no output on stdout, exit status 0 or 1 (git grep finds nothing)
            nonempty  output on stdout and exit status 0
  <command> run with bash in the repo; it may contain "|"

Runs every command (default timeout 600s each), saving stdout and stderr to
<log folder>/check-<n>.log, and writes <log folder>/attempt.md: "- Run:",
"- Results:" with one "  - Check <n> (<text>) [<who>]: <result>…" line per
Validation item, "- Outcome:". Engineer items are pending; an Agent + Engineer
item is failed if its command failed, else pending (the engineer's part). An
Agent item with no command is blocked: check it by hand.
Record the attempt with: status-record.sh <status> validation <WU> --file <log folder>/attempt.md

Commands come from the breakdown; read the block before running it on a
breakdown you didn't write. The repo defaults to the header's "**Repo:**".
Prints one TSV row per item (n, who, result, command, evidence), then the
attempt path.

Exit: 0 every Agent check passed, 1 an Agent check failed or is blocked,
2 usage error or no checks block (run the unit's checks by hand or through
the run-agent-checks brief).
EOF
	exit 2
}

die() { echo "run-checks.sh: $*" >&2; exit 2; }

[ $# -ge 3 ] || usage
case "$1" in -h | --help) usage ;; esac
bd=$1; wu=$2; logdir=$3; shift 3
repo=""; why="agent checks"; to=600
while [ $# -gt 0 ]; do
	case "$1" in
		--repo) repo=${2:?}; shift 2 ;;
		--why) why=${2:?}; shift 2 ;;
		--timeout) to=${2:?}; shift 2 ;;
		*) usage ;;
	esac
done
[ -f "$bd" ] || die "no such file: $bd"
here=$(cd "$(dirname "$0")" && pwd)
if [ -z "$repo" ]; then
	repo=$(tr -d '\r' <"$bd" | sed -n '1,25p' | sed -n 's/.*\*\*Repo:\*\*[^`]*`\([^`]*\)`.*/\1/p' | head -n 1)
	[ -n "$repo" ] || die "no **Repo:** in the breakdown header; pass --repo"
fi
repo=$(printf '%s' "$repo" | sed 's#\\#/#g')
[ -d "$repo" ] || die "no such repo folder: $repo"
mkdir -p "$logdir"
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

bash "$here/md-section.sh" get "$bd" "## $wu —" 2>/dev/null | tr -d '\r' | awk '/^### / { exit } { print }' >"$work/unit" || true
[ -s "$work/unit" ] || die "no \"## $wu —\" unit block in $bd"

# Validation items: n<TAB>who<TAB>text. Checks: n<TAB>expect<TAB>command.
awk -v OUT="$work" '
function trim(s) { sub(/^[ \t]+/, "", s); sub(/[ \t]+$/, "", s); return s }
/^\*\*Validation\*\*/ { inv = 1; next }
/^\*\*How to validate\*\*/ { inv = 0 }
inv && /^- \[[ xX]\] / {
	t = substr($0, 7); who = "Agent"
	if (match(t, /\((Agent \+ Engineer|Agent|Engineer)\)[ \t]*$/)) { who = substr(t, RSTART + 1, RLENGTH - 2); sub(/[ \t]*$/, "", who); sub(/\)[ \t]*$/, "", who); t = trim(substr(t, 1, RSTART - 1)) }
	n++; print n "\t" who "\t" t > (OUT "/items"); next
}
/^```checks[ \t]*$/ { inc = 1; found = 1; next }
inc && /^```/ { inc = 0; next }
inc && NF {
	l = $0; p = index(l, "|"); if (!p) next
	cn = trim(substr(l, 1, p - 1)); l = substr(l, p + 1); p = index(l, "|"); if (!p) next
	ex = trim(substr(l, 1, p - 1)); cmd = trim(substr(l, p + 1))
	print cn "\t" ex "\t" cmd > (OUT "/checks")
}
END { if (!found) exit 3 }' "$work/unit" || { [ $? -eq 3 ] && die "no checks block in $wu: run its Agent checks by hand or through the run-agent-checks brief"; exit 2; }
touch "$work/items" "$work/checks"

oneline() { tr '\n' ' ' | sed 's/[[:space:]]\+/ /g; s/^ //; s/ $//' | cut -c1-240; }
now=$(date '+%Y-%m-%d %H:%M')
results="$work/results"; : >"$results"
nfail=0; nblock=0
printf 'n\twho\tresult\tcommand\tevidence\n'
while IFS=$'\t' read -r n who text; do
	cmd=$(awk -F'\t' -v N="$n" '$1 == N { sub(/^[^\t]*\t[^\t]*\t/, ""); print; exit }' "$work/checks")
	exp=$(awk -F'\t' -v N="$n" '$1 == N { print $2; exit }' "$work/checks")
	res=""; ev=""
	if [ -n "$cmd" ] && [ "$who" != Engineer ]; then
		log="$logdir/check-$n.log"
		set +e
		(cd "$repo" && timeout "$to" bash -c "$cmd") >"$work/out" 2>"$work/err"
		rc=$?
		set -e
		{ printf '$ %s\n# exit %s\n' "$cmd" "$rc"; cat "$work/out"; [ -s "$work/err" ] && { echo "# stderr"; cat "$work/err"; }; } >"$log"
		lines=$(wc -l <"$work/out" | tr -d ' ')
		case "$exp" in
			ok) [ "$rc" = 0 ] && ok=1 || ok=0 ;;
			empty) { [ ! -s "$work/out" ] && [ "$rc" -le 1 ]; } && ok=1 || ok=0 ;;
			nonempty) { [ -s "$work/out" ] && [ "$rc" = 0 ]; } && ok=1 || ok=0 ;;
			*) ok=x ;;
		esac
		if [ "$ok" = x ]; then
			res=blocked; ev="unknown expectation \"$exp\" in the checks block"
		elif [ "$rc" = 124 ]; then
			res=failed; ev="timed out after ${to}s"
		else
			if [ -s "$work/out" ]; then out=$(head -n 3 "$work/out" | oneline); else out="(no output)"; fi
			[ "$ok" = 1 ] && res=passed || res=failed
			ev="exit $rc; $lines line(s): $out"
			[ "$res" = failed ] && [ -s "$work/err" ] && ev="$ev; stderr: $(head -n 2 "$work/err" | oneline)"
		fi
		ev="\`$cmd\` → $ev (log: check-$n.log)"
		if [ "$who" = "Agent + Engineer" ] && [ "$res" = passed ]; then res=pending; ev="agent part passed: $ev; engineer part pending"; fi
	elif [ "$who" = Engineer ]; then
		res=pending
	else
		res=blocked; ev="no command in the checks block; check it by hand"
	fi
	case "$res" in failed) nfail=$((nfail + 1)) ;; blocked) [ "$who" != Engineer ] && nblock=$((nblock + 1)) ;; esac
	printf '%s\t%s\t%s\t%s\t%s\n' "$n" "$who" "$res" "${cmd:--}" "${ev:--}"
	printf '  - Check %s (%s) [%s]: %s%s\n' "$n" "$text" "$who" "$res" "${ev:+. $ev}" >>"$results"
done <"$work/items"

pending=$(grep -E ']: (pending|blocked)' "$results" | sed -n 's/^  - Check \([0-9]*\) .*/\1/p' | paste -sd ',' - | sed 's/,/, /g')
if [ "$nfail" -gt 0 ]; then outcome=Failed; elif [ -n "$pending" ]; then outcome="Pending (checks $pending)"; else outcome=Done; fi
{ echo "- Run: $now ($why)"; echo "- Results:"; cat "$results"; echo "- Outcome: $outcome"; } >"$logdir/attempt.md"
echo "attempt: $logdir/attempt.md (outcome: $outcome)"
[ "$nfail" -eq 0 ] && [ "$nblock" -eq 0 ] && exit 0
exit 1
