#!/usr/bin/env bash
# Vendor upstream skill sets verbatim, one source per lock file.
#
# Usage:
#   vendor.sh list                  names of the vendored sources
#   vendor.sh status [NAME]         print the lock(s)
#   vendor.sh update [NAME] [REF]   re-sync to REF (default origin/main), rewrite the lock
#   vendor.sh diff   [NAME]         what upstream changed since the pin
#   vendor.sh check                 locks well-formed + vendored trees match their pins
#
# NAME omitted = every vendored source. A source is any sources/<NAME>.lock with
# a `subdir:` field; the lock is both its config and its pin:
#
#   upstream: <git url>
#   subdir:   <path inside upstream, or .>
#   location: <dir in this repo the subdir is mirrored into>
#   include:  <optional, space-separated top-level names/globs to copy (default all)>
#   exclude:  <optional, space-separated top-level names/globs to skip>
#   commit / date / subject   <written by update>
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SOURCES="$ROOT/sources"
CACHE_ROOT="$ROOT/.vendor-cache"

field() { awk -v k="$1:" '$1 == k { $1 = ""; sub(/^ +/, ""); print; exit }' "$2"; }

lock_of() {
  local lock="$SOURCES/$1.lock"
  [ -f "$lock" ] && grep -q '^subdir:' "$lock" || { echo "unknown vendored source: $1" >&2; exit 1; }
  echo "$lock"
}

names() {
  for lock in "$SOURCES"/*.lock; do
    grep -q '^subdir:' "$lock" && basename "$lock" .lock
  done
}

targets() { if [ -n "${1:-}" ]; then echo "$1"; else names; fi; }

fetch() { # NAME -> cache dir with an up-to-date clone
  local name="$1" url cache
  url="$(field upstream "$(lock_of "$name")")"
  cache="$CACHE_ROOT/$name"
  if [ -d "$cache/.git" ]; then
    git -C "$cache" fetch --quiet --tags origin
  else
    mkdir -p "$CACHE_ROOT"
    git clone --quiet "$url" "$cache"
  fi
  echo "$cache"
}

# rsync upstream subdir -> DEST, applying the lock's include/exclude filters.
mirror() { # NAME CACHE DEST
  local lock sub p; lock="$(lock_of "$1")"
  sub="$(field subdir "$lock")"
  # `read -a` splits the patterns without glob-expanding them against cwd.
  local -a inc exc filters=(--exclude=.git)
  read -ra exc <<<"$(field exclude "$lock")"
  read -ra inc <<<"$(field include "$lock")"
  for p in "${exc[@]}"; do filters+=("--exclude=/$p"); done
  if [ "${#inc[@]}" -gt 0 ]; then
    for p in "${inc[@]}"; do filters+=("--include=/$p" "--include=/$p/***"); done
    filters+=("--exclude=*")
  fi
  mkdir -p "$3"
  rsync -a --delete --delete-excluded "${filters[@]}" "$2/$sub/" "$3/"
}

write_lock() { # NAME CACHE
  local name="$1" cache="$2" lock tmp k v
  lock="$(lock_of "$name")"; tmp="$(mktemp)"
  for k in upstream subdir location include exclude; do
    v="$(field "$k" "$lock")"
    [ -n "$v" ] && printf '%-9s %s\n' "$k:" "$v" >>"$tmp"
  done
  {
    printf '%-9s %s\n' policy: "vendored verbatim (pinned; never hand-edited)"
    printf '%-9s %s\n' update: "make vendor-update SOURCE=$name"
    printf '%-9s %s\n' commit: "$(git -C "$cache" rev-parse HEAD)"
    printf '%-9s %s\n' date: "$(git -C "$cache" log -1 --format=%ci HEAD)"
    printf '%-9s %s\n' subject: "$(git -C "$cache" log -1 --format=%s HEAD)"
  } >>"$tmp"
  mv "$tmp" "$lock"
}

cmd_update() { # [NAME] [REF]
  local name cache
  if [ -n "${2:-}" ] && [ -z "${1:-}" ]; then echo "REF needs a NAME: a commit belongs to one upstream" >&2; exit 1; fi
  for name in $(targets "${1:-}"); do
    cache="$(fetch "$name")"
    git -C "$cache" checkout --quiet --detach "${2:-origin/main}"
    mirror "$name" "$cache" "$ROOT/$(field location "$(lock_of "$name")")"
    write_lock "$name" "$cache"
    echo ">> vendored $name @ $(git -C "$cache" rev-parse --short HEAD)"
  done
}

cmd_diff() { # [NAME]
  local name cache lock sha latest
  for name in $(targets "${1:-}"); do
    lock="$(lock_of "$name")"; cache="$(fetch "$name")"
    sha="$(field commit "$lock")"; latest="$(git -C "$cache" rev-parse origin/main)"
    echo "== $name"
    if [ "$sha" = "$latest" ]; then
      echo "pinned commit is upstream main ($latest); nothing to update"
    else
      echo "pinned:   ${sha:-<none>}"; echo "upstream: $latest"
      [ -n "$sha" ] && git -C "$cache" diff --stat "$sha" "$latest" -- "$(field subdir "$lock")"
      echo "sync with: make vendor-update SOURCE=$name"
    fi
  done
}

cmd_status() { # [NAME]
  local name
  for name in $(targets "${1:-}"); do echo "== $name"; cat "$(lock_of "$name")"; done
}

# Exit 1 on a malformed lock; drift is reported as a warning (needs the cache).
cmd_check() {
  local name lock cache sha stage rc=0 f
  for name in $(names); do
    lock="$SOURCES/$name.lock"
    for f in upstream subdir location commit; do
      [ -n "$(field "$f" "$lock")" ] || { echo "ERROR $name: lock missing '$f:'"; rc=1; }
    done
    cache="$CACHE_ROOT/$name"; sha="$(field commit "$lock")"
    if [ ! -d "$cache/.git" ] || [ -z "$sha" ]; then
      echo "  $name: no local cache; run 'make vendor-update SOURCE=$name' once to enable drift detection"
      continue
    fi
    git -C "$cache" checkout --quiet --detach "$sha"
    stage="$(mktemp -d)"
    mirror "$name" "$cache" "$stage"
    if diff -rq "$stage" "$ROOT/$(field location "$lock")" >"$stage.diff" 2>&1; then
      echo "  ✓ $name matches pinned $sha"
    else
      sed "s/^/  WARN drift $name: /" "$stage.diff" | head -20
      echo "  WARN $name differs from its pin; was it hand-edited? re-sync with 'make vendor-update SOURCE=$name'"
    fi
    rm -rf "$stage" "$stage.diff"
  done
  return $rc
}

case "${1:-}" in
  list)   names;;
  status) cmd_status "${2:-}";;
  update) cmd_update "${2:-}" "${3:-}";;
  diff)   cmd_diff "${2:-}";;
  check)  cmd_check;;
  *)      sed -n '2,19p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; exit 1;;
esac
