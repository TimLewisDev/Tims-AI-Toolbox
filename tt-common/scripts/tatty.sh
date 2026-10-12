#!/usr/bin/env bash
# tatty.sh: Tatty, the tt toolbox's robot. Draws the avatar with one quip.
# Shared by tt-guide and tt-workflow. Needs bash and awk only. Writes nothing.
set -u

usage() {
	cat >&2 <<'EOF'
usage: tatty.sh [banner]    Tatty with a random quip
       tatty.sh quip        one quip

TT_GUIDE_ASCII=1 draws Tatty without box-drawing characters.
Exit: 0 ok, 2 usage error.
EOF
}

here=$(readlink -f "$(dirname "$0")" 2>/dev/null) || here=$(cd -P "$(dirname "$0")" && pwd -P)
quips="$(dirname "$here")/quips.txt"

quip() {
	local n
	n=$(awk 'NF && !/^#/' "$quips" 2>/dev/null | wc -l | tr -d ' ')
	[ "${n:-0}" -gt 0 ] || { echo "Hello. I'd tell a joke, but my quips file is missing."; return; }
	awk -v k=$((RANDOM % n + 1)) '{ sub(/\r$/, "") } NF && !/^#/ && ++i == k { print; exit }' "$quips"
}

art() {
	if [ "${TT_GUIDE_ASCII:-}" = 1 ]; then
		cat <<EOF
    [-o-]
   +-----+
   | o o |   Tatty
   |  v  |   "$1"
   +-+-+-+
     | |
EOF
	else
		cat <<EOF
    [¬º-°]¬
   ┌─────┐
   │ ◉ ◉ │   Tatty
   │  ▽  │   "$1"
   └┬───┬┘
    ╨   ╨
EOF
	fi
}

case ${1:-banner} in
banner) art "$(quip)" ;;
quip) quip ;;
-h | --help) usage ;;
*) usage; exit 2 ;;
esac
