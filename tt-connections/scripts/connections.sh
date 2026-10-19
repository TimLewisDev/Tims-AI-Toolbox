#!/usr/bin/env bash
# connections.sh: which connections (MCP servers, CLI logins, git settings) a
# project needs, and which of them are missing. The list for a project comes
# from a "connection pack" installed in a user-level folder, never from this
# repo. Needs bash and awk only. Writes nothing but installed packs and the
# link file; it never runs a pack's setup command (the skill does, after a yes).
set -u

usage() {
	cat >&2 <<'EOF'
usage: connections.sh status [dir]              the pack for dir's project and how each connection stands
       connections.sh next [dir] [--skip a,b]   the first connection still to set up, as key=value lines
       connections.sh check <id> [dir]          one connection's state (ok, missing, auth, down); exit 0 if ok
       connections.sh which [dir]               the pack that applies to dir's project
       connections.sh list                      installed packs and what they match
       connections.sh pack install <file|dir>   install a .pack file, or every .pack in a folder
       connections.sh link <pack>               use this pack for dir's project, whatever its remote
       connections.sh unlink                    go back to matching by remote

A pack is a tab-separated text file. Comment lines start with "#":
  # name: <pack name>
  # match: <glob on the git remote url>        (repeatable)
  <id> TAB <kind> TAB <label> TAB <check> TAB <setup> TAB <next step>
kind "mcp": check is the MCP server name, looked up in `claude mcp list`.
kind "cmd": check is a shell command run in the project; exit 0 means connected.
Use "-" for an empty setup or next step.

Packs and links live in ${TT_CONNECTIONS_HOME:-${CLAUDE_CONFIG_DIR:-$HOME/.claude}/tt-connections}
TT_CLAUDE_BIN names the claude executable (default: claude).
Exit: 0 ok, 1 gaps (status) or nothing left (next), 2 usage error, 3 no pack for the project.
EOF
}

home=${TT_CONNECTIONS_HOME:-${CLAUDE_CONFIG_DIR:-$HOME/.claude}/tt-connections}
packs="$home/packs"
links="$home/links.tsv"
claude_bin=${TT_CLAUDE_BIN:-claude}
TAB=$'\t'
mcp_out=""
trap '[ -n "$mcp_out" ] && rm -f "$mcp_out"' EXIT

# need_dir <dir>: the folder's absolute path, or exit 2
need_dir() {
	local d
	d=$(cd "${1:-.}" 2>/dev/null && pwd) || { echo "connections.sh: no such folder: ${1:-.}" >&2; exit 2; }
	printf '%s\n' "$d"
}

# project_key <dir>: the git root of dir, or dir itself
project_key() { git -C "$1" rev-parse --show-toplevel 2>/dev/null || printf '%s\n' "$1"; }

remote_url() { git -C "$1" config --get remote.origin.url 2>/dev/null | tr -d '\r'; }

# pack_name <file>: the pack's name, else its file name
pack_name() {
	local n
	n=$(awk -F': *' '{ sub(/\r$/, "") } /^# *name:/ { print $2; exit }' "$1")
	printf '%s\n' "${n:-$(basename "$1" .pack)}"
}

# pack_file <name or file name>: the installed pack's path, if any
pack_file() {
	local n=${1%.pack}
	[ -f "$packs/$n.pack" ] && { printf '%s\n' "$packs/$n.pack"; return 0; }
	local f
	for f in "$packs"/*.pack; do
		[ -f "$f" ] && [ "$(pack_name "$f")" = "$n" ] && { printf '%s\n' "$f"; return 0; }
	done
	return 1
}

# pack_for <dir>: the pack that applies (a link wins over a remote match), or nothing
pack_for() {
	local dir=$1 key linked url f pat
	key=$(project_key "$dir")
	if [ -f "$links" ]; then
		linked=$(awk -F'\t' -v k="$key" '{ sub(/\r$/, "") } $1 == k { print $2; exit }' "$links")
		if [ -n "$linked" ]; then pack_file "$linked" && return 0; fi
	fi
	url=$(remote_url "$dir")
	[ -n "$url" ] || return 1
	for f in "$packs"/*.pack; do
		[ -f "$f" ] || continue
		while IFS= read -r pat; do
			[ -n "$pat" ] || continue
			# shellcheck disable=SC2254
			case $url in $pat) printf '%s\n' "$f"; return 0 ;; esac
		done < <(awk '{ sub(/\r$/, "") } /^# *match:/ { sub(/^# *match: */, ""); print }' "$f")
	done
	return 1
}

