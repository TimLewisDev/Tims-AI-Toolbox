#!/usr/bin/env bash
# decide-lib.sh: helpers shared by the scripts that own a decision document
# (challenges.sh, proposals.sh, questions.sh) and by workflow-state.sh, which
# reads them. Sourced, never run. Needs bash and awk only; dl_waiting_all
# needs bash 4.2 or later.
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
#   dl_ch_model <file>       one TSV line per challenge in a Challenges document
#   dl_pr_model <file>       the P and O lines of a Tech Proposals document
#   dl_qs_model <file>       the H, Q and O lines of a Questions list
#   dl_ch_status <file> [stage]   total=, open=, apply=, done= for Challenges
#   dl_pr_status <file>      the same counts for Tech Proposals
#   dl_qs_status <file>      the same counts plus title= and for= for Questions
#   dl_waiting_all <folder>  fills DL_WAIT (prefix -> sentence) with what waits
#                            for a decision or to be applied, per prefix
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

# dl_ch_model <file>: one TSV line per challenge:
#   1 id 2 stage 3 title 4 severity 5 target 6 assumption 7 why 8 evidence
#   9 question 10 recommended 11 take 12 outcome 13 resolution
dl_ch_model() {
	awk -v OFS='\t' '
	function trim(s) { gsub(/^[ \t]+|[ \t]+$/, "", s); return s }
	function clean(s) { gsub(/\t/, " ", s); return trim(s) }
	function endfield() { if (fname != "") val[fname] = trim(fval); fname = "" }
	function endblock(   rec, tk) {
		endfield()
		if (id != "") {
			rec = ""; tk = val["Take"]
			if (match(tk, /^\*Recommend [a-z]+\.\*/)) { rec = substr(tk, 12, RLENGTH - 13); tk = trim(substr(tk, RLENGTH + 1)) }
			print id, stage, clean(title), clean(sev), clean(target), clean(val["Assumption attacked"]), clean(val["Why it may be wrong"]), clean(val["Evidence"]), clean(val["Question for the engineer"]), rec, clean(tk), clean(val["Outcome"]), clean(val["Resolution"])
		}
		id = ""; sev = ""; target = ""; title = ""; split("", val)
	}
	{ sub(/\r$/, ""); if (NR == 1) sub(/^\357\273\277/, "") }
	/^```/ { fence = !fence }
	fence { next }
	/^## / {
		endblock(); s = substr($0, 4); p = index(s, " — challenged")
		stage = p ? substr(s, 1, p - 1) : ""; next
	}
	/^### CH[0-9]+/ {
		endblock(); id = $2; sub(/[^A-Za-z0-9]+$/, "", id)
		p = index($0, " — "); title = p ? substr($0, p + length(" — ")) : ""; next
	}
	/^#/ { endblock(); next }
	id == "" { next }
	/^\*\*/ { endblock(); next }
	/^[ \t]*$/ { endfield(); next }
	/^- \*\*[^*]+:\*\*/ {
		endfield(); s = substr($0, 5); p = index(s, ":**")
		fname = substr(s, 1, p - 1); fval = substr(s, p + 3)
		if (fname == "Severity") {
			q = index(fval, "**Target:**")
			if (q) { target = substr(fval, q + 11); sev = substr(fval, 1, q - 1) } else sev = fval
			gsub(/·/, "", sev); sev = trim(sev)
		}
		next
	}
	fname != "" { fval = fval " " trim($0) }
	END { endblock() }' "$1"
}

# dl_pr_model <file>: P and O lines:
#   P id question type status statusfull decides context recommendation chosen applied asked
#   O id key title recommended oneline benefit risk chosen
dl_pr_model() {
	awk -v OFS='\t' '
	function trim(s) { gsub(/^[ \t]+|[ \t]+$/, "", s); return s }
	function clean(s) { gsub(/\t/, " ", s); return trim(s) }
	# split a table row into c[1..n], keeping a "|" inside [[...|...]] links
	function cells(line,   s, i, n, out, inl) {
		s = line; out = ""; inl = 0
		for (i = 1; i <= length(s); i++) {
			ch = substr(s, i, 1)
			if (substr(s, i, 2) == "[[") inl = 1
			if (substr(s, i, 2) == "]]") inl = 0
			out = out ((ch == "|" && inl) ? "\001" : ch)
		}
		sub(/^[ \t]*\|/, "", out); sub(/\|[ \t]*$/, "", out)
		n = split(out, c, "|")
		for (i = 1; i <= n; i++) { gsub(/\001/, "|", c[i]); c[i] = trim(c[i]) }
		return n
	}
	function word(s) {
		if (s ~ /^Default applied/) return "Default applied"
		if (s ~ /^Open/) return "Open"; if (s ~ /^Decided/) return "Decided"; if (s ~ /^Superseded/) return "Superseded"
		return s
	}
	function endsec(   i) {
		if (id == "") return
		print "P", id, clean(q), clean(type), word(clean(st)), clean(st), clean(dec), clean(ctx), clean(rec), clean(chosen), applied + 0, asked + 0
		for (i = 1; i <= nk; i++) print "O", id, key[i], clean(otitle[i]), orec[i] + 0, clean(one[key[i]]), clean(ben[key[i]]), clean(risk[key[i]]), ochosen[i] + 0
		id = ""
	}
	{ sub(/\r$/, ""); if (NR == 1) sub(/^\357\273\277/, "") }
	/^```/ { fence = !fence }
	fence { next }
	/^## P[0-9]+ / {
		endsec(); id = $2; p = index($0, " — "); q = p ? substr($0, p + length(" — ")) : ""
		type = ""; st = ""; dec = ""; ctx = ""; rec = ""; chosen = ""; applied = 0; asked = 0; sub_ = ""; nk = 0; hdr = 0
		split("", one); split("", ben); split("", risk); next
	}
	/^## / { endsec(); next }
	id == "" { next }
	/^### / { sub_ = substr($0, 5); next }
	sub_ == "" && /^\| \*\*(Status|Type|Decides)\*\* \|/ {
		f = $0; sub(/^\| \*\*/, "", f); name = substr(f, 1, index(f, "**") - 1); v = substr(f, index(f, "**") + 2)
		sub(/^ *\| */, "", v); sub(/ *\| *$/, "", v)
		if (name == "Status") st = v; else if (name == "Type") type = v; else dec = v
		next
	}
	st == "" && /\*\*Status:\*\*/ { s = $0; sub(/.*\*\*Status:\*\* */, "", s); sub(/ *·.*/, "", s); st = s }
	sub_ == "The question" && NF { ctx = ctx " " $0; next }
	sub_ == "Recommendation" && NF { rec = rec " " $0; next }
	sub_ == "Options at a glance" && /^\|/ {
		n = cells($0)
		if (!hdr) {
			hdr = 1
			for (i = 1; i <= n; i++) if (match(c[i], /^[A-Z]: /)) {
				t = substr(c[i], 4); nk++; key[nk] = substr(c[i], 1, 1)
				orec[nk] = (t ~ /\(Recommended\)/); ochosen[nk] = (t ~ /\(Chosen\)/)
				gsub(/ *\((Recommended|Chosen)\)/, "", t); otitle[nk] = t; col[i] = key[nk]
			}
			next
		}
		r = c[1]; gsub(/\*/, "", r)
		for (i = 2; i <= n; i++) if (col[i] != "") {
			if (r == "In one line") one[col[i]] = c[i]
			else if (r == "Main benefit") ben[col[i]] = c[i]
			else if (r == "Main risk") risk[col[i]] = c[i]
		}
		next
	}
	sub_ == "Decision" && /^- \*\*Chosen:\*\*/ { chosen = substr($0, index($0, ":**") + 3) }
	sub_ == "Decision" && /^- \*\*Applied:\*\* *not yet/ { applied = 1 }
	sub_ == "Decision" && /^- \*\*Asked:\*\*/ { asked = 1 }
	END { endsec() }' "$1"
}

