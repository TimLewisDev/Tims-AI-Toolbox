#!/usr/bin/env bash
# tatty.sh: Tatty, the tt toolbox's robot. Draws the avatar with one quip.
# Shared by tt-guide and tt-workflow. Needs bash only. Writes nothing.
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

_s=${0//\\//}; case $_s in */*) d=${_s%/*} ;; *) d=. ;; esac
if [ -f "$d/../quips.txt" ] && [ -r "$d/../quips.txt" ]; then
	quips="$d/../quips.txt"
	cheers="$d/../celebrate-quips.txt"
else
	here=$(readlink -f "$(dirname "$0")" 2>/dev/null) || here=$(cd -P "$(dirname "$0")" && pwd -P)
	quips="$(dirname "$here")/quips.txt"
	cheers="$(dirname "$here")/celebrate-quips.txt"
fi

# pick <file> <fallback>: sets REPLY to one random line of the file, or the fallback if it has none
pick() {
	local line
	local -a lines=()
	if [ -r "$1" ]; then
		while IFS= read -r line || [ -n "$line" ]; do
			line=${line%$'\r'}
			case $line in
			'#'*) continue ;;
			*[![:blank:]]*) lines+=("$line") ;;
			esac
		done <"$1"
	fi
	if [ "${#lines[@]}" -gt 0 ]; then
		REPLY=${lines[RANDOM % ${#lines[@]}]}
	else
		REPLY=$2
	fi
}

quip() { pick "$quips" "Hello. I'd tell a joke, but my quips file is missing."; }

cheer() { pick "$cheers" "Finished! I'd congratulate you properly, but my cheers file is missing."; }

art() {
	if [ "${TT_GUIDE_ASCII:-}" = 1 ]; then
		printf '%s\n' \
			'    [-o-]' \
			'   +-----+' \
			'   | o o |   Tatty' \
			"   |  v  |   \"$1\"" \
			'   +-+-+-+' \
			'     | |'
	else
		printf '%s\n' \
			'    [¬º-°]¬' \
			'   ┌─────┐' \
			'   │ ◉ ◉ │   Tatty' \
			"   │  ▽  │   \"$1\"" \
			'   └┬───┬┘' \
			'    ╨   ╨'
	fi
}

party() {
	if [ "${TT_GUIDE_ASCII:-}" = 1 ]; then
		printf '%s\n' \
			'   * . * . * . * . *' \
			'   \[-o-]/' \
			'   +-----+' \
			'   | ^ ^ |   Tatty' \
			"   |  v  |   \"$1\"" \
			'   +-+-+-+' \
			'     | |'
	else
		printf '%s\n' \
			'   * . * . * . * . *' \
			'   \[¬º-°]/' \
			'   ┌─────┐' \
			'   │ ^ ^ │   Tatty' \
			"   │  ▽  │   \"$1\"" \
			'   └┬───┬┘' \
			'    ╨   ╨'
	fi
}

case ${1:-banner} in
banner) quip; art "$REPLY" ;;
quip) quip; printf '%s\n' "$REPLY" ;;
celebrate) cheer; party "$REPLY" ;;
-h | --help) usage ;;
*) usage; exit 2 ;;
esac
