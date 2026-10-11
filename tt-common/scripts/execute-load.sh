#!/usr/bin/env bash
# execute-load.sh: print, in one call, everything tt-execute reads to start a
# session: the Task Status's header, Resume Here and boards, the breakdown's
# header and Work Units table, and the current unit's block up to its first
# card.
set -eu

usage() {
	cat >&2 <<'EOF'
usage: execute-load.sh <task status.md> <task breakdown.md> [--unit <WU>]

Prints, each under a "==== <what>" line:
  status     the "# Status", "# Resume Here", "# Work Unit Board" and
             "# Task Board" sections;
  breakdown  the header (everything before the first "## ") and "## Work Units";
  unit       the "## <WU> — " block, from its heading up to its first "### "
             card: plain English, Validation, How to validate, checks block.
The unit is --unit, else the header's "Current Unit:", else the unit its
"Next:" line names; with none (all Done) the unit part says so.

Exit: 0 printed, 2 usage error (missing section or unit).
EOF
	exit 2
}

die() { echo "execute-load.sh: $*" >&2; exit 2; }

[ $# -ge 2 ] || usage
case "$1" in -h | --help) usage ;; esac
status=$1; bd=$2; shift 2
wu=""
while [ $# -gt 0 ]; do case "$1" in --unit) wu=${2:?}; shift 2 ;; *) usage ;; esac; done
[ -f "$status" ] || die "no such file: $status"
[ -f "$bd" ] || die "no such file: $bd"
md="$(dirname "$0")/md-section.sh"
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
tr -d '\r' <"$status" >"$work/status"
tr -d '\r' <"$bd" >"$work/bd"

echo "==== status: $status"
bash "$md" get "$work/status" "# Status" "# Resume Here" "# Work Unit Board" "# Task Board" ||
	die "the Task Status is missing # Status, # Resume Here or a board"

echo "==== breakdown: $bd"
awk '/^## / { exit } { print }' "$work/bd"
bash "$md" get "$work/bd" "## Work Units" || die "the breakdown has no ## Work Units"

if [ -z "$wu" ]; then
	wu=$(sed -n 's/^- Current Unit:[ \t]*\(WU[0-9][0-9]*[a-z]*\).*/\1/p' "$work/status" | head -n 1)
	[ -n "$wu" ] || wu=$(sed -n 's/^- Next:.*\(WU[0-9][0-9]*[a-z]*\).*/\1/p' "$work/status" | head -n 1)
fi
if [ -z "$wu" ]; then
	echo "==== unit: none (no current or next unit in the header)"
	exit 0
fi
echo "==== unit: $wu"
awk -v H="## $wu — " '
index($0, H) == 1 { on = 1; print; next }
on && (/^### / || /^## /) { exit }
on { print }
END { if (!on) exit 3 }' "$work/bd" || die "no \"## $wu — \" block in the breakdown"
