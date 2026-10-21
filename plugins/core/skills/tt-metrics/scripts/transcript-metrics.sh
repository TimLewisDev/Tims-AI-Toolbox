#!/usr/bin/env bash
# transcript-metrics.sh: per-session response size, context size, slow
# responses, stalls, subagent use and token use, from Claude Code session
# transcripts, optionally recorded in a markdown log. Used to compare skill
# runs before and after a change. Needs bash and awk only.
set -eu

usage() {
	cat >&2 <<'EOF'
usage: transcript-metrics.sh [--since YYYY-MM-DD] [--slow SECONDS] <project dir | session.jsonl> ...
       transcript-metrics.sh --tokens [--since YYYY-MM-DD] [--session <id>] <project dir | session.jsonl> ...
       transcript-metrics.sh --detail <id> <project dir | session.jsonl> ...
       transcript-metrics.sh --record <log.md> [--label <text>] [--match <ERE>] [--all]
                             [--since YYYY-MM-DD] [--session <id>] <project dir | session.jsonl> ...

A project dir is ~/.claude/projects/<project>; its subagent transcripts
(<session>/subagents/*.jsonl) are included as kind "sub". A session id may be
given as a unique prefix.

Default mode, one row per transcript. Columns: session kind start minutes
skills responses max_out out_gt8k max_ctx slow stalls other_err agent_calls
  minutes      summed model time (request to last streamed chunk)
  max_out      largest output_tokens of one response (thinking included)
  out_gt8k     responses over 8k output tokens
  max_ctx      largest input + cache tokens of one request
  slow         responses longer than --slow seconds (default 240)
  stalls       "response stopped arriving" / "connection lost" errors

--tokens  One row per session, its subagents added in. Columns: session start
          skills mode model sub_models subs requests cache_write cache_read
          input output weighted max_ctx stalls
            mode       first word of the first skill's arguments when it is a
                       bare word ("continue"), else "-"
            weighted   cache_write*1.25 + cache_read*0.1 + input + output*5:
                       tokens priced relative to plain input, on one model.
                       Model price differences are not included; see model.
            max_ctx    largest context of one main-thread request
--detail  The same token columns for each thread (main and every subagent)
          of one session, with each subagent's model and description.
--record  Append one row per session to the markdown table in <log.md>
          (created if missing). By default only the most recent session; with
          --all, every session in range. A session already in the log has
          its row replaced (a resumed session grows), keeping its label
          unless --label is given, so re-running is safe. --match keeps only
          sessions whose skills list matches the ERE (e.g. '(^|,)tt-').
          Times are UTC.

Exit: 0 ok (for --record: at least one row added), 1 nothing to show or
record, 2 usage or environment error.
EOF
	exit 2
}

since=""; slow=240; mode=default; detail=""; session=""; log=""; label=""; match=""; all=0
while [ $# -gt 0 ]; do
	case "$1" in
		--since) since=${2:?}; shift 2 ;;
		--slow) slow=${2:?}; shift 2 ;;
		--tokens) mode=tokens; shift ;;
		--detail) mode=detail; detail=${2:?}; shift 2 ;;
		--record) mode=record; log=${2:?}; shift 2 ;;
		--label) label=${2?}; shift 2 ;;
		--match) match=${2:?}; shift 2 ;;
		--session) session=${2:?}; shift 2 ;;
		--all) all=1; shift ;;
		-h | --help) usage ;;
		-*) echo "transcript-metrics.sh: unknown option: $1" >&2; usage ;;
		*) break ;;
	esac
done
[ $# -gt 0 ] || usage

if [ "$mode" != default ]; then
	# Token use per thread, from a main transcript followed by its subagent
	# transcripts. A response is streamed as several lines with one message id:
	# each usage field is taken at its largest value for that id.
	TOK_AWK='
	function num(re, off) { return match($0, re) ? substr($0, RSTART + off, RLENGTH - off) + 0 : 0 }
	function str(re, off, tr) { return match($0, re) ? substr($0, RSTART + off, RLENGTH - off - tr) : "" }
	function addsk(s) {
		if (s ~ /^(clear|model|compact|resume|config|help|context|cost|exit|effort|memory|permissions|agents|mcp|hooks|ide|doctor|status|login|logout|fast|init|plan)$/ || (s in sk)) return 0
		sk[s] = 1; skills = skills (skills == "" ? "" : ",") s; return 1
	}
	function setmode(a,   w) {
		w = a; sub(/^[ \t]+/, "", w)
		if (match(w, /^[A-Za-z][A-Za-z-]*/) && (RLENGTH == length(w) || substr(w, RLENGTH + 1, 1) ~ /[ \t\\]/)) mode = substr(w, 1, RLENGTH)
		else mode = "-"
	}
	function wt(t) { return t["cw"] * 1.25 + t["cr"] * 0.1 + t["in"] + t["out"] * 5 }
	FNR == 1 { fi++; kind[fi] = (fi == 1 ? "main" : "sub"); f = FILENAME; sub(/.*[\/\\]/, "", f); sub(/\.jsonl$/, "", f); name[fi] = f }
	{ ts = str("\"timestamp\":\"[^\"]*\"", 13, 1) }
	ts == "" { next }
	fi == 1 && /"isSidechain":true/ { next }
	fi == 1 { if (first == "") first = ts; last = ts }
	fi == 1 && /"type":"user"/ && !/"tool_result"/ && match($0, /command-name>\/[A-Za-z0-9:_-]+<\/command-name>/) {
		s = substr($0, RSTART + 14, RLENGTH - 29)
		a = ""; if (match($0, /<command-args>[^<]*/)) a = substr($0, RSTART + 14, RLENGTH - 14)
		if (addsk(s) && mode == "") setmode(a)
	}
	fi == 1 && /"type":"assistant"/ {
		rest = $0
		while (match(rest, /"name":"Skill","input":\{"skill":"[^"]*"/)) {
			s = substr(rest, RSTART + 33, RLENGTH - 34); rest = substr(rest, RSTART + RLENGTH)
			a = ""; if (match(rest, /^,"args":"[^"]*/)) a = substr(rest, 10, RLENGTH - 9)
			if (addsk(s) && mode == "") setmode(a)
		}
	}
	/"type":"assistant"/ && /"role":"assistant"/ && !/"toolUseResult"/ {
		if (/"isApiErrorMessage":true/ || /"text":"API Error/) { if (/stopped arriving|[Cc]onnection lost/) stalls[fi]++; next }
		id = str("\"id\":\"msg_[^\"]*\"", 6, 1); if (id == "") next
		k = fi SUBSEP id
		if (!(k in seen)) { seen[k] = 1; req[fi]++; keys[++nk] = k; kf[nk] = fi }
		m = str("\"model\":\"[^\"]*\"", 9, 1); sub(/^claude-/, "", m)
		if (m != "" && m != "<synthetic>" && !((fi, m) in hasm)) { hasm[fi, m] = 1; models[fi] = models[fi] (models[fi] == "" ? "" : ",") m }
		v = num("\"input_tokens\":[0-9]+", 15); if (v > u_in[k]) u_in[k] = v
		v = num("\"cache_creation_input_tokens\":[0-9]+", 30); if (v > u_cw[k]) u_cw[k] = v
		v = num("\"cache_read_input_tokens\":[0-9]+", 26); if (v > u_cr[k]) u_cr[k] = v
		v = num("\"output_tokens\":[0-9]+", 16); if (v > u_out[k]) u_out[k] = v
	}
	END {
		if (fi == 0 || first == "") exit
		if (SINCE != "" && first < SINCE) exit
		for (i = 1; i <= nk; i++) {
			k = keys[i]; t = kf[i]
			cw[t] += u_cw[k]; cr[t] += u_cr[k]; inp[t] += u_in[k]; out[t] += u_out[k]
			c = u_in[k] + u_cw[k] + u_cr[k]; if (c > mc[t]) mc[t] = c
		}
		if (DETAIL) {
			for (t = 1; t <= fi; t++) {
				x["cw"] = cw[t]; x["cr"] = cr[t]; x["in"] = inp[t]; x["out"] = out[t]
				printf "%s\t%s\t%s\t%d\t%d\t%d\t%d\t%d\t%.0f\t%d\t%d\n", name[t], kind[t], (models[t] == "" ? "-" : models[t]), req[t], cw[t], cr[t], inp[t], out[t], wt(x), mc[t], stalls[t]
			}
			exit
		}
		for (t = 1; t <= fi; t++) {
			x["cw"] += cw[t]; x["cr"] += cr[t]; x["in"] += inp[t]; x["out"] += out[t]; r += req[t]; st += stalls[t]
			if (t > 1 && req[t] > 0) {
				subs++
				n2 = split(models[t], ms, ",")
				for (j = 1; j <= n2; j++) if (!(ms[j] in sm)) { sm[ms[j]] = 1; smodels = smodels (smodels == "" ? "" : ",") ms[j] }
			}
		}
		printf "%s\t%s\t%s\t%s\t%s\t%s\t%s\t%d\t%d\t%d\t%d\t%d\t%d\t%.0f\t%d\t%d\n", name[1], first, last, (skills == "" ? "-" : skills), (mode == "" ? "-" : mode), (models[1] == "" ? "-" : models[1]), (smodels == "" ? "-" : smodels), subs, r, x["cw"], x["cr"], x["in"], x["out"], wt(x), mc[1], st
	}'

	# Human-readable token counts: 1234 -> 1k, 1234567 -> 1.23M.
	FMT_AWK='function h(n) { return n >= 1000000 ? sprintf("%.2fM", n / 1000000) : n >= 1000 ? sprintf("%dk", int(n / 1000 + 0.5)) : sprintf("%d", n) }'

	mains=()
	for a in "$@"; do
		if [ -d "$a" ]; then
			for f in "$a"/*.jsonl; do [ -f "$f" ] && mains+=("$f"); done
		elif [ -f "$a" ]; then
			mains+=("$a")
		else
			echo "transcript-metrics.sh: no such file or folder: $a" >&2; exit 2
		fi
	done
	[ "$mode" = detail ] && session=$detail
	if [ -n "$session" ]; then
		picked=()
		for f in ${mains[@]+"${mains[@]}"}; do case "${f##*/}" in "$session"*) picked+=("$f") ;; esac; done
		[ ${#picked[@]} -gt 0 ] || { echo "transcript-metrics.sh: no session matches: $session" >&2; exit 1; }
		[ ${#picked[@]} -eq 1 ] || { echo "transcript-metrics.sh: session prefix is ambiguous: $session" >&2; exit 2; }
		mains=("${picked[@]}")
	fi
	[ ${#mains[@]} -gt 0 ] || { echo "transcript-metrics.sh: no transcripts found" >&2; exit 1; }

	threads() { # main transcript, then its subagent transcripts
		local m=$1 s
		printf '%s\n' "$m"
		for s in "${m%.jsonl}"/subagents/*.jsonl; do [ -f "$s" ] && printf '%s\n' "$s"; done
		return 0
	}

	if [ "$mode" = detail ]; then
		m=${mains[0]}; list=()
		while IFS= read -r t; do list+=("$t"); done < <(threads "$m")
		printf 'thread\tkind\tmodel\trequests\tcache_write\tcache_read\tinput\toutput\tweighted\tmax_ctx\tstalls\tdescription\n'
		awk -v DETAIL=1 -v SINCE="" "$TOK_AWK" "${list[@]}" | while IFS=$'\t' read -r name kind model rest; do
			desc="-"; meta="${m%.jsonl}/subagents/$name.meta.json"
			[ -f "$meta" ] && desc=$(sed -n 's/.*"description":"\([^"]*\)".*/\1/p' "$meta")
			printf '%s\t%s\t%s\t%s\t%s\n' "$name" "$kind" "$model" "$rest" "${desc:--}"
		done | awk -F'\t' -v OFS='\t' "$FMT_AWK"' { for (i = 5; i <= 10; i++) $i = h($i); print }'
		exit 0
	fi

	rows=$(for m in "${mains[@]}"; do
		list=()
		while IFS= read -r t; do list+=("$t"); done < <(threads "$m")
		awk -v DETAIL=0 -v SINCE="$since" "$TOK_AWK" "${list[@]}"
	done)
	[ -n "$rows" ] || { echo "transcript-metrics.sh: no sessions in range" >&2; exit 1; }

	if [ "$mode" = tokens ]; then
		printf 'session\tstart\tskills\tmode\tmodel\tsub_models\tsubs\trequests\tcache_write\tcache_read\tinput\toutput\tweighted\tmax_ctx\tstalls\n'
		printf '%s\n' "$rows" | sort -t$'\t' -k2,2 | awk -F'\t' -v OFS='\t' "$FMT_AWK"'
			{ print substr($1, 1, 8), substr($2, 1, 16), $4, $5, $6, $7, $8, $9, h($10), h($11), h($12), h($13), h($14), h($15), $16 }'
		exit 0
	fi

	# --record
	if [ -n "$match" ]; then
		rows=$(printf '%s\n' "$rows" | awk -F'\t' -v RE="$match" '$4 ~ RE')
		[ -n "$rows" ] || { echo "transcript-metrics.sh: no session matches --match $match" >&2; exit 1; }
	fi
	if [ "$all" = 1 ]; then
		rows=$(printf '%s\n' "$rows" | sort -t$'\t' -k2,2)
	else
		rows=$(printf '%s\n' "$rows" | sort -t$'\t' -k3,3 | tail -n 1)
	fi
	if [ ! -f "$log" ]; then
		mkdir -p "$(dirname "$log")"
		cat > "$log" <<'EOF'
# Token log

Written by `transcript-metrics.sh --record`, one row per Claude Code session,
its subagents included. Times are UTC. Weighted = cache write × 1.25 + cache
read × 0.1 + input + output × 5 (tokens priced relative to plain input, on one
model; compare rows on the same model). Max context is the main thread's.

| Start (UTC) | Session | Label | Skills | Mode | Model | Sub models | Subs | Requests | Cache write | Cache read | Input | Output | Weighted | Max context | Stalls |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
EOF
	fi
	added=0
	while IFS=$'\t' read -r sid start _ rest; do
		short=${sid:0:8}
		row=$(printf '%s\t%s\t%s\t%s\n' "$sid" "$start" "$label" "$rest" | awk -F'\t' "$FMT_AWK"'
			{ gsub(/\|/, "\\|", $3)
			  printf "| %s | %s | %s | %s | %s | %s | %s | %d | %d | %s | %s | %s | %s | %s | %s | %d |\n",
			    substr($2, 1, 16), substr($1, 1, 8), ($3 == "" ? "-" : $3), $4, $5, $6, $7, $8, $9,
			    h($10), h($11), h($12), h($13), h($14), h($15), $16 }')
		if grep -qF "| $short |" "$log"; then
			# A resumed session is recorded again: replace its row, keeping the
			# earlier label unless a new one is given.
			tmp=$(mktemp "$log.XXXXXX")
			awk -v S="$short" -v ROW="$row" -v NEWLABEL="$label" '
				{ n = split($0, c, " \\| ") }
				n > 3 && c[2] == S {
					if (NEWLABEL != "") { print ROW; next }
					m = split(ROW, r, " \\| "); r[3] = c[3]; out = r[1]
					for (i = 2; i <= m; i++) out = out " | " r[i]
					print out; next
				}
				{ print }' "$log" > "$tmp" && mv "$tmp" "$log"
			echo "updated: $short" >&2
		else
			printf '%s\n' "$row" >> "$log"
			echo "recorded: $short" >&2
		fi
		added=$((added + 1))
	done <<< "$rows"
	[ "$added" -gt 0 ] || exit 1
	exit 0
fi

files=()
for a in "$@"; do
	if [ -d "$a" ]; then
		for f in "$a"/*.jsonl "$a"/*/subagents/*.jsonl; do [ -f "$f" ] && files+=("$f"); done
	else
		files+=("$a")
	fi
done

printf 'session\tkind\tstart\tminutes\tskills\tresponses\tmax_out\tout_gt8k\tmax_ctx\tslow\tstalls\tother_err\tagent_calls\n'
for f in "${files[@]}"; do
	case "$f" in */subagents/*) kind=sub ;; *) kind=main ;; esac
	awk -v F="$f" -v KIND="$kind" -v SINCE="$since" -v SLOW="$slow" '
	function num(re, off) { return match($0, re) ? substr($0, RSTART + off, RLENGTH - off) + 0 : 0 }
	function str(re, off, tr) { return match($0, re) ? substr($0, RSTART + off, RLENGTH - off - tr) : "" }
	# Seconds since an epoch, from an ISO timestamp (days from civil date).
	function ep(t,   y, m, d) {
		y = substr(t, 1, 4) + 0; m = substr(t, 6, 2) + 0; d = substr(t, 9, 2) + 0
		if (m <= 2) { y--; m += 12 }
		return (365 * y + int(y / 4) - int(y / 100) + int(y / 400) + int((153 * (m - 3) + 2) / 5) + d) * 86400 \
			+ substr(t, 12, 2) * 3600 + substr(t, 15, 2) * 60 + substr(t, 18, 6)
	}
	function addsk(s) {
		if (s ~ /^(clear|model|compact|resume|config|help|context|cost|exit|effort|memory|permissions|agents|mcp|hooks|ide|doctor|status|login|logout|fast|init|plan)$/ || (s in sk)) return
		sk[s] = 1; skills = skills (skills == "" ? "" : ",") s
	}
	{ ts = str("\"timestamp\":\"[^\"]*\"", 13, 1) }
	ts == "" { next }
	KIND == "main" && /"isSidechain":true/ { next }
	{ if (first == "") first = ts; last = ts }
	match($0, /command-name>\/[A-Za-z0-9:_-]+/) { addsk(substr($0, RSTART + 14, RLENGTH - 14)) }
	match($0, /"name":"Skill","input":\{"skill":"[^"]*"/) { addsk(substr($0, RSTART + 33, RLENGTH - 34)) }
	/"type":"assistant"/ && /"role":"assistant"/ {
		if (/"isApiErrorMessage":true/ || /"text":"API Error/) { if (/stopped arriving|[Cc]onnection lost/) stalls++; else other++; next }
		id = str("\"id\":\"msg_[^\"]*\"", 6, 1); if (id == "") next
		if (!(id in st)) { st[id] = lastU; ids[++n] = id }
		en[id] = ts
		o = num("\"output_tokens\":[0-9]+", 16); if (o > out[id]) out[id] = o
		c = num("\"input_tokens\":[0-9]+", 15) + num("\"cache_read_input_tokens\":[0-9]+", 26) + num("\"cache_creation_input_tokens\":[0-9]+", 30)
		if (c > mc) mc = c
		rest = $0
		while (match(rest, /"type":"tool_use","id":"[^"]*","name":"Agent"/)) {
			t = substr(rest, RSTART, RLENGTH); if (!(t in seen)) { seen[t] = 1; ag++ }
			rest = substr(rest, RSTART + RLENGTH)
		}
		next
	}
	/"type":"user"/ { lastU = ts }
	END {
		if (n == 0 && stalls == 0 && other == 0) exit
		if (SINCE != "" && first < SINCE) exit
		for (i = 1; i <= n; i++) {
			id = ids[i]
			if (out[id] > mo) mo = out[id]
			if (out[id] > 8000) big++
			if (st[id] != "") { d = ep(en[id]) - ep(st[id]); if (d > 0) ms += d; if (d > SLOW) sl++ }
		}
		sub(/.*\//, "", F); sub(/\.jsonl$/, "", F)
		printf "%s\t%s\t%s\t%.1f\t%s\t%d\t%d\t%d\t%d\t%d\t%d\t%d\t%d\n", F, KIND, substr(first, 1, 16), ms / 60, (skills == "" ? "-" : skills), n, mo, big, mc, sl, stalls, other, ag
	}' "$f"
done
