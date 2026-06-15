#!/usr/bin/env bash
#
# Review suite for the skills in this repo. Three layers:
#   lint     — deterministic structural + hygiene checks (errors fail CI)
#   metrics  — quantitative report (size, code blocks, trigger coverage)
#   links    — broken intra-repo markdown links
# The qualitative LLM-judge layer lives in evals/ (see evals/README.md).
#
# Usage:
#   skills-eval.sh integrity # repo invariants (plugin.json/README/eval/names)
#   skills-eval.sh lint      # exit 1 on any error
#   skills-eval.sh metrics   # markdown report to stdout
#   skills-eval.sh links     # exit 1 on broken links
#   skills-eval.sh all       # integrity + lint + links + metrics
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

# count fenced code blocks opened without a language tag
fences_no_lang() {
  awk '
    /^```/ { if (!inb) { inb=1; if ($0 ~ /^```[[:space:]]*$/) n++ } else inb=0 }
    END { print n+0 }' "$1"
}

# broken relative markdown links in a file (ignoring links inside ``` fences)
broken_links() {
  local f="$1" dir; dir="$(dirname "$1")"
  awk '/^```/{inb=!inb; next} !inb' "$f" \
    | grep -oE '\]\(([^)]+)\)' 2>/dev/null | sed -E 's/^\]\(//; s/\)$//' | while IFS= read -r tgt; do
    case "$tgt" in
      http*|\#*|mailto:*) continue;;
    esac
    tgt="${tgt%%#*}"; tgt="${tgt%% *}"; [ -z "$tgt" ] && continue
    case "$tgt" in /*) path="$tgt";; *) path="$dir/$tgt";; esac
    [ -e "$path" ] || echo "$tgt"
  done
}

# Tier 1 — repo-integrity invariants (what CLAUDE.md mandates but nothing checked)
integrity() {
  echo "$(green "integrity") — repo invariants"
  local plugin="$ROOT/.claude-plugin/plugin.json" readme="$ROOT/README.md"

  # 1. plugin.json entries resolve to a real skill dir
  echo "$(dim "• plugin.json ↔ filesystem")"
  grep -oE '"\./skills/[^"]+"' "$plugin" 2>/dev/null | tr -d '"' | while IFS= read -r rel; do
    [ -f "$ROOT/$rel/SKILL.md" ] || err "plugin.json entry '$rel' has no SKILL.md"
  done

  # 2. promoted skills (engineering/productivity/misc) must be in plugin.json;
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
      misc)                        # "rarely used": README expected, plugin optional
        [ "$in_readme" = y ] || warn "$base (misc): not linked in top-level README.md"
        [ "$in_plugin" = y ] || warn "$base (misc): not in plugin.json (misc is opt-in)";;
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

  # 5. name uniqueness across the install surface (collisions clobber symlinks)
  echo "$(dim "• name uniqueness (fork + vendored)")"
  { fork; vendored; } | xargs -n1 basename 2>/dev/null | sort | uniq -d | while IFS= read -r dup; do
    [ -n "$dup" ] && err "duplicate skill name '$dup' (would clobber on install)"
  done

  echo
  echo "integrity: $(red "$ERRORS error(s)"), $(yellow "$WARNS warning(s)")"
  [ "$ERRORS" -gt 0 ] && return 1 || return 0
}

lint() {
  echo "$(green "lint") — structural + hygiene (forked skills in skills/)"
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
    # OCaml hygiene (warn) — forked skills should not carry Lwt or TS residue
    grep -rnE '\bLwt\b|\bjest\b|\bvitest\b|\bpnpm\b|\.tsx|tsconfig' "$d" --include='*.md' 2>/dev/null \
      | sed "s#^$ROOT/##" | while IFS= read -r hit; do warn "$base: non-OCaml residue: $hit"; done
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
  echo "lint: $(red "$ERRORS error(s)"), $(yellow "$WARNS warning(s)")"
  [ "$ERRORS" -gt 0 ] && return 1 || return 0
}

links() {
  echo "$(green "links") — broken intra-repo markdown links"
  local bad=0
  while IFS= read -r f; do
    while IFS= read -r missing; do [ -z "$missing" ] && continue
      echo "  $(red "✗") ${f#"$ROOT"/} -> $missing"; bad=$((bad+1))
    done < <(broken_links "$f")
  done < <(find "$ROOT/skills" -name '*.md' -not -path '*/deprecated/*' 2>/dev/null)
  echo "links: $bad broken"
  [ "$bad" -gt 0 ] && return 1 || return 0
}

metrics() {
  echo "# Skills metrics"
  echo
  echo "| skill | src | SKILL lines | files | bytes | code blks | desc len | trigger |"
  echo "|---|---|--:|--:|--:|--:|--:|:--:|"
  local total=0 fork_n=0 vend_n=0 no_trig=0 big=0
  emit() {
    local d="$1" src="$2" md name desc lines files bytes blks dlen trig
    md="$(skillmd "$d")"; [ -z "$md" ] && return
    name="$(basename "$d")"; desc="$(fm_field "$md" description)"
    lines="$(wc -l < "$md" | tr -d ' ')"
    files="$(find "$d" -type f | wc -l | tr -d ' ')"
    bytes="$(du -sk "$d" | cut -f1)"
    blks="$(grep -cE '^```[a-zA-Z]' "$md")"
    dlen="${#desc}"
    if echo "$desc" | grep -qiE 'use when|use this when|use for'; then trig="✓"; else trig="✗"; no_trig=$((no_trig+1)); fi
    [ "$lines" -gt 500 ] && big=$((big+1))
    printf '| %s | %s | %s | %s | %sK | %s | %s | %s |\n' "$name" "$src" "$lines" "$files" "$bytes" "$blks" "$dlen" "$trig"
    total=$((total+1))
  }
  while IFS= read -r d; do [ -z "$d" ] && continue; emit "$d" fork; fork_n=$((fork_n+1)); done < <(fork)
  while IFS= read -r d; do [ -z "$d" ] && continue; emit "$d" vend; vend_n=$((vend_n+1)); done < <(vendored)
  echo
  echo "**Totals**: $total skills ($fork_n forked from mattpocock, $vend_n vendored from avsm) · $no_trig missing a trigger phrase · $big over 500 lines."
}

case "$CMD" in
  integrity) integrity;;
  lint)    lint;;
  links)   links;;
  metrics) metrics;;
  all)     integrity; r0=$?; echo; lint; r1=$?; echo; links; r2=$?; echo; metrics; [ $((r0+r1+r2)) -eq 0 ];;
  *)       sed -n '2,19p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//';;
esac
