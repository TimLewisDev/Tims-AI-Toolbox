#!/usr/bin/env bash
# tatty.sh: Tatty, the tt toolbox's robot. Draws the avatar with one quip.
# Shared by tt-guide and tt-workflow. Needs bash and awk only. Writes nothing.
set -u

usage() {
	cat >&2 <<'EOF'
usage: tatty.sh [banner]    Tatty with a random quip
       tatty.sh quip        one quip
       tatty.sh celebrate   Tatty with raised arms and a congratulation, for a finished feature

TT_GUIDE_ASCII=1 draws Tatty without box-drawing characters.
Exit: 0 ok, 2 usage error.
EOF
}

here=$(readlink -f "$(dirname "$0")" 2>/dev/null) || here=$(cd -P "$(dirname "$0")" && pwd -P)
quips="$(dirname "$here")/quips.txt"
cheers="$(dirname "$here")/celebrate-quips.txt"

# pick <file> <fallback>: one random line of the file, or the fallback if it has none
pick() {
	local n
	n=$(awk 'NF && !/^#/' "$1" 2>/dev/null | wc -l | tr -d ' ')
	[ "${n:-0}" -gt 0 ] || { echo "$2"; return; }
	awk -v k=$((RANDOM % n + 1)) '{ sub(/\r$/, "") } NF && !/^#/ && ++i == k { print; exit }' "$1"
}

quip() { pick "$quips" "Hello. I'd tell a joke, but my quips file is missing."; }

cheer() { pick "$cheers" "Finished! I'd congratulate you properly, but my cheers file is missing."; }

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

party() {
	if [ "${TT_GUIDE_ASCII:-}" = 1 ]; then
		cat <<EOF
   * . * . * . * . *
   \\[-o-]/
   +-----+
   | ^ ^ |   Tatty
   |  v  |   "$1"
   +-+-+-+
     | |
EOF
	else
		cat <<EOF
   * . * . * . * . *
   \\[¬º-°]/
   ┌─────┐
   │ ^ ^ │   Tatty
   │  ▽  │   "$1"
   └┬───┬┘
    ╨   ╨
EOF
	fi
}

case ${1:-banner} in
banner) art "$(quip)" ;;
quip) quip ;;
celebrate) party "$(cheer)" ;;
-h | --help) usage ;;
*) usage; exit 2 ;;
esac
