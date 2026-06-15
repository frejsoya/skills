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
