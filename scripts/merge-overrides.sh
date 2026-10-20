#!/usr/bin/env bash
#
# Merge upstream changes into local overrides of vendored skills.
#
# For every override in sources/overrides/overrides.lock that tracks VENDOR,
# walk the upstream skill directory at the newly vendored commit and three-way
# merge (git merge-file) each file's changes since the recorded base into the
# local copy, then advance the base. The base is kept as a snapshot of the
# upstream directory under sources/overrides/<skill>/, so a rewritten upstream
# history (which drops the base commit) cannot break the merge.
#
# Per file: unchanged upstream -> untouched. Changed upstream -> merged into
# the local copy. New upstream -> copied in (merged against an empty base if
# the override already has a file of that name). Removed upstream -> removed
# locally only if the local copy still equals the base, reported otherwise.
# Files only the override has are left alone. Conflicts are left as markers
# and listed with resolution instructions; `make integrity` fails until they
# are gone.
#
# Usage: merge-overrides.sh VENDOR SUBDIR
#   VENDOR  vendor name (sources/VENDOR.lock, .vendor-cache/VENDOR)
#   SUBDIR  upstream subdir the vendor mirrors (UPSTREAM_SUB_<vendor>)
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

vendor="$1"
sub="${2%/}"
lock=sources/overrides/overrides.lock
cache=".vendor-cache/$vendor"
new="$(awk '/^commit:/{print $2}' "sources/$vendor.lock")"
[ -n "$new" ] || { echo "merge-overrides: no commit in sources/$vendor.lock" >&2; exit 2; }

upstream_path() { [ "$sub" = . ] && echo "$1" || echo "$sub/$1"; }
upstream_file() { git -C "$cache" show "$1:$(upstream_path "$2")"; }      # COMMIT PATH -> stdout
upstream_files() {                                                        # COMMIT DIR -> relative paths
  local p; p="$(upstream_path "$2")"
  git -C "$cache" ls-tree -r --name-only "$1" -- "$p" | sed "s|^$p/||"
}

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
: > "$tmp/empty"
conflicts=()
notes=()

while read -r dir v updir base; do
  case "$dir" in ''|'#'*) continue;; esac
  [ "$v" = "$vendor" ] || continue
  snap="sources/overrides/$(basename "$dir")"

  if [ "$base" = "$new" ]; then
    echo ">> override $dir: up to date"
    continue
  fi
  if [ ! -d "$snap" ]; then
    echo "merge-overrides: missing base snapshot $snap/ for $dir" >&2; exit 2
  fi
  if ! upstream_files "$new" "$updir" | grep -q .; then
    echo "merge-overrides: $updir is gone upstream at $new (moved or deleted)." >&2
    echo "  Decide by hand: re-point $dir in $lock, or drop the override." >&2
    exit 2
  fi

  merged=0 added=0 same=0 nconf=0
  while IFS= read -r rel; do [ -z "$rel" ] && continue
    upstream_file "$new" "$updir/$rel" > "$tmp/new"
    local_file="$dir/$rel"; base_file="$snap/$rel"
    if [ -f "$base_file" ]; then
      if cmp -s "$base_file" "$tmp/new"; then same=$((same+1)); continue; fi
      if [ ! -f "$local_file" ]; then
        notes+=("$local_file: removed locally but changed upstream ${base:0:7}..${new:0:7}; re-add or keep dropping it")
        continue
      fi
    else
      if [ ! -f "$local_file" ]; then
        mkdir -p "$(dirname "$local_file")"; cp "$tmp/new" "$local_file"; added=$((added+1)); continue
      fi
      base_file="$tmp/empty"   # both sides added a file of this name
    fi
    rc=0
    git merge-file --diff3 -L "local $local_file" -L "upstream ${base:0:7} (base)" -L "upstream ${new:0:7}" \
      "$local_file" "$base_file" "$tmp/new" || rc=$?
    if [ "$rc" -lt 0 ] || [ "$rc" -gt 127 ]; then
      echo "merge-overrides: git merge-file failed on $local_file" >&2; exit 2
    elif [ "$rc" -gt 0 ]; then
      conflicts+=("$local_file|$rc|$base"); nconf=$((nconf+rc))
    fi
    merged=$((merged+1))
  done < <(upstream_files "$new" "$updir")

  # files upstream removed since the base
  while IFS= read -r rel; do [ -z "$rel" ] && continue
    upstream_files "$new" "$updir" | grep -qx "$rel" && continue
    local_file="$dir/$rel"
    [ -f "$local_file" ] || continue
    if cmp -s "$local_file" "$snap/$rel"; then
      rm -f "$local_file"; notes+=("$local_file: removed (upstream removed it; local copy was unmodified)")
    else
      notes+=("$local_file: upstream removed it but the local copy has edits; keep or delete by hand")
    fi
  done < <(cd "$snap" && find . -type f | sed 's|^\./||')

  if [ "$nconf" -gt 0 ]; then
    echo ">> override $dir: merged upstream ${base:0:7}..${new:0:7} ($merged file(s), $added added) with $nconf conflict(s)"
  elif [ "$((merged+added))" -gt 0 ]; then
    echo ">> override $dir: merged upstream ${base:0:7}..${new:0:7} ($merged file(s), $added added)"
  else
    echo ">> override $dir: upstream unchanged"
  fi

  # Advance the base: refresh the snapshot and the lock. On conflict the
  # markers in the file record the work left.
  rm -rf "$snap"; mkdir -p "$snap"
  while IFS= read -r rel; do [ -z "$rel" ] && continue
    mkdir -p "$snap/$(dirname "$rel")"; upstream_file "$new" "$updir/$rel" > "$snap/$rel"
  done < <(upstream_files "$new" "$updir")
  awk -v d="$dir" -v n="$new" '$1 == d { sub(/[0-9a-f]{40}$/, n) } { print }' \
    "$lock" > "$tmp/lock" && cat "$tmp/lock" > "$lock"
done < "$lock"

for n in "${notes[@]+"${notes[@]}"}"; do echo "   note: $n"; done
[ "${#conflicts[@]}" -eq 0 ] && exit 0

cat >&2 <<EOT

CONFLICTS: upstream changes overlap local edits in ${#conflicts[@]} file(s).
EOT
for c in "${conflicts[@]}"; do
  IFS='|' read -r f n b <<<"$c"
  echo "  $f  ($n conflict(s); upstream diff: git -C $cache diff ${b:0:7} ${new:0:7} -- ${sub}/)" >&2
done
cat >&2 <<'EOT'

To resolve (human or agent), for each file above:
  1. Read the "override" comment under the SKILL.md front matter: its "Local
     changes" list is what the local version must keep.
  2. Each conflict block shows three versions: <<<<<<< local, ||||||| the
     upstream base, ======= ... >>>>>>> the new upstream. Take the new
     upstream text, then re-apply only those local changes to it. Everything
     else upstream changed is an improvement to keep.
  3. If upstream now does what a local change did, drop that line from the
     "Local changes" list too.
  4. Done when no conflict markers remain and `make integrity` passes.
EOT
exit 1