# dl_qs_model <file>: H, Q and O lines:
#   Q id title ref context take decision note applied
#   O id key title detail recommended needs-note
dl_qs_model() {
	awk -v OFS='\t' '
	function trim(s) { gsub(/^[ \t]+|[ \t]+$/, "", s); return s }
	function v(s) { s = trim(s); return (s == "—" || s == "-") ? "" : s }
	function endq() { if (id != "") print "Q", id, qt, ref, ctx, take, dec, note, app; id = "" }
	{ sub(/\r$/, ""); if (NR == 1) sub(/^\357\273\277/, ""); gsub(/\t/, " ") }
	/^# / && !h { h = 1; title = substr($0, 3); next }
	/^## Q[0-9]+ / {
		if (!hp) { print "H", title, feature, forwhat; hp = 1 }
		endq(); id = $2; p = index($0, " — "); qt = p ? substr($0, p + length(" — ")) : ""
		ref = ""; ctx = ""; take = ""; dec = ""; note = ""; app = ""; mode = ""; next
	}
	id == "" && /^- \*\*Feature:\*\*/ { feature = v(substr($0, index($0, ":**") + 3)); next }
	id == "" && /^- \*\*For:\*\*/ { forwhat = v(substr($0, index($0, ":**") + 3)); next }
	id == "" { next }
	/^- \*\*[A-Za-z]+:\*\*/ {
		f = substr($0, 5); name = substr(f, 1, index(f, ":**") - 1); val = substr(f, index(f, ":**") + 3); mode = ""
		if (name == "Ref") ref = v(val)
		else if (name == "Context") { mode = "ctx"; if (v(val) != "") ctx = v(val) }
		else if (name == "Take") take = v(val)
		else if (name == "Options") mode = "opt"
		else if (name == "Decision") { dec = v(val); sub(/ .*/, "", dec) }
		else if (name == "Note") note = v(val)
		else if (name == "Applied") app = v(val)
		next
	}
	mode == "opt" && /^  - \*\*[^*]+\*\* — / {
		s = substr($0, 7); k = substr(s, 1, index(s, "**") - 1); r = substr(s, index(s, "**") + 2); sub(/^ — /, "", r)
		rec = (r ~ /\*\(recommended\)\*/); nn = (r ~ /\*\(needs a note\)\*/)
		gsub(/ *\*\((recommended|needs a note)\)\*/, "", r)
		p = index(r, ": "); t = p ? substr(r, 1, p - 1) : r; d = p ? substr(r, p + 2) : ""
		print "O", id, k, trim(t), trim(d), rec, nn; next
	}
	mode == "ctx" && /^  / { l = substr($0, 3); ctx = (ctx == "" ? l : ctx "\001" l); next }
	END { if (!hp) print "H", title, feature, forwhat; endq() }' "$1"
}

