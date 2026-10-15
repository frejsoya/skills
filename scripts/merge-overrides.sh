#!/usr/bin/env bash
#
# Merge upstream changes into local overrides of vendored skills.
#
# For every override in sources/overrides/overrides.lock that tracks VENDOR, three-way
# merge (git merge-file) the upstream file's changes from the recorded base to
# the vendored commit into the local SKILL.md, then advance the base. The base
# file itself is kept at sources/overrides/<skill>.md, so a rewritten upstream
# history (which drops the base commit) cannot break the merge. Conflicts
# are left as markers in the file and listed with resolution instructions;
# `make integrity` fails until they are gone.
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

upstream_file() { # COMMIT PATH -> stdout, fails if absent
  local path="$2"
  [ "$sub" = . ] || path="$sub/$path"
  git -C "$cache" show "$1:$path"
}

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
conflicts=()

while read -r dir v file base; do
  case "$dir" in ''|'#'*) continue;; esac
  [ "$v" = "$vendor" ] || continue
  local_file="$dir/SKILL.md"

  if [ "$base" = "$new" ]; then
    echo ">> override $dir: up to date"
    continue
  fi
  snapshot="sources/overrides/$(basename "$dir").md"
  if [ ! -f "$snapshot" ]; then
    echo "merge-overrides: missing base snapshot $snapshot for $dir" >&2; exit 2
  fi
  cp "$snapshot" "$tmp/base"
  if ! upstream_file "$new" "$file" > "$tmp/new"; then
    echo "merge-overrides: $file is gone upstream at $new (moved or deleted)." >&2
    echo "  Decide by hand: re-point $dir in $lock, or drop the override." >&2
    exit 2
  fi

  if cmp -s "$tmp/base" "$tmp/new"; then
    echo ">> override $dir: upstream unchanged"
  else
    rc=0
    git merge-file --diff3 -L "local $dir" -L "upstream ${base:0:7} (base)" -L "upstream ${new:0:7}" \
      "$local_file" "$tmp/base" "$tmp/new" || rc=$?
    if [ "$rc" -lt 0 ] || [ "$rc" -gt 127 ]; then
      echo "merge-overrides: git merge-file failed on $local_file" >&2; exit 2
    elif [ "$rc" -gt 0 ]; then
      conflicts+=("$local_file|$rc|$base")
      echo ">> override $dir: merged with $rc conflict(s)"
    else
      echo ">> override $dir: merged upstream ${base:0:7}..${new:0:7}"
    fi
  fi

  # Advance the base. On conflict the markers in the file record the work left.
  cp "$tmp/new" "$snapshot"
  awk -v d="$dir" -v n="$new" '$1 == d { sub(/[0-9a-f]{40}$/, n) } { print }' \
    "$lock" > "$tmp/lock" && cat "$tmp/lock" > "$lock"
done < "$lock"

[ "${#conflicts[@]}" -eq 0 ] && exit 0

cat >&2 <<EOF

CONFLICTS: upstream changes overlap local edits in ${#conflicts[@]} override(s).
EOF
for c in "${conflicts[@]}"; do
  IFS='|' read -r f n b <<<"$c"
  echo "  $f  ($n conflict(s); upstream diff: git -C $cache diff ${b:0:7} ${new:0:7} -- ${sub}/)" >&2
done
cat >&2 <<'EOF'

To resolve (human or agent), for each file above:
  1. Read the "override" comment under the front matter: its "Local changes"
     list is what the local version must keep.
  2. Each conflict block shows three versions: <<<<<<< local, ||||||| the
     upstream base, ======= ... >>>>>>> the new upstream. Take the new
     upstream text, then re-apply only those local changes to it. Everything
     else upstream changed is an improvement to keep.
  3. If upstream now does what a local change did, drop that line from the
     "Local changes" list too.
  4. Done when no conflict markers remain and `make integrity` passes.
EOF
exit 1
