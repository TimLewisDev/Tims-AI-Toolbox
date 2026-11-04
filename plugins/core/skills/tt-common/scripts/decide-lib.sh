#!/usr/bin/env bash
# decide-lib.sh: helpers shared by the scripts that own a decision document
# (challenges.sh, decide.sh). Sourced, never run. Needs bash and awk only.
#
#   dl_lock <doc>            take the document's lock (a folder beside it); waits
#                            up to 10 s, and treats a lock older than a minute as
#                            left behind by a crash. Released on exit, which
#                            also runs $DL_CLEAN (the caller's own clean-up).
#   dl_crlf <file>           prints 1 if the file has CRLF line endings, else 0
#   dl_bom <file>            prints 1 if the file starts with a UTF-8 BOM, else 0
#   dl_put <doc> <tmp>       moves the finished temp file over the document
#   dl_today                 the date as YYYY-MM-DD
#
# Some awks drop the CR on reading, so the line ending is noted once per file
# (dl_crlf) and written back by the awk program, never decided per line.

dl_lock() {
	local d n i=0
	d=$(dirname "$1"); n=$(basename "$1")
	DL_LOCK="$d/.$n.lock"
	while ! mkdir "$DL_LOCK" 2>/dev/null; do
		i=$((i + 1))
		if [ -n "$(find "$DL_LOCK" -maxdepth 0 -mmin +1 2>/dev/null)" ]; then rmdir "$DL_LOCK" 2>/dev/null; continue; fi
		if [ $i -ge 200 ]; then echo "$(basename "$0"): the document is busy (lock $DL_LOCK)" >&2; exit 1; fi
		sleep 0.05
	done
	trap 'rmdir "$DL_LOCK" 2>/dev/null; eval "${DL_CLEAN:-}"' EXIT
}

dl_crlf() { if [ "$(tr -cd '\r' <"$1" | wc -c | tr -d ' ')" -gt 0 ]; then echo 1; else echo 0; fi; }
dl_bom() { if [ "$(head -c 3 "$1" | od -An -tx1 | tr -d ' \n')" = efbbbf ]; then echo 1; else echo 0; fi; }
dl_put() { mv -f "$2" "$1"; }
dl_today() { date +%F; }
