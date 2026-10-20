# Skills repo: install/manage these skills for your agents, and vendor the
# upstream skill sets they are composed from.
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
# Two kinds of skill, split by edit policy:
#   - vendor/  = VENDORED VERBATIM from an upstream (pinned, never hand-edited):
#                mattpocock/skills (workflow), avsm/ocaml-claude-marketplace
#                (ocaml-dev), gazagnaire.org/ocaml-claude-skills (monopam) and
#                DreambigOu/ELI5.  `make vendor-update` / `vendor-diff`.
#   - skills/  = ours: local skills, plus OVERRIDES -- local adaptations of an
#                upstream skill that keep tracking it through
#                sources/overrides/overrides.lock (three-way merged on update).
# Provenance + locks live under sources/.

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
	@echo '  make vendor-update   re-sync ALL vendored sets to latest, update locks,'
	@echo '                       merge upstream changes into skills/ overrides'
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
#
# VENDOR_EXCLUDE_<name> drops paths (relative to the subdir) at vendor time.
# It is for skills an upstream ships that another source owns — recorded in
# the lock and honoured by the drift check, so it stays a declared vendoring
# decision rather than an undetectable hand-edit of vendor/.
#
# VENDOR_LICENSE_<name> names the upstream's license file (relative to the
# repo root) when it sits outside the vendored subdir; it is copied to
# vendor/<name>/ so the license travels with the code, and recorded in the lock.
VENDORS := mattpocock-skills ocaml-claude-marketplace ocaml-claude-skills eli5

# Matt Pocock's engineering + productivity workflow skills (grilling, tdd,
# triage, wayfinder, ...). This repo began as a fork of it; the git history
# keeps that, the layout no longer does: it is vendored like every other set.
#
# Dropped at vendor time:
#   - misc, deprecated, and the unfinished in-progress skills (loop-me,
#     setup-ts-deep-modules, writing-*): not promoted upstream, TS-specific.
#     chief-of-staff and claude-handoff ARE kept from in-progress.
#   - ask-matt, setup-matt-pocock-skills: route to / configure upstream's own
#     set; here the tracker and label context lives in AGENTS.md.
#   - code-review: review-diff (skills/engineering) owns review here.
#   - codebase-design diagnosing-bugs implement implement-spec prototype tdd
#     to-spec to-tickets triage wayfinder: OCaml-adapted OVERRIDES living in
#     skills/engineering/, tracking upstream via sources/overrides/overrides.lock.
UPSTREAM_URL_mattpocock-skills := https://github.com/mattpocock/skills.git
UPSTREAM_SUB_mattpocock-skills := skills
VENDOR_LICENSE_mattpocock-skills := LICENSE
VENDOR_EXCLUDE_mattpocock-skills := misc deprecated \
  in-progress/loop-me in-progress/setup-ts-deep-modules in-progress/writing-beats \
  in-progress/writing-fragments in-progress/writing-shape \
  engineering/ask-matt engineering/setup-matt-pocock-skills engineering/code-review \
  engineering/codebase-design engineering/diagnosing-bugs engineering/implement \
  engineering/implement-spec engineering/prototype engineering/tdd engineering/to-spec \
  engineering/to-tickets engineering/triage engineering/wayfinder

UPSTREAM_URL_ocaml-claude-marketplace := https://github.com/avsm/ocaml-claude-marketplace.git
UPSTREAM_SUB_ocaml-claude-marketplace := plugins/ocaml-dev
VENDOR_LICENSE_ocaml-claude-marketplace := LICENSE
# Crowbar fuzz skill dropped: the house fuzz library is alcobar, and the
# Alcobar fuzz skill comes from ocaml-claude-skills. project-setup dropped:
# init-ocaml owns new-package setup (house layout). Tool-conflict drops
# (2026-08 review): progress (console owns progress/spinners), logs
# (ocaml-observe owns logging wiring), memtrace (perf/obs owns allocation
# profiling), tutorials (mdx/readme own MDX conventions).
VENDOR_EXCLUDE_ocaml-claude-marketplace := skills/fuzz skills/project-setup skills/progress skills/logs skills/memtrace skills/tutorials

