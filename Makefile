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
# (default ~/.agents/skills). Each agent's skill path (~/.claude/skills,
# ~/.pi/agent/skills) is a single symlink to that store, so new skills appear
# everywhere without per-agent bookkeeping. The repo stays the source of truth:
# edit a SKILL.md here and it's live everywhere.
#
# Override the target dir with SKILLS_DIR=..., e.g.
#   make install SKILLS_DIR=~/.claude/skills
# Skip the vendored OCaml skills with INCLUDE_VENDOR=0.
#
# ---------------------------------------------------------------------------
# Sources (see sources/README.md)
# ---------------------------------------------------------------------------
#
# Every skill is external. They differ by edit policy:
#   - skills/  = our DIVERGED FORK of mattpocock/skills (OCaml-adapted; we edit).
#                Update by merging the `upstream` remote.  `make fork-status`.
#   - vendor/  = VENDORED VERBATIM from upstream marketplaces (pinned, never
#                hand-edited): avsm/ocaml-claude-marketplace (ocaml-dev) and
#                gazagnaire.org/ocaml-claude-skills (monopam).
#                `make vendor-update` / `vendor-diff`.
# Provenance + locks for both live under sources/.

INSTALL        := scripts/install-skills.sh
EVAL           := scripts/skills-eval.sh

.DEFAULT_GOAL := help

.PHONY: help install uninstall prune skills-status list-skills check lint links metrics eval integrity check-ocaml vendor-check

help:
	@echo 'Skills repo — OCaml/FP agent skills'
	@echo
	@echo 'Install & manage:'
	@echo '  make install         symlink every skill into your agent skills dir'
	@echo '  make uninstall       remove the symlinks this repo created'
	@echo '  make prune           drop installed skills no longer in the repo (stale/dangling)'
	@echo '  make skills-status   show which skills are installed (and from where)'
	@echo '  make list-skills     list every skill this repo provides'
	@echo '    vars: SKILLS_DIR=<dir> (default ~/.agents/skills), INCLUDE_VENDOR=0|1'
	@echo
	@echo 'Review suite (see evals/README.md):'
	@echo '  make integrity       repo invariants (plugin.json/README/eval/names)'
	@echo '  make check           lint: structural + hygiene checks (fails on error)'
	@echo '  make links           report broken intra-repo markdown links'
	@echo '  make metrics         per-skill size/trigger/code-block report'
	@echo '  make vendor-check    vendored locks well-formed + no hand-edits (drift)'
	@echo '  make eval            integrity + lint + links + vendor-check + metrics'
	@echo '  make check-ocaml     parse ocaml code blocks (opt-in; needs OCaml toolchain)'
	@echo '  make waza            run model-graded routing evals (opt-in; needs waza)'
	@echo '  make waza-calibrate  run ONE suite verbose to read real token cost first'
	@echo '    vars: EXECUTOR=mock|copilot-sdk  MODEL=<id>  TRIALS=<n>  SUITE=<skill>'
	@echo
	@echo 'Sources (see sources/README.md):'
	@echo '  make fork-status     how far skills/ is behind mattpocock/skills upstream'
	@echo '  make vendor-update   re-sync ALL vendored sets to latest, update locks'
	@echo '  make vendor-diff     show what each upstream changed vs our pinned copy'
	@echo '  make vendor-status   print the pinned commit of each vendored set'
	@echo '    per-vendor: make vendor-update-<name> etc., name in: $(VENDORS)'

install:
	@$(INSTALL) install "$(SKILLS_DIR)"

uninstall:
	@$(INSTALL) uninstall "$(SKILLS_DIR)"

prune:
	@$(INSTALL) prune "$(SKILLS_DIR)"

skills-status:
	@$(INSTALL) status "$(SKILLS_DIR)"

list-skills:
	@$(INSTALL) list

integrity:
	@$(EVAL) integrity

check lint:
	@$(EVAL) lint

links:
	@$(EVAL) links

metrics:
	@$(EVAL) metrics

eval:
	@$(EVAL) all

check-ocaml:
	@$(EVAL) check-ocaml

vendor-check:
	@$(EVAL) vendor-check

# Model-graded routing evals (microsoft/waza). Skips cleanly if waza isn't installed.
# Override model/executor/trials without editing the 9 eval.yaml files, e.g.:
#   make waza EXECUTOR=copilot-sdk MODEL=claude-haiku-4-5
#   make waza-calibrate SUITE=tdd EXECUTOR=copilot-sdk MODEL=claude-haiku-4-5
# (real runs need a provider: GITHUB_TOKEN for Copilot, or COPILOT_BASE_URL for an
#  OpenAI-compatible proxy in front of Anthropic/Ollama. mock makes no API calls.)
EXECUTOR ?= mock
MODEL    ?=
TRIALS   ?= 1
SUITE    ?= tdd
WAZA_FLAGS = --executor $(EXECUTOR) --trials $(TRIALS) $(if $(MODEL),--model $(MODEL))

