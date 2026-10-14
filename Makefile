# Skills repo: install/manage these skills for your agents, and vendor upstream
# skill sets.
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
# Sources (see sources/README.md)
# ---------------------------------------------------------------------------
#
# Every skill is external. They differ by edit policy:
#   - skills/  = our DIVERGED FORK of mattpocock/skills (OCaml-adapted; we edit).
#                Update by merging the `upstream` remote.  `make fork-status`.
#   - vendor/  = VENDORED VERBATIM, one source per sources/<name>.lock (pinned,
#                never hand-edited).  `make vendor-update` / `vendor-diff`.
# Provenance + locks for both live under sources/.

INSTALL        := scripts/install-skills.sh
EVAL           := scripts/skills-eval.sh
VENDOR         := scripts/vendor.sh

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
	@echo '  make vendor-list     list the vendored sources'
	@echo '  make vendor-update   re-sync vendored sources to latest, update their locks'
	@echo '  make vendor-diff     show what upstream changed vs our pinned copies'
	@echo '  make vendor-status   print the pinned commits'
	@echo '    vars: SOURCE=<name> (default: all vendored sources), REF=<sha> (update only)'

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

FORK_LOCK      := sources/mattpocock-skills.lock
SOURCE         ?=
REF            ?=

.PHONY: vendor-update vendor-diff vendor-status vendor-list fork-status waza waza-calibrate

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

vendor-list:
	@$(VENDOR) list

vendor-update:
	@$(VENDOR) update "$(SOURCE)" "$(REF)"

vendor-diff:
	@$(VENDOR) diff "$(SOURCE)"

vendor-status:
	@$(VENDOR) status "$(SOURCE)"
