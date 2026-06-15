#!/usr/bin/env bash
#
# Review suite for the skills in this repo. Three layers:
#   lint     — deterministic structural + hygiene checks (errors fail CI)
#   metrics  — quantitative report (size, code blocks, trigger coverage)
#   links    — broken intra-repo markdown links
# The qualitative LLM-judge layer lives in evals/ (see evals/README.md).
#
# Usage:
#   skills-eval.sh integrity    # repo invariants (plugin.json/README/eval/names)
#   skills-eval.sh lint         # frontmatter/description/hygiene (exit 1 on error)
#   skills-eval.sh links        # broken links, anchors, orphans, depth
#   skills-eval.sh metrics      # markdown report to stdout
#   skills-eval.sh check-ocaml  # parse ocaml code blocks (opt-in; needs toolchain)
#   skills-eval.sh vendor-check # vendored locks well-formed + no drift
#   skills-eval.sh all          # integrity + lint + links + vendor-check + metrics
#
# Lint/hygiene apply to the FORKED skills (skills/ — our diverged copy of
# mattpocock/skills that we edit). VENDORED skills (vendor/, verbatim from avsm)
# are measured in metrics but never fail lint — fixes go upstream. See sources/.
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CMD="${1:-help}"

fork()     { find "$ROOT/skills"  -iname 'skill.md' -not -path '*/deprecated/*' -exec dirname {} \; 2>/dev/null | sort; }
vendored() { [ -d "$ROOT/vendor" ] && find "$ROOT/vendor" -iname 'skill.md' -exec dirname {} \; 2>/dev/null | sort; }

skillmd() { ls "$1"/SKILL.md "$1"/skill.md 2>/dev/null | head -1; }

# Extract a frontmatter field, handling YAML block scalars (`>` / `|`) that
# continue across indented lines (e.g. caveman's folded description).
fm_field() {
  awk -v key="$2" '
    BEGIN { fm=0 }
    /^---[[:space:]]*$/ { fm++; if (fm==2) exit; next }
    fm==1 {
      if (cont) {
        if ($0 ~ /^[[:space:]]+/) { sub(/^[[:space:]]+/,""); buf=buf " " $0; next }
        else cont=0
      }
      if ($0 ~ "^" key ":") {
        v=$0; sub("^" key ":[[:space:]]*","",v)
        if (v==">" || v=="|" || v=="") { cont=1; buf="" } else buf=v
      }
    }
    END { gsub(/^[[:space:]]+/,"",buf); print buf }
  ' "$1"
}

red() { printf '\033[31m%s\033[0m' "$1"; }
yellow() { printf '\033[33m%s\033[0m' "$1"; }
green() { printf '\033[32m%s\033[0m' "$1"; }
dim() { printf '\033[2m%s\033[0m' "$1"; }

ERRORS=0; WARNS=0
err()  { ERRORS=$((ERRORS+1)); echo "  $(red "✗ error") $1"; }
warn() { WARNS=$((WARNS+1));   echo "  $(yellow "⚠ warn ") $1"; }

# lines inside ```ocaml / ```ml fenced blocks
ocaml_code() {
  awk '
    /^```/ { if (inb) { inb=0; next } if ($0 ~ /^```(ocaml|ml)([[:space:]]|$)/) inb=1; next }
    inb { print }' "$1"
}

# count fenced code blocks opened without a language tag
fences_no_lang() {
  awk '
    /^```/ { if (!inb) { inb=1; if ($0 ~ /^```[[:space:]]*$/) n++ } else inb=0 }
    END { print n+0 }' "$1"
}

# GitHub-style heading slugs of a file (headings outside code fences)
heading_slugs() {
  awk '/^```/{inb=!inb; next} !inb && /^#+[[:space:]]/' "$1" \
    | sed -E 's/^#+[[:space:]]+//' | tr 'A-Z' 'a-z' | sed -E 's/[^a-z0-9 -]//g; s/ +/-/g'
}