waza:
	@if ! command -v waza >/dev/null 2>&1; then \
	  echo "waza not installed — https://github.com/microsoft/waza (see evals/README.md)"; exit 0; \
	fi; \
	rc=0; for e in evals/*/eval.yaml; do echo "== $$e =="; waza run "$$e" $(WAZA_FLAGS) || rc=1; done; exit $$rc

# Run ONE suite verbose to read real token usage/cost before running all 18 tasks.
# Use a real executor + model to get actual numbers, e.g.:
#   make waza-calibrate SUITE=tdd EXECUTOR=copilot-sdk MODEL=claude-haiku-4-5
waza-calibrate:
	@if ! command -v waza >/dev/null 2>&1; then echo "waza not installed — see evals/README.md"; exit 0; fi; \
	echo "Calibrating evals/$(SUITE)/eval.yaml (executor=$(EXECUTOR), model=$(if $(MODEL),$(MODEL),<eval.yaml default>), trials=$(TRIALS))"; \
	$(if $(filter mock,$(EXECUTOR)),echo "NOTE: executor=mock makes no API calls / costs nothing — set EXECUTOR=copilot-sdk for real token usage.";,) \
	waza run "evals/$(SUITE)/eval.yaml" $(WAZA_FLAGS) --verbose --output ".waza-calibrate-$(SUITE).json"; \
	echo "Per-task token usage is in the output above and .waza-calibrate-$(SUITE).json — multiply by 18 tasks (× trials) for a full run."

# alias kept so `make check` in CI runs the full deterministic gate
check-all: integrity check links vendor-check

# Vendored upstreams, verbatim + pinned. To add one: append its name to
# VENDORS and define UPSTREAM_URL_<name> / UPSTREAM_SUB_<name>. It lands in
# vendor/<name>/<basename of subdir>/ with a lock at sources/<name>.lock.
VENDORS := ocaml-claude-marketplace ocaml-claude-skills

UPSTREAM_URL_ocaml-claude-marketplace := https://github.com/avsm/ocaml-claude-marketplace.git
UPSTREAM_SUB_ocaml-claude-marketplace := plugins/ocaml-dev

UPSTREAM_URL_ocaml-claude-skills := https://tangled.org/gazagnaire.org/ocaml-claude-skills
UPSTREAM_SUB_ocaml-claude-skills := plugins/monopam

vdir = vendor/$(1)/$(notdir $(UPSTREAM_SUB_$(1)))

FORK_LOCK      := sources/mattpocock-skills.lock
REF            ?= origin/main

# rsync flags: mirror upstream subdir, drop VCS noise.
RSYNC_FLAGS := -a --delete --exclude '.git'

.PHONY: vendor-update vendor-diff vendor-status fork-status waza waza-calibrate

fork-status:
	@git fetch --quiet upstream 2>/dev/null || true; \
	 fp=$$(awk '/^fork-point:/{print $$2}' "$(FORK_LOCK)" 2>/dev/null); \
	 latest=$$(git rev-parse upstream/main 2>/dev/null); \
	 echo "skills/ is a diverged fork of mattpocock/skills."; \
	 echo "  fork-point: $$fp"; echo "  upstream main: $$latest"; \
	 if [ -n "$$fp" ] && [ "$$fp" != "$$latest" ]; then \
	   n=$$(git rev-list --count "$$fp"..upstream/main 2>/dev/null); \
	   echo "  upstream is $$n commit(s) ahead of our fork-point."; \
	   echo "  pull with: git merge upstream/main  (then resolve + update $(FORK_LOCK))"; \
	 else echo "  up to date with upstream main."; fi

vendor-update: $(addprefix vendor-update-,$(VENDORS))
vendor-diff:   $(addprefix vendor-diff-,$(VENDORS))
vendor-status: $(addprefix vendor-status-,$(VENDORS))

_vendor-fetch-%:
	@mkdir -p .vendor-cache
	@if [ -d ".vendor-cache/$*/.git" ]; then \
	  echo ">> fetching $(UPSTREAM_URL_$*)"; \
	  git -C ".vendor-cache/$*" fetch --quiet --tags origin; \
	else \
	  echo ">> cloning $(UPSTREAM_URL_$*)"; \
	  git clone --quiet "$(UPSTREAM_URL_$*)" ".vendor-cache/$*"; \
	fi

vendor-update-%: _vendor-fetch-%
	@git -C ".vendor-cache/$*" checkout --quiet --detach "$(REF)"
	@mkdir -p "$(call vdir,$*)"
	@rsync $(RSYNC_FLAGS) ".vendor-cache/$*/$(UPSTREAM_SUB_$*)/" "$(call vdir,$*)/"
	@sha=$$(git -C ".vendor-cache/$*" rev-parse HEAD); \
	 date=$$(git -C ".vendor-cache/$*" log -1 --format='%ci' HEAD); \
	 subj=$$(git -C ".vendor-cache/$*" log -1 --format='%s' HEAD); \
	 printf 'upstream: %s\nsubdir:   %s\npolicy:   vendored verbatim (pinned; never hand-edited)\nlocation: %s\nupdate:   make vendor-update\ncommit:   %s\ndate:     %s\nsubject:  %s\n' \
	   "$(UPSTREAM_URL_$*)" "$(UPSTREAM_SUB_$*)" "$(call vdir,$*)/" "$$sha" "$$date" "$$subj" > "sources/$*.lock"; \
	 echo ">> vendored $(call vdir,$*) @ $$sha"; \
	 echo ">> wrote sources/$*.lock"

vendor-diff-%: _vendor-fetch-%
	@echo "== $* =="; \
	 sha=$$(awk '/^commit:/{print $$2}' "sources/$*.lock" 2>/dev/null); \
	 latest=$$(git -C ".vendor-cache/$*" rev-parse origin/main); \
	 if [ "$$sha" = "$$latest" ]; then \
	   echo "Vendored copy is at upstream main ($$latest). Nothing to update."; \
	 else \
	   echo "Pinned : $$sha"; echo "Upstream: $$latest"; echo; \
	   git -C ".vendor-cache/$*" diff --stat "$$sha" "$$latest" -- "$(UPSTREAM_SUB_$*)"; \
	   echo; echo "Run 'make vendor-update-$*' to sync, or 'git -C .vendor-cache/$* diff $$sha origin/main -- $(UPSTREAM_SUB_$*)' for the full patch."; \
	 fi

vendor-status-%:
	@echo "== $* =="; cat "sources/$*.lock" 2>/dev/null || echo "No lock file — run 'make vendor-update-$*'."
