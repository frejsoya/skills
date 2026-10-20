#!/usr/bin/env bash
#
# Install this repo's skills into your agent skills dirs by symlinking, so the
# repo stays the single source of truth (edit here -> live everywhere).
#
# Layout on this machine: a shared store (~/.agents/skills) holds one symlink per
# skill pointing into this repo, and each agent path (~/.claude/skills,
# ~/.pi/agent/skills) is a single symlink to the store. Install populates the
# store, then ensures each agent path is that one symlink (backing up any real
# directory it replaces). New skills appear in every agent automatically.
#
# Usage:
#   install-skills.sh install   [STORE]
#   install-skills.sh uninstall [STORE]
#   install-skills.sh prune     [STORE]   # drop installed skills no longer in repo
#   install-skills.sh status    [STORE]
#   install-skills.sh list
#
# Env:
#   SKILLS_DIR       the shared store (default: $HOME/.agents/skills); arg overrides
#   AGENT_DIRS       space-separated agent skill paths to point at the store
#                    (default: ~/.claude/skills ~/.pi/agent/skills)
#   INCLUDE_VENDOR   1 (default) to include vendored skills, 0 to skip
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CMD="${1:-help}"
STORE="${2:-${SKILLS_DIR:-$HOME/.agents/skills}}"
INCLUDE_VENDOR="${INCLUDE_VENDOR:-1}"

# Agent skill paths that should be a single symlink to the store. Auto-detect
# (parent dir exists = agent installed on this machine) unless overridden.
if [ -z "${AGENT_DIRS:-}" ]; then
  AGENT_DIRS=""
  for d in "$HOME/.claude/skills" "$HOME/.pi/agent/skills"; do
    [ -d "$(dirname "$d")" ] && [ "$d" != "$STORE" ] && AGENT_DIRS="$AGENT_DIRS $d"
  done
fi

discover_raw() {
  find "$ROOT/skills" -iname 'skill.md' -not -path '*/deprecated/*' \
    -exec dirname {} \; 2>/dev/null | sort
  if [ "$INCLUDE_VENDOR" = "1" ] && [ -d "$ROOT/vendor" ]; then
    find "$ROOT/vendor" -iname 'skill.md' -exec dirname {} \; 2>/dev/null | sort
  fi
}

# The install surface is flat (one symlink per skill name), so when sources
# overlap the first in discover order wins: local skills, then vendors sorted.
discover() { discover_raw | awk -F/ '!seen[$NF]++'; }
dupes()    { discover_raw | awk -F/ 'seen[$NF]++'; }

green() { printf '\033[32m%s\033[0m' "$1"; }
yellow() { printf '\033[33m%s\033[0m' "$1"; }
bold() { printf '\033[1m%s\033[0m' "$1"; }
dim() { printf '\033[2m%s\033[0m' "$1"; }

# link SRC at LINK, backing up a real (non-symlink) target. echoes: linked|relinked|skipped|backed
link_one() {
  local src="$1" link="$2" backup="$3"
  if [ -L "$link" ]; then
    [ "$(readlink "$link")" = "$src" ] && { echo skipped; return; }
    rm -f "$link"; ln -s "$src" "$link"; echo relinked; return
  elif [ -e "$link" ]; then
    mkdir -p "$backup"; mv "$link" "$backup/$(basename "$link")"
    ln -s "$src" "$link"; echo backed; return
  fi
  ln -s "$src" "$link"; echo linked
}