# Markdown link/file problems in a file (ignoring links inside ``` fences).
# Echoes one finding per line: "ERR <kind> <detail>" or "WARN <kind> <detail>".
file_link_problems() {
  local f="$1" dir; dir="$(dirname "$1")"
  awk '/^```/{inb=!inb; next} !inb' "$f" \
    | grep -oE '\]\(([^)]+)\)' 2>/dev/null | sed -E 's/^\]\(//; s/\)$//' | while IFS= read -r raw; do
    case "$raw" in http*|mailto:*) continue;; esac
    local tgt="${raw%%#*}" frag=""
    case "$raw" in *\#*) frag="${raw#*#}";; esac
    tgt="${tgt%% *}"
    if [ -z "$tgt" ]; then   # same-file anchor
      [ -n "$frag" ] && { heading_slugs "$f" | grep -qx "$frag" || echo "ERR anchor #$frag"; }
      continue
    fi
    case "$tgt" in *../../*) echo "WARN deep $tgt";; esac          # links should be one level deep
    local path; case "$tgt" in /*) path="$tgt";; *) path="$dir/$tgt";; esac
    if [ ! -e "$path" ]; then echo "ERR broken $tgt"; continue; fi
    [ -n "$frag" ] && { heading_slugs "$path" | grep -qx "$frag" || echo "ERR anchor $tgt#$frag"; }
    case "$tgt" in *.sh) [ -x "$path" ] || echo "WARN nonexec $tgt";; esac
  done
}

# Supporting docs in a skill dir that nothing else in the dir links to.
orphan_docs() {
  local d="$1"
  find "$d" -maxdepth 2 -name '*.md' ! -iname 'skill.md' ! -iname 'readme.md' 2>/dev/null | while IFS= read -r doc; do
    local bn; bn="$(basename "$doc")"
    grep -rlF "$bn" "$d" --include='*.md' 2>/dev/null | grep -qv "^$doc$" || echo "WARN orphan ${doc#"$ROOT"/}"
  done
}

# Tier 1 — repo-integrity invariants (what CLAUDE.md mandates but nothing checked)
integrity() {
  echo "$(green "integrity") — repo invariants"
  local e0=$ERRORS w0=$WARNS
  local plugin="$ROOT/.claude-plugin/plugin.json" readme="$ROOT/README.md"

  # 1. plugin.json entries resolve to a real skill dir
  echo "$(dim "• plugin.json ↔ filesystem")"
  grep -oE '"\./skills/[^"]+"' "$plugin" 2>/dev/null | tr -d '"' | while IFS= read -r rel; do
    [ -f "$ROOT/$rel/SKILL.md" ] || err "plugin.json entry '$rel' has no SKILL.md"
  done

  # 2. promoted skills (engineering/productivity) must be in plugin.json;
  #    personal/ must NOT be. (CLAUDE.md)
  echo "$(dim "• promotion rules (plugin.json + README)")"
  while IFS= read -r d; do [ -z "$d" ] && continue
    local base bucket; base="$(basename "$d")"; bucket="$(basename "$(dirname "$d")")"
    local in_plugin in_readme
    in_plugin=$(grep -qE "\"\./skills/$bucket/$base\"" "$plugin" && echo y || echo n)
    in_readme=$(grep -qE "\(\./skills/$bucket/$base/SKILL\.md\)" "$readme" && echo y || echo n)
    case "$bucket" in
      engineering|productivity)   # auto-loaded buckets: required in plugin.json
        [ "$in_plugin" = y ] || err "$base ($bucket): missing from plugin.json"
        [ "$in_readme" = y ] || warn "$base ($bucket): not linked in top-level README.md";;
      personal)                    # private: must NOT be promoted
        [ "$in_plugin" = n ] || err "$base (personal): must NOT be in plugin.json"
        [ "$in_readme" = n ] || warn "$base (personal): should not be promoted in README.md";;
    esac
  done < <(fork)

  # 3. each bucket has a README listing every skill in it (CLAUDE.md)
  echo "$(dim "• bucket READMEs")"
  while IFS= read -r d; do [ -z "$d" ] && continue
    local base bucketdir; base="$(basename "$d")"; bucketdir="$(dirname "$d")"
    local breadme="$bucketdir/README.md"
    if [ ! -f "$breadme" ]; then err "$(basename "$bucketdir")/: no bucket README.md"; continue; fi
    grep -qE "\(\./$base/SKILL\.md\)" "$breadme" || warn "$base: not listed in $(basename "$bucketdir")/README.md"
  done < <(fork)

  # 4. eval-set integrity: every expected skill in trigger-cases exists
  echo "$(dim "• eval-set references")"
  local tc="$ROOT/evals/trigger-cases.md"
  if [ -f "$tc" ]; then
    grep -E '^\| *[0-9]+ *\|' "$tc" | awk -F'|' '{print $4}' | while IFS= read -r exp; do
      exp="$(echo "$exp" | sed -E 's/^ *//; s/ *$//')"
      case "$exp" in —*|""|"—") continue;; esac
      local sk; sk="$(echo "$exp" | awk '{print $1}')"
      find "$ROOT/skills" "$ROOT/vendor" -iname 'skill.md' -path "*/$sk/*" 2>/dev/null | grep -q . \
        || err "trigger-cases: expected skill '$sk' not found on disk"
    done
  fi

  # 4b. routing-eval coverage (waza-style): how many skills have a positive case?
  echo "$(dim "• routing-eval coverage")"
  if [ -f "$tc" ]; then
    local covered total=0 cov=0 expset; expset="$(grep -E '^\| *[0-9]+ *\|' "$tc" | awk -F'|' '{print $4}' | awk '{print $1}' | sort -u)"
    while IFS= read -r d; do [ -z "$d" ] && continue
      total=$((total+1)); printf '%s\n' "$expset" | grep -qx "$(basename "$d")" && cov=$((cov+1))
    done < <(fork; vendored)
    echo "  $(dim "$cov/$total skills have a positive routing case")"
    [ "$cov" -lt "$total" ] && warn "routing-eval covers $cov/$total skills — add trigger-cases for the rest"
  fi

  # 5. name uniqueness across the install surface (collisions clobber symlinks)
  echo "$(dim "• name uniqueness (fork + vendored)")"
  { fork; vendored; } | xargs -n1 basename 2>/dev/null | sort | uniq -d | while IFS= read -r dup; do
    [ -n "$dup" ] && err "duplicate skill name '$dup' (would clobber on install)"
  done

  echo
  echo "integrity: $(red "$((ERRORS-e0)) error(s)"), $(yellow "$((WARNS-w0)) warning(s)")"
  [ "$((ERRORS-e0))" -gt 0 ] && return 1 || return 0
}

