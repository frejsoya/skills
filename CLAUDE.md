Skills are organized into bucket folders under `skills/`:

- `engineering/` — daily code work
- `productivity/` — daily non-code workflow tools
- `personal/` — tied to my own setup, not promoted

Every skill in `engineering/` or `productivity/` must have a reference in the top-level `README.md` and an entry in `.claude-plugin/plugin.json`. Skills in `personal/` must not appear in either.

Each skill entry in the top-level `README.md` must link the skill name to its `SKILL.md`.

Each bucket folder has a `README.md` that lists every skill in the bucket with a one-line description, with the skill name linked to its `SKILL.md`.

`vendor/` holds upstream skill sets vendored verbatim: pinned, never hand-edited, refreshed with `make vendor-update`. A local adaptation of an upstream skill is an *override*: it lives in `skills/`, opens with an `<!-- override: ... -->` comment listing the local changes to keep, and is registered in `sources/overrides/overrides.lock` so `make vendor-update` three-way merges upstream changes into it. See `sources/README.md`.