case "$CMD" in
  list)
    echo "Skills provided by this repo:"
    while IFS= read -r src; do [ -z "$src" ] && continue
      printf '  %-32s %s\n' "$(basename "$src")" "$(dim "${src#"$ROOT"/}")"
    done < <(discover)
    ;;

  install)
    mkdir -p "$STORE"
    ts="$(date +%Y%m%d-%H%M%S)"; backup="$STORE/.skills-backup-$ts"
    linked=0 relinked=0 backed=0
    # Phase 1: store -> repo
    while IFS= read -r src; do [ -z "$src" ] && continue
      name="$(basename "$src")"
      case "$(link_one "$src" "$STORE/$name" "$backup")" in
        linked) linked=$((linked+1));; relinked) relinked=$((relinked+1));; backed) backed=$((backed+1));;
      esac
    done < <(discover)
    echo "$(green "✓") store $(bold "$STORE"): linked $linked, repointed $relinked, backed up $backed"
    [ -d "$backup" ] && echo "  $(yellow "backups:") $backup"
    while IFS= read -r skip; do [ -z "$skip" ] && continue
      echo "  $(yellow "name collision:") skipped ${skip#"$ROOT"/} $(dim "(an earlier source provides '$(basename "$skip")')")"
    done < <(dupes)
    # Phase 2: each agent path is one symlink to the store
    for adir in $AGENT_DIRS; do
      abackup="$(dirname "$adir")/.skills-backup-$ts"
      case "$(link_one "$STORE" "$adir" "$abackup")" in
        backed) echo "$(green "✓") agent $(bold "$adir") -> store $(yellow "(old dir moved to $abackup)")";;
        *)      echo "$(green "✓") agent $(bold "$adir") -> store";;
      esac
    done
    echo "  $(dim "Restart the agent to pick up new/changed skills.")"
    ;;

  uninstall)
    removed=0
    for tdir in $AGENT_DIRS "$STORE"; do
      # agent paths that are symlinks to the store are covered by the store pass
      [ "$tdir" != "$STORE" ] && [ "$(readlink -f "$tdir" 2>/dev/null)" = "$(readlink -f "$STORE" 2>/dev/null)" ] && continue
      while IFS= read -r src; do [ -z "$src" ] && continue
        name="$(basename "$src")"; link="$tdir/$name"
        # remove if it points at the store entry (agent dirs) or the repo (store)
        if [ -L "$link" ]; then
          tgt="$(readlink "$link")"
          if [ "$tgt" = "$src" ] || [ "$tgt" = "$STORE/$name" ]; then
            rm -f "$link"; removed=$((removed+1))
          fi
        fi
      done < <(discover)
    done
    echo "$(green "✓") removed $removed symlink(s)"
    echo "  $(dim "Backed-up originals (if any) remain under .skills-backup-* dirs.")"
    ;;

  prune)
    # Remove installed entries that no longer correspond to a repo skill:
    # stale/dangling symlinks are deleted; orphan real dirs are moved to a backup.
    # Links pointing outside this repo belong to another installer (a tool that
    # ships its own skill, another marketplace) and are left alone — prune only
    # cleans up after itself.
    valid="$(discover | xargs -n1 basename 2>/dev/null | sort -u)"
    ts="$(date +%Y%m%d-%H%M%S)"
    pruned=0 backed=0 foreign=0
    for tdir in $AGENT_DIRS "$STORE"; do
      [ -d "$tdir" ] || continue
      # agent paths that are symlinks to the store are covered by the store pass
      [ "$tdir" != "$STORE" ] && [ "$(readlink -f "$tdir")" = "$(readlink -f "$STORE")" ] && continue
      for entry in "$tdir"/*; do
        [ -e "$entry" ] || [ -L "$entry" ] || continue
        name="$(basename "$entry")"
        case "$name" in .skills-backup-*|README.md) continue;; esac
        printf '%s\n' "$valid" | grep -qx "$name" && continue   # still a real skill
        if [ -L "$entry" ]; then
          case "$(readlink "$entry")" in
            "$ROOT"/*) rm -f "$entry"; pruned=$((pruned+1))
                       echo "  $(yellow "− link") $tdir/$name";;
            *)         foreign=$((foreign+1))
                       echo "  $(dim "· keep") $tdir/$name $(dim "-> not ours, left alone")";;
          esac
        elif [ -d "$entry" ]; then
          mkdir -p "$tdir/.skills-backup-$ts"; mv "$entry" "$tdir/.skills-backup-$ts/$name"; backed=$((backed+1))
          echo "  $(yellow "− dir ") $tdir/$name $(dim "-> .skills-backup-$ts/")"
        fi
      done
    done
    echo "$(green "✓") pruned $pruned stale link(s), backed up $backed orphan dir(s), left $foreign foreign link(s)"
    ;;

  status)
    echo "Store: $(bold "$STORE")"
    for adir in $AGENT_DIRS; do
      if [ "$(readlink -f "$adir" 2>/dev/null)" = "$(readlink -f "$STORE" 2>/dev/null)" ]; then
        echo "  $(green "●") agent $adir $(dim "-> store")"
      elif [ -d "$adir" ]; then
        echo "  $(yellow "○") agent $adir $(dim "real dir / not linked to store — run install")"
      else
        echo "  $(dim "·") agent $adir $(dim "absent — run install")"
      fi
    done
    while IFS= read -r src; do [ -z "$src" ] && continue
      name="$(basename "$src")"; link="$STORE/$name"
      if [ -L "$link" ] && [ "$(readlink "$link")" = "$src" ]; then
        printf '  %s %-30s %s\n' "$(green "●")" "$name" "$(dim "store -> repo")"
      elif [ -e "$link" ]; then
        printf '  %s %-30s %s\n' "$(yellow "○")" "$name" "$(dim "store entry not ours")"
      else
        printf '  %s %-30s %s\n' "$(dim "·")" "$name" "$(dim "not installed")"
      fi
    done < <(discover)
    ;;

  *)
    sed -n '2,21p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
    ;;
esac
