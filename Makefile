# Skills repo: install/manage these skills for your agents, and vendor upstream
# OCaml skills.
#
# Quick start:
#   make install          # symlink every skill into your agent skills dir
#   make skills-status     # show what's installed
#   make uninstall         # remove the symlinks this repo created
#
# ---------------------------------------------------------------------------
# Installing these skills
# ---------------------------------------------------------------------------
#
# Skills are installed by symlinking each skill directory into a shared store
# (default ~/.agents/skills), which both Claude Code (~/.claude/skills) and pi
# (~/.pi/agent/skills) already read through their own symlinks. The repo stays
# the source of truth: edit a SKILL.md here and it's live everywhere.
#
# Override the target dir with SKILLS_DIR=..., e.g.
#   make install SKILLS_DIR=~/.claude/skills
# Skip the vendored OCaml skills with INCLUDE_VENDOR=0.
#
# ---------------------------------------------------------------------------
# Vendoring of third-party OCaml agent skills.
#
# We vendor Anil Madhavapeddy's `ocaml-dev` plugin (avsm/ocaml-claude-marketplace)
# alongside our own skills so the OCaml *domain* skills (eio, result, testing,
# code-style, memtrace, fuzz, ...) sit next to our engineering *workflow* skills.
#
# Usage:
#   make vendor-update           # pull latest upstream main, re-sync, update lock
#   make vendor-update REF=<sha> # pin to a specific upstream commit
#   make vendor-diff             # show what upstream changed vs our vendored copy
#   make vendor-status           # print pinned commit + whether upstream moved

INSTALL        := scripts/install-skills.sh
EVAL           := scripts/skills-eval.sh

.DEFAULT_GOAL := help

.PHONY: help install uninstall skills-status list-skills check lint links metrics eval

help:
	@echo 'Skills repo — OCaml/FP agent skills'
	@echo
	@echo 'Install & manage:'
	@echo '  make install         symlink every skill into your agent skills dir'
	@echo '  make uninstall       remove the symlinks this repo created'
	@echo '  make skills-status   show which skills are installed (and from where)'
	@echo '  make list-skills     list every skill this repo provides'
	@echo '    vars: SKILLS_DIR=<dir> (default ~/.agents/skills), INCLUDE_VENDOR=0|1'
	@echo
	@echo 'Review suite (see evals/README.md):'
	@echo '  make check           lint: structural + hygiene checks (fails on error)'
	@echo '  make links           report broken intra-repo markdown links'
	@echo '  make metrics         per-skill size/trigger/code-block report'
	@echo '  make eval            check + links + metrics'
	@echo
	@echo 'Vendored upstream skills:'
	@echo '  make vendor-update   pull latest avsm/ocaml-dev, re-sync, update lock'
	@echo '  make vendor-diff     show what upstream changed vs our copy'
	@echo '  make vendor-status   print the pinned upstream commit'

install:
	@$(INSTALL) install "$(SKILLS_DIR)"

uninstall:
	@$(INSTALL) uninstall "$(SKILLS_DIR)"

skills-status:
	@$(INSTALL) status "$(SKILLS_DIR)"

list-skills:
	@$(INSTALL) list

check lint:
	@$(EVAL) lint

links:
	@$(EVAL) links

metrics:
	@$(EVAL) metrics

eval:
	@$(EVAL) all

VENDOR_NAME    := ocaml-claude-marketplace
UPSTREAM_URL   := https://github.com/avsm/ocaml-claude-marketplace.git
UPSTREAM_SUB   := plugins/ocaml-dev
VENDOR_DIR     := vendor/$(VENDOR_NAME)/ocaml-dev
LOCK           := vendor/$(VENDOR_NAME).lock
CACHE          := .vendor-cache/$(VENDOR_NAME)
REF            ?= origin/main

# rsync flags: mirror upstream subdir, drop VCS noise.
RSYNC_FLAGS := -a --delete --exclude '.git'

.PHONY: vendor-update vendor-diff vendor-status _vendor-fetch

_vendor-fetch:
	@mkdir -p $(dir $(CACHE))
	@if [ -d "$(CACHE)/.git" ]; then \
	  echo ">> fetching $(UPSTREAM_URL)"; \
	  git -C "$(CACHE)" fetch --quiet --tags origin; \
	else \
	  echo ">> cloning $(UPSTREAM_URL)"; \
	  git clone --quiet "$(UPSTREAM_URL)" "$(CACHE)"; \
	fi

vendor-update: _vendor-fetch
	@git -C "$(CACHE)" checkout --quiet --detach "$(REF)"
	@mkdir -p "$(VENDOR_DIR)"
	@rsync $(RSYNC_FLAGS) "$(CACHE)/$(UPSTREAM_SUB)/" "$(VENDOR_DIR)/"
	@sha=$$(git -C "$(CACHE)" rev-parse HEAD); \
	 date=$$(git -C "$(CACHE)" log -1 --format='%ci' HEAD); \
	 subj=$$(git -C "$(CACHE)" log -1 --format='%s' HEAD); \
	 printf 'upstream: %s\nsubdir:   %s\ncommit:   %s\ndate:     %s\nsubject:  %s\n' \
	   "$(UPSTREAM_URL)" "$(UPSTREAM_SUB)" "$$sha" "$$date" "$$subj" > "$(LOCK)"; \
	 echo ">> vendored $(VENDOR_DIR) @ $$sha"; \
	 echo ">> wrote $(LOCK)"

vendor-diff: _vendor-fetch
	@sha=$$(awk '/^commit:/{print $$2}' "$(LOCK)" 2>/dev/null); \
	 latest=$$(git -C "$(CACHE)" rev-parse origin/main); \
	 if [ "$$sha" = "$$latest" ]; then \
	   echo "Vendored copy is at upstream main ($$latest). Nothing to update."; \
	 else \
	   echo "Pinned : $$sha"; echo "Upstream: $$latest"; echo; \
	   git -C "$(CACHE)" diff --stat "$$sha" "$$latest" -- "$(UPSTREAM_SUB)"; \
	   echo; echo "Run 'make vendor-update' to sync, or 'git -C $(CACHE) diff $$sha origin/main -- $(UPSTREAM_SUB)' for the full patch."; \
	 fi

vendor-status:
	@cat "$(LOCK)" 2>/dev/null || echo "No lock file — run 'make vendor-update'."