lint() {
  echo "$(green "lint") — structural + hygiene (forked skills in skills/)"
  local e0=$ERRORS w0=$WARNS
  while IFS= read -r d; do [ -z "$d" ] && continue
    local md name desc base; md="$(skillmd "$d")"; base="$(basename "$d")"
    echo "$(dim "• $base")"
    [ -z "$md" ] && { err "$base: no SKILL.md"; continue; }
    name="$(fm_field "$md" name)"; desc="$(fm_field "$md" description)"
    # frontmatter well-formedness (error): needs an opening + closing ---
    [ "$(grep -cE '^---[[:space:]]*$' "$md")" -ge 2 ] || err "$base: missing/!closed YAML frontmatter"
    # structure (errors)
    [ -z "$name" ] && err "$base: frontmatter missing 'name'"
    [ -z "$desc" ] && err "$base: frontmatter missing 'description'"
    [ -n "$name" ] && [ "$name" != "$base" ] && err "$base: name '$name' != directory"
    # unknown frontmatter keys (warn) — likely typos
    awk '/^---[[:space:]]*$/{fm++; next} fm==1 && /^[a-zA-Z][a-zA-Z0-9_-]*:/{sub(/:.*/,""); print}' "$md" \
      | while IFS= read -r k; do
          case "$k" in name|description|disable-model-invocation|argument-hint) ;; \
            *) warn "$base: unknown frontmatter key '$k'";; esac
        done
    # description quality (warns)
    if [ -n "$desc" ]; then
      local dmi; dmi="$(fm_field "$md" disable-model-invocation)"
      if [ "$dmi" != "true" ]; then
        echo "$desc" | grep -qiE 'use when|use this when|use for' || warn "$base: description has no 'Use when …' trigger"
      fi
      [ "${#desc}" -gt 1024 ] && warn "$base: description ${#desc} chars (> 1024)"
      case "$desc" in [A-Z]*) ;; *) warn "$base: description should start with a capital";; esac
      case "$desc" in *.) ;; *) warn "$base: description should end with a period";; esac
      echo "$desc" | grep -qE '^(I|I'\''ve|We|My) ' && warn "$base: description is first-person (use third person)"
    fi
    # progressive disclosure (warn)
    local lines; lines="$(wc -l < "$md")"
    [ "$lines" -gt 500 ] && warn "$base: SKILL.md $lines lines (> 500; split into reference files)"
    # code fences without a language (warn)
    local nf; nf="$(fences_no_lang "$md")"
    [ "$nf" -gt 0 ] && warn "$base: $nf code block(s) without a language tag"
    # non-OCaml residue, whole file (warn) — Lwt/TS tooling shouldn't appear at all
    grep -rnE '\bLwt\b|\bjest\b|\bvitest\b|\bpnpm\b|\.tsx|tsconfig' "$d" --include='*.md' 2>/dev/null \
      | sed "s#^$ROOT/##" | while IFS= read -r hit; do warn "$base: non-OCaml residue: $hit"; done
    # OCaml anti-patterns, code blocks only (warn) — avoid prose false-positives
    for omd in "$d"/*.md; do [ -f "$omd" ] || continue
      ocaml_code "$omd" | grep -nE 'Obj\.magic|Printf\.|open[[:space:]]+Lwt' \
        | while IFS= read -r hit; do warn "$base: OCaml anti-pattern in $(basename "$omd") code: $hit"; done
    done
  done < <(fork)
  # trigger-overlap heuristic (warn): descriptions sharing many significant words
  # route ambiguously. O(n^2) over a small set.
  echo "$(dim "• trigger overlap")"
  local tmp; tmp="$(mktemp)"
  while IFS= read -r d; do [ -z "$d" ] && continue
    local b m dsc w; b="$(basename "$d")"; m="$(skillmd "$d")"; dsc="$(fm_field "$m" description)"
    w="$(echo "$dsc" | tr 'A-Z' 'a-z' | grep -oE '[a-z]{5,}' \
        | grep -vE '^(skill|skills|using|which|where|their|other|these|those|while|about|should|would|could|when|user|wants|mentions)$' \
        | sort -u | tr '\n' ' ')"
    echo "$b|$w" >> "$tmp"
  done < <(fork)
  awk -F'|' '{names[NR]=$1; words[NR]=$2} END{
    for(i=1;i<=NR;i++)for(j=i+1;j<=NR;j++){
      n=split(words[i],a," "); shared=0
      for(k=1;k<=n;k++){if(a[k]=="")continue; if(index(" "words[j]" "," "a[k]" ")) shared++}
      if(shared>=5) printf "OVERLAP %s ~ %s (%d shared)\n", names[i], names[j], shared
    }}' "$tmp" | while IFS= read -r line; do warn "${line#OVERLAP }"; done
  rm -f "$tmp"
  echo
  echo "lint: $(red "$((ERRORS-e0)) error(s)"), $(yellow "$((WARNS-w0)) warning(s)")"
  [ "$((ERRORS-e0))" -gt 0 ] && return 1 || return 0
}

links() {
  echo "$(green "links") — markdown link & file hygiene"
  local errs=0
  # per-file link/anchor/depth/exec checks (our docs, not vendored)
  while IFS= read -r f; do
    while IFS= read -r line; do [ -z "$line" ] && continue
      local kind detail; kind="$(echo "$line" | awk '{print $1,$2}')"; detail="${line#* * }"
      case "$line" in
        ERR\ broken*) echo "  $(red "✗ broken") ${f#"$ROOT"/} -> $detail"; errs=$((errs+1));;
        ERR\ anchor*) echo "  $(red "✗ anchor") ${f#"$ROOT"/} -> $detail"; errs=$((errs+1));;
        WARN\ deep*)  warn "${f#"$ROOT"/}: link not one level deep -> $detail";;
        WARN\ nonexec*) warn "${f#"$ROOT"/}: referenced script not executable -> $detail";;
      esac
    done < <(file_link_problems "$f")
  done < <(find "$ROOT/skills" "$ROOT/evals" "$ROOT/sources" -name '*.md' -not -path '*/deprecated/*' 2>/dev/null; ls "$ROOT"/*.md 2>/dev/null)
  # orphan supporting docs (fork skills only)
  while IFS= read -r d; do [ -z "$d" ] && continue
    while IFS= read -r line; do [ -z "$line" ] && continue
      warn "orphan supporting doc: ${line#WARN orphan }"
    done < <(orphan_docs "$d")
  done < <(fork)
  echo "links: $(red "$errs error(s)"), see warnings above"
  [ "$errs" -gt 0 ] && return 1 || return 0
}

metrics() {
  echo "# Skills metrics"
  echo
  echo "| skill | src | SKILL lines | files | ~tokens | code blks | desc len | trigger |"
  echo "|---|---|--:|--:|--:|--:|--:|:--:|"
  local total=0 fork_n=0 vend_n=0 no_trig=0 big=0 tok_total=0 heavy=0
  emit() {
    local d="$1" src="$2" md name desc lines files chars tok blks dlen trig
    md="$(skillmd "$d")"; [ -z "$md" ] && return
    name="$(basename "$d")"; desc="$(fm_field "$md" description)"
    lines="$(wc -l < "$md" | tr -d ' ')"
    files="$(find "$d" -type f | wc -l | tr -d ' ')"
    # rough token budget across all .md in the skill (~4 chars/token)
    chars="$(cat "$d"/*.md 2>/dev/null | wc -c | tr -d ' ')"; tok=$((chars/4))
    blks="$(grep -cE '^```[a-zA-Z]' "$md")"
    dlen="${#desc}"
    if echo "$desc" | grep -qiE 'use when|use this when|use for'; then trig="✓"; else trig="✗"; no_trig=$((no_trig+1)); fi
    [ "$lines" -gt 500 ] && big=$((big+1))
    tok_total=$((tok_total+tok)); [ "$tok" -gt 5000 ] && heavy=$((heavy+1))
    printf '| %s | %s | %s | %s | %s | %s | %s | %s |\n' "$name" "$src" "$lines" "$files" "$tok" "$blks" "$dlen" "$trig"
    total=$((total+1))
  }
  while IFS= read -r d; do [ -z "$d" ] && continue; emit "$d" fork; fork_n=$((fork_n+1)); done < <(fork)
  while IFS= read -r d; do [ -z "$d" ] && continue; emit "$d" vend; vend_n=$((vend_n+1)); done < <(vendored)
  echo
  echo "**Totals**: $total skills ($fork_n forked from mattpocock, $vend_n vendored from avsm) · ~$tok_total tokens total · $no_trig missing a trigger phrase · $big over 500 lines · $heavy over ~5k tokens."
}

# Tier 4 #14 — syntax-check ocaml code blocks (opt-in; needs a toolchain).
# Illustrative *fragments* (containing `...`, `<placeholders>`, "pseudo-code")
# are skipped — only self-contained blocks are parsed. To *execute* runnable
# blocks (compile + verify output), use MDX (see evals/README.md).
CHK_OK=0; CHK_FAIL=0; CHK_SKIP=0
check_ocaml() {
  echo "$(green "check-ocaml") — syntax of ocaml code blocks (fragments skipped)"
  local tool flag_impl flag_intf
  if command -v ocamlformat >/dev/null 2>&1; then tool=ocamlformat
  elif command -v ocamlc >/dev/null 2>&1; then tool=ocamlc
  else echo "  $(yellow "skipped") — no ocamlformat/ocamlc on PATH (install OCaml to enable)"; return 0; fi
  command -v mdx >/dev/null 2>&1 && echo "  $(dim "mdx present — see evals/README.md to verify runnable blocks")"
  local tmp; tmp="$(mktemp -d)"
  parse_block() { # $1 content  $2 src-label  $3 block-no
    case "$1" in *...*|*"pseudo"*) CHK_SKIP=$((CHK_SKIP+1)); return;; esac
    printf '%s' "$1" | grep -qE '<[a-zA-Z_]+>' && { CHK_SKIP=$((CHK_SKIP+1)); return; }
    local ext f; if printf '%s' "$1" | grep -qE '^[[:space:]]*val ' && ! printf '%s' "$1" | grep -qE '^[[:space:]]*let '; then ext=mli; else ext=ml; fi
    f="$tmp/blk.$ext"; printf '%s\n' "$1" > "$f"
    if [ "$tool" = ocamlformat ]; then
      ocamlformat --enable-outside-detected-project "$f" >/dev/null 2>"$tmp/e"
    else ocamlc -stop-after parsing "$f" >/dev/null 2>"$tmp/e"; fi
    if [ $? -eq 0 ]; then CHK_OK=$((CHK_OK+1)); else CHK_FAIL=$((CHK_FAIL+1)); warn "$2 block $3: parse error — $(head -1 "$tmp/e")"; fi
  }
  while IFS= read -r d; do [ -z "$d" ] && continue
    for omd in "$d"/*.md; do [ -f "$omd" ] || continue
      local inb=0 n=0 cur="" src; src="$(basename "$d")/$(basename "$omd")"
      while IFS= read -r ln; do
        if [ $inb -eq 1 ]; then
          case "$ln" in '```'*) parse_block "$cur" "$src" "$n"; inb=0; cur="";; *) cur+="$ln"$'\n';; esac
        else
          case "$ln" in '```ocaml'|'```ocaml '*|'```ml'|'```ml '*) inb=1; n=$((n+1)); cur="";; esac
        fi
      done < "$omd"
    done
  done < <(fork)
  rm -rf "$tmp"
  echo "check-ocaml: $(green "$CHK_OK ok"), $(red "$CHK_FAIL parse error(s)"), $CHK_SKIP fragment(s) skipped"
  [ "$CHK_FAIL" -gt 0 ] && return 1 || return 0
}

# Tier 5 — vendoring integrity: locks well-formed + vendored tree not hand-edited
vendor_check() {
  echo "$(green "vendor-check") — lock well-formedness + drift"
  local e0=$ERRORS w0=$WARNS
  # 1. locks have required fields
  echo "$(dim "• lock files")"
  local fl="$ROOT/sources/mattpocock-skills.lock" vl="$ROOT/sources/ocaml-claude-marketplace.lock"
  [ -f "$fl" ] || err "missing sources/mattpocock-skills.lock"
  [ -f "$vl" ] || err "missing sources/ocaml-claude-marketplace.lock"
  [ -f "$fl" ] && for f in upstream policy fork-point; do grep -q "^$f:" "$fl" || err "mattpocock lock missing '$f:'"; done
  [ -f "$vl" ] && for f in upstream subdir commit; do grep -q "^$f:" "$vl" || err "avsm lock missing '$f:'"; done
  # 2. drift: does vendor/ still match the pinned commit? (needs the cache)
  echo "$(dim "• drift (vendored tree vs pinned commit)")"
  local cache="$ROOT/.vendor-cache/ocaml-claude-marketplace"
  local sub sha vdir; sub="$(awk '/^subdir:/{print $2}' "$vl" 2>/dev/null)"
  sha="$(awk '/^commit:/{print $2}' "$vl" 2>/dev/null)"
  vdir="$ROOT/vendor/ocaml-claude-marketplace/ocaml-dev"
  if [ -d "$cache/.git" ] && [ -n "$sha" ]; then
    git -C "$cache" checkout -q --detach "$sha" 2>/dev/null || true
    if diff -rq --exclude='.git' "$cache/$sub" "$vdir" >/tmp/vdrift 2>&1; then
      echo "  $(green "✓") vendored tree matches pinned $sha"
    else
      sed 's/^/  /' /tmp/vdrift | head -20 | while IFS= read -r l; do warn "drift: ${l#  }"; done
      warn "vendored tree differs from pin — was it hand-edited? re-sync with 'make vendor-update'"
    fi; rm -f /tmp/vdrift
  else
    echo "  $(dim "no local cache — run 'make vendor-update' once to enable drift detection")"
  fi
  echo
  echo "vendor-check: $(red "$((ERRORS-e0)) error(s)"), $(yellow "$((WARNS-w0)) warning(s)")"
  [ "$((ERRORS-e0))" -gt 0 ] && return 1 || return 0
}

case "$CMD" in
  integrity)   integrity;;
  lint)        lint;;
  links)       links;;
  metrics)     metrics;;
  check-ocaml) check_ocaml;;
  vendor-check) vendor_check;;
  all)         integrity; r0=$?; echo; lint; r1=$?; echo; links; r2=$?; echo; vendor_check; r3=$?; echo; metrics; [ $((r0+r1+r2+r3)) -eq 0 ];;
  *)           sed -n '2,19p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//';;
esac