UPSTREAM_URL_ocaml-claude-skills := https://tangled.org/gazagnaire.org/ocaml-claude-skills
UPSTREAM_SUB_ocaml-claude-skills := plugins/monopam
VENDOR_LICENSE_ocaml-claude-skills := LICENSE.md
# monopam-tool-specific skills dropped: this workspace vendors with unpac, and
# the unpac counterparts live in skills/engineering/ (unpac, fork-package).
# ocaml-protocols and init-ocaml dropped here because they are local overrides
# that track upstream through sources/overrides/overrides.lock (scripts/merge-overrides.sh).
# requests dropped (2026-08 review): cohttp-eio owns HTTP.
VENDOR_EXCLUDE_ocaml-claude-skills := skills/monopam skills/concurrent-claude skills/fork-package skills/ocaml-protocols skills/init-ocaml skills/requests

# DreambigOu's ELI5 — audience-calibrated explanation (kids, managers,
# engineers, family). Not OCaml, not a workflow: a presentation skill.
#
# Vendored WHOLE (subdir '.') because the skill's only sibling worth carrying
# is the LICENSE — the repo has no plugin dir, its skills live at skills/, so
# there is no subdir that holds both. UPSTREAM_DIR names the landing dir.
#
# eli5-workspace/ dropped: it is the author's own eval harness (a Python
# runner, its tests, and a results log) that scores the skill against Claude.
# It is authoring infrastructure for upstream, not part of the skill, and this
# repo has its own evals/ — vendoring it would install a second, divergent one.
UPSTREAM_URL_eli5 := https://github.com/DreambigOu/ELI5.git
UPSTREAM_SUB_eli5 := .
UPSTREAM_DIR_eli5 := eli5
VENDOR_EXCLUDE_eli5 := eli5-workspace

# Landing dir under vendor/<name>/. Defaults to the subdir's basename;
# UPSTREAM_DIR_<name> overrides it (needed when the subdir is the repo root).
vdirname = $(or $(UPSTREAM_DIR_$(1)),$(notdir $(UPSTREAM_SUB_$(1))))
vdir     = vendor/$(1)/$(call vdirname,$(1))
vexcl    = $(foreach e,$(VENDOR_EXCLUDE_$(1)),--exclude '/$(e)')

REF            ?= origin/main

# rsync flags: mirror upstream subdir, drop VCS noise.
RSYNC_FLAGS := -a --delete --exclude '.git'

.PHONY: vendor-update vendor-diff vendor-status waza waza-calibrate

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
	@rsync $(RSYNC_FLAGS) $(call vexcl,$*) ".vendor-cache/$*/$(UPSTREAM_SUB_$*)/" "$(call vdir,$*)/"
	@sha=$$(git -C ".vendor-cache/$*" rev-parse HEAD); \
	 date=$$(git -C ".vendor-cache/$*" log -1 --format='%ci' HEAD); \
	 subj=$$(git -C ".vendor-cache/$*" log -1 --format='%s' HEAD); \
	 printf 'upstream: %s\nsubdir:   %s\npolicy:   vendored verbatim (pinned; never hand-edited)\nlocation: %s\nupdate:   make vendor-update\ncommit:   %s\ndate:     %s\nsubject:  %s\n' \
	   "$(UPSTREAM_URL_$*)" "$(UPSTREAM_SUB_$*)" "$(call vdir,$*)/" "$$sha" "$$date" "$$subj" > "sources/$*.lock"; \
	 for e in $(VENDOR_EXCLUDE_$*); do echo "exclude:  $$e" >> "sources/$*.lock"; done; \
	 echo ">> vendored $(call vdir,$*) @ $$sha"; \
	 echo ">> wrote sources/$*.lock"
	@if [ -n "$(VENDOR_LICENSE_$*)" ]; then \
	   cp ".vendor-cache/$*/$(VENDOR_LICENSE_$*)" "vendor/$*/$(notdir $(VENDOR_LICENSE_$*))"; \
	   echo "license:  $(VENDOR_LICENSE_$*)" >> "sources/$*.lock"; \
	   echo ">> copied upstream $(VENDOR_LICENSE_$*) to vendor/$*/"; \
	 fi
	@if awk -v v="$*" '$$2 == v { f = 1 } END { exit !f }' sources/overrides/overrides.lock; then \
	   scripts/merge-overrides.sh "$*" "$(UPSTREAM_SUB_$*)"; \
	 fi

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