# dl_ch_status <file> [stage]: total=, open=, apply=, done= for a Challenges document
dl_ch_status() {
	dl_ch_model "$1" | awk -F'\t' -v st="${2:-}" '
		st != "" && $2 != st { next }
		{ t++; if ($12 == "Open" || $12 == "") o++; else if ($12 == "Accepted" && $13 ~ /^To apply/) a++; else d++ }
		END { printf "total=%d\nopen=%d\napply=%d\ndone=%d\n", t, o, a, d }'
}

# dl_pr_status <file>: total=, open=, apply=, done= for a Tech Proposals document
dl_pr_status() {
	dl_pr_model "$1" | awk -F'\t' '$1 == "P" { t++; if ($11 == 1) a++; else if ($5 == "Open" || ($5 == "Default applied" && $12 == 1)) o++; else d++ }
		END { printf "total=%d\nopen=%d\napply=%d\ndone=%d\n", t, o, a, d }'
}

# dl_qs_status <file>: total=, open=, apply=, done=, title=, for= for a Questions list
dl_qs_status() {
	dl_qs_model "$1" | awk -F'\t' '$1 == "H" { t = $2; f = $4 } $1 == "Q" { n++; if ($7 == "") o++; else if ($9 == "") a++; else d++ }
		END { printf "total=%d\nopen=%d\napply=%d\ndone=%d\ntitle=%s\nfor=%s\n", n, o, a, d, t, f }'
}

# dl_waiting_all <folder>: fills the global DL_WAIT, prefix -> the sentence
# saying what waits for that prefix (" 2 challenges and 1 question wait for a
# decision." or "... to be applied."). A prefix with nothing waiting has no
# entry. Reads every Challenges, Tech Proposals and Questions document under
# the folder once, with bash only. Needs bash 4.2 or later.
dl_waiting_all() {
	declare -gA DL_WAIT=()
	local -A co=() ca=() seen=()
	local f b p what line key val kind m t s out v part
	local kinds=(challenge proposal question)
	for f in "$1"/*" - Challenges.md" "$1"/*" - Tech Proposals.md" "$1"/.tt/*" - Questions"/*.md; do
		[ -f "$f" ] || continue
		b=${f##*/}
		case $f in
		*" - Challenges.md") p=${b% - Challenges.md}; kind=challenge; out=$(dl_ch_status "$f" 2>/dev/null) ;;
		*" - Tech Proposals.md") p=${b% - Tech Proposals.md}; kind=proposal; out=$(dl_pr_status "$f" 2>/dev/null) ;;
		*) p=${f%/*}; p=${p##*/}; p=${p% - Questions}; kind=question; out=$(dl_qs_status "$f" 2>/dev/null) ;;
		esac
		seen[$p]=1
		while IFS= read -r line; do
			key=${line%%=*}; val=${line#*=}
			case $key in
			open) co[$p,$kind]=$(( ${co[$p,$kind]:-0} + ${val:-0} )) ;;
			apply) ca[$p,$kind]=$(( ${ca[$p,$kind]:-0} + ${val:-0} )) ;;
			esac
		done <<<"$out"
	done
	for p in "${!seen[@]}"; do
		for what in open apply; do
			m=0; t=0; s=
			for kind in "${kinds[@]}"; do
				if [ "$what" = open ]; then v=${co[$p,$kind]:-0}; else v=${ca[$p,$kind]:-0}; fi
				[ "$v" -gt 0 ] || continue
				m=$((m + 1)); t=$((t + v))
				part="$v $kind"; [ "$v" -eq 1 ] || part="${part}s"
				if [ "$m" -eq 1 ]; then s=$part
				else s="$s, $part"; fi
			done
			[ "$m" -gt 0 ] || continue
			# the last part is joined with " and " instead of ", "
			if [ "$m" -gt 1 ]; then s="${s%, $part} and $part"; fi
			s=" $s wait"; [ "$t" -eq 1 ] && s="${s}s"
			if [ "$what" = open ]; then DL_WAIT[$p]="$s for a decision."; else DL_WAIT[$p]="$s to be applied."; fi
			break
		done
	done
}