# rows <pack>: the connection rows, without comments, blank lines or CRs
rows() { awk '{ sub(/\r$/, "") } /^#/ || /^[ \t]*$/ { next } { print }' "$1"; }

# need_pack <dir>: set $pack, or say there is none and return 3
need_pack() {
	pack=$(pack_for "$1") && return 0
	echo "No connection pack for this project."
	return 3
}

# mcp_list: run `claude mcp list` once per invocation
mcp_list() {
	[ -n "$mcp_out" ] && return 0
	mcp_out=$(mktemp)
	if ! command -v "$claude_bin" >/dev/null 2>&1; then
		echo "connections.sh: $claude_bin not found, so MCP servers show as missing" >&2
		return 0
	fi
	"$claude_bin" mcp list >"$mcp_out" 2>/dev/null </dev/null
}

# mcp_state <server>: ok, auth, down or missing
mcp_state() {
	mcp_list
	awk -v n="$1" '
		BEGIN { n = tolower(n) }
		{ sub(/\r$/, "") }
		index(tolower($0), n ":") == 1 {
			s = tolower($0); found = 1
			if (s ~ /needs auth/) print "auth"
			else if (s ~ /connected/ && s !~ /not connected/) print "ok"
			else print "down"
			exit
		}
		END { if (!found) print "missing" }' "$mcp_out"
}

# prep <pack>: list the MCP servers now, in this shell, so state (which runs
# in a subshell) reads one cached `claude mcp list` instead of running it per row
prep() { rows "$1" | awk -F'\t' '$2 == "mcp" { f = 1 } END { exit !f }' && mcp_list; return 0; }

# state <dir> <kind> <check>: ok, auth, down or missing
state() {
	case $2 in
	mcp) mcp_state "$3" ;;
	cmd)
		if command -v timeout >/dev/null 2>&1; then
			(cd "$1" && timeout 30 bash -c "$3") >/dev/null 2>&1 </dev/null
		else
			(cd "$1" && bash -c "$3") >/dev/null 2>&1 </dev/null
		fi && echo ok || echo missing ;;
	*) echo missing ;;
	esac
}

status() {
	local dir pack ok=0 total=0 gaps="" id kind label check setup nxt st tag
	dir=$(need_dir "${1:-.}") || exit 2
	need_pack "$dir" || return 3
	prep "$pack"
	printf 'Pack: %s (%s)\n\n' "$(pack_name "$pack")" "$pack"
	while IFS=$'\t' read -r id kind label check setup nxt; do
		total=$((total + 1))
		st=$(state "$dir" "$kind" "$check")
		case $st in
		ok) tag="ok            "; ok=$((ok + 1)) ;;
		auth) tag="NEEDS AUTH    "; gaps="$gaps $id" ;;
		down) tag="NOT CONNECTED "; gaps="$gaps $id" ;;
		*) tag="MISSING       "; gaps="$gaps $id" ;;
		esac
		printf '  %s %-14s %s\n' "$tag" "$id" "$label"
	done < <(rows "$pack")
	printf '\n%d of %d connected.' "$ok" "$total"
	[ -n "$gaps" ] && printf ' Still to do:%s.' "$gaps"
	printf '\n'
	[ -z "$gaps" ]
}

next() {
	local dir="." skip=","
	while [ $# -gt 0 ]; do
		case $1 in
		--skip) skip=",${2:-},"; shift 2 ;;
		*) dir=$1; shift ;;
		esac
	done
	local pack id kind label check setup nxt st found="" left=0
	dir=$(need_dir "$dir") || exit 2
	need_pack "$dir" || return 3
	prep "$pack"
	while IFS=$'\t' read -r id kind label check setup nxt; do
		case $skip in *",$id,"*) continue ;; esac
		st=$(state "$dir" "$kind" "$check")
		[ "$st" = ok ] && continue
		left=$((left + 1))
		[ -n "$found" ] && continue
		found="id=$id${TAB}state=$st${TAB}label=$label${TAB}kind=$kind${TAB}setup=$setup${TAB}handoff=$nxt"
	done < <(rows "$pack")
	if [ -z "$found" ]; then echo "nothing left to set up"; return 1; fi
	printf '%s\n' "$found" | tr '\t' '\n'
	printf 'remaining=%d\n' "$left"
}

