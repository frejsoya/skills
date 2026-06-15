#!/usr/bin/env bash
#
# Install this repo's skills into your agent skills dirs by symlinking, so the
# repo stays the single source of truth (edit here -> live everywhere).
#
# Layout on this machine: a shared store (~/.agents/skills) holds each skill, and
# each agent dir (~/.claude/skills, ~/.pi/agent/skills) forwards into it. Install
# populates the store with links to this repo, then ensures every agent dir has a
# forwarding link for each skill (including brand-new ones).
#
# Usage:
#   install-skills.sh install   [STORE]
#   install-skills.sh uninstall [STORE]
#   install-skills.sh status    [STORE]
#   install-skills.sh list
#
# Env:
#   SKILLS_DIR       the shared store (default: $HOME/.agents/skills); arg overrides
#   AGENT_DIRS       space-separated agent dirs to forward into
#                    (default: auto-detect ~/.claude/skills ~/.pi/agent/skills)
#   INCLUDE_VENDOR   1 (default) to include vendored skills, 0 to skip
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CMD="${1:-help}"
STORE="${2:-${SKILLS_DIR:-$HOME/.agents/skills}}"
INCLUDE_VENDOR="${INCLUDE_VENDOR:-1}"

# Agent dirs that forward into the store. Auto-detect unless overridden.
if [ -z "${AGENT_DIRS:-}" ]; then
  AGENT_DIRS=""
  for d in "$HOME/.claude/skills" "$HOME/.pi/agent/skills"; do
    [ -d "$d" ] && [ "$d" != "$STORE" ] && AGENT_DIRS="$AGENT_DIRS $d"
  done
fi

discover() {
  find "$ROOT/skills" -iname 'skill.md' -not -path '*/deprecated/*' \
    -exec dirname {} \; 2>/dev/null | sort
  if [ "$INCLUDE_VENDOR" = "1" ] && [ -d "$ROOT/vendor" ]; then
    find "$ROOT/vendor" -iname 'skill.md' -exec dirname {} \; 2>/dev/null | sort
  fi
}

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
    # Phase 2: each agent dir -> store
    for adir in $AGENT_DIRS; do
      mkdir -p "$adir"; fwd=0; abackup="$adir/.skills-backup-$ts"
      while IFS= read -r src; do [ -z "$src" ] && continue
        name="$(basename "$src")"
        case "$(link_one "$STORE/$name" "$adir/$name" "$abackup")" in
          skipped) ;; *) fwd=$((fwd+1));;
        esac
      done < <(discover)
      echo "$(green "✓") agent $(bold "$adir"): $fwd forwarder(s) ensured"
    done
    echo "  $(dim "Restart the agent to pick up new/changed skills.")"
    ;;

  uninstall)
    removed=0
    for tdir in $AGENT_DIRS "$STORE"; do
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

  status)
    echo "Store: $(bold "$STORE")   Agents:${AGENT_DIRS:- (none)}"
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