check() {
	local want=${1:-} dir id kind label chk setup nxt st
	[ -n "$want" ] || { usage; exit 2; }
	dir=$(need_dir "${2:-.}") || exit 2
	need_pack "$dir" || return 3
	prep "$pack"
	while IFS=$'\t' read -r id kind label chk setup nxt; do
		[ "$id" = "$want" ] || continue
		st=$(state "$dir" "$kind" "$chk")
		echo "$st"
		[ "$st" = ok ]
		return
	done < <(rows "$pack")
	echo "connections.sh: no connection \"$want\" in $(pack_name "$pack")" >&2
	return 2
}

which_pack() {
	local dir pack
	dir=$(need_dir "${1:-.}") || exit 2
	need_pack "$dir" || return 3
	printf '%s\t%s\n' "$(pack_name "$pack")" "$pack"
}

list() {
	local f n=0
	for f in "$packs"/*.pack; do
		[ -f "$f" ] || continue
		n=$((n + 1))
		printf '%s\t%s\n' "$(pack_name "$f")" "$(awk '{ sub(/\r$/, "") } /^# *match:/ { sub(/^# *match: */, ""); printf "%s%s", s, $0; s = ", " }' "$f")"
	done
	[ "$n" -gt 0 ] || echo "no packs installed in $packs"
}

# valid_pack <file>: has a match line and rows with at least five fields
valid_pack() {
	grep -q '^# *match:' "$1" || { echo "connections.sh: $1 has no \"# match:\" line" >&2; return 1; }
	local bad
	bad=$(rows "$1" | awk -F'\t' 'NF < 5 { n++ } END { print n + 0 }')
	[ "$bad" = 0 ] || { echo "connections.sh: $1 has $bad row(s) with fewer than 5 tab-separated fields" >&2; return 1; }
	[ -n "$(rows "$1")" ] || { echo "connections.sh: $1 has no connections" >&2; return 1; }
}

pack_cmd() {
	[ "${1:-}" = install ] && [ -n "${2:-}" ] || { usage; exit 2; }
	local src=$2 f n=0 rc=0
	[ -e "$src" ] || { echo "connections.sh: no such file or folder: $src" >&2; exit 2; }
	mkdir -p "$packs" || exit 2
	for f in "$src" "$src"/*.pack; do
		[ -f "$f" ] || continue
		case $f in *.pack) ;; *) continue ;; esac
		if valid_pack "$f"; then
			cp "$f" "$packs/$(basename "$f")" && { echo "installed $(basename "$f")"; n=$((n + 1)); }
		else
			rc=2
		fi
	done
	[ "$n" -gt 0 ] || { echo "connections.sh: nothing installed from $src" >&2; exit 2; }
	return "$rc"
}

# setlink <dir> <pack or empty>: replace this project's row (empty pack removes it)
setlink() {
	local key tmp
	key=$(project_key "$1")
	mkdir -p "$home" || exit 2
	tmp="$links.$$"
	{ [ -f "$links" ] && awk -F'\t' -v k="$key" '$1 != k' "$links"; [ -n "$2" ] && printf '%s\t%s\t%s\n' "$key" "$2" "$(date +%F)"; } >"$tmp"
	mv "$tmp" "$links"
}

cmd=${1:-status}
[ $# -gt 0 ] && shift
case $cmd in
status) status "$@" ;;
next) next "$@" ;;
check) check "$@" ;;
which) which_pack "$@" ;;
list) list ;;
pack) pack_cmd "$@" ;;
link)
	[ -n "${1:-}" ] || { usage; exit 2; }
	pack_file "$1" >/dev/null || { echo "connections.sh: no installed pack \"$1\"" >&2; exit 2; }
	d=$(need_dir .) || exit 2
	setlink "$d" "$(pack_name "$(pack_file "$1")")" && echo "linked $1" ;;
unlink)
	d=$(need_dir .) || exit 2
	setlink "$d" "" && echo "unlinked" ;;
-h | --help) usage ;;
*) usage; exit 2 ;;
esac
