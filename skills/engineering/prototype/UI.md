# UI Prototype

Generate **several radically different UI variations** on a single route, switchable from a floating bottom bar. The user flips between variants in the browser, picks one (or steals bits from each), then throws the rest away.

If the question is about logic/state rather than what something looks like — wrong branch. Use [LOGIC.md](LOGIC.md).

## Stack: Dream + htmx (simplest for OCaml)

Server-render the variants with [Dream](https://aantron.github.io/dream/) and let
[htmx](https://htmx.org/) handle the swapping. **No JS build step, no
js_of_ocaml, no Bonsai** — exactly what you want for throwaway UI.

- **Variants are HTML-returning functions.** Use Dream's built-in `.eml.html`
  embedded templates (HTML with `<%s ... %>` OCaml splices) or
  [`dream-html`](https://github.com/yawaramin/dream-html)/TyXML for typed
  combinators. Each variant is `val variant_a : data -> string` (or a
  `Dream_html.node`).
- **One Dream handler** reads `?variant=` and renders the matching variant, so a
  full page load is always correct and shareable.
- **htmx** swaps just the variant slot when the user clicks the switcher, and
  `hx-push-url` keeps the URL in sync.
- **Styling**: pull TailwindCSS from its CDN `<script>` in the layout, or plain
  CSS. (shadcn/MUI are React-only — not applicable here.)

If the project genuinely uses js_of_ocaml + Bonsai/Brr for its frontend, mirror
that instead — but for most OCaml work, Dream + htmx is the lowest-ceremony way to
get several real variants in front of the user.

## When this is the right shape

- "What should this page look like?"
- "I want to see a few options for this dashboard before committing."
- "Try a different layout for the settings screen."
- Any time the user would otherwise spend a day picking between three vague mockups in their head.

## Two sub-shapes — strongly prefer sub-shape A

A UI prototype is much easier to judge when it's **butting up against the rest of the app** — real header, real data, real density. A throwaway route on its own is a vacuum: every variant looks fine in isolation. Default to sub-shape A whenever there's a plausible existing page to host the variants. Only reach for sub-shape B if the prototype genuinely has no nearby home.

### Sub-shape A — adjustment to an existing page (preferred)

The route already exists. Variants are rendered **on the same route**, gated by a `?variant=` query param read with `Dream.query request "variant"`. The existing handler, data loading, and auth all stay — only the rendered body swaps. This is the default; pick it unless there's a specific reason not to.

If the prototype is for something that doesn't yet have a page but *would naturally live inside one* (a new section of the dashboard, a new card on the settings screen, a new step in an existing flow) — that's still sub-shape A. Mount the variants inside the host handler.

### Sub-shape B — a new route (last resort)

Only use this when the thing being prototyped genuinely has no existing page to live inside — e.g. an entirely new top-level surface, or a flow that can't be embedded anywhere sensible.

Add a **throwaway route** following whatever routing convention the project already uses. Name it so it's obviously a prototype (e.g. `Dream.get "/prototype/settings"`). Same `?variant=` pattern.

Before committing to sub-shape B, sanity-check: is there really no existing page this could be embedded in? An empty route hides design problems that a populated one would expose.

In both sub-shapes the floating bottom bar is identical.

## Process

### 1. State the question and pick N

Default to **3 variants**. More than 5 stops being radically different and starts being noise — cap there.

Write down the plan in one line, in the prototype's location or a top-of-file comment:

> "Three variants of the settings page, switchable via `?variant=`, on the existing `/settings` route."

This works whether the user is here to push back or not.

### 2. Generate radically different variants

Draft each variant. Hold each one to:

- The page's purpose and the data it has access to.
- The project's styling system (TailwindCSS via CDN, plain CSS, whatever).
- A clear function name, e.g. `variant_a`, `variant_b`, `variant_c`, each taking the page's `data` and returning HTML.

Variants must be **structurally different** — different layout, different information hierarchy, different primary affordance, not just different colours. Three slightly-tweaked card grids isn't a UI prototype, it's wallpaper. If two drafts come out too similar, redo one with explicit "do not use a card grid" guidance.

### 3. Wire them together

One handler picks the variant from the query param and renders it inside a slot,
with the floating switcher alongside:

```ocaml
(* pseudo-code — adapt to dream-html / .eml templates *)
let variants = [ "A", variant_a; "B", variant_b; "C", variant_c ]

let render request data =
  let key = Option.value (Dream.query request "variant") ~default:"A" in
  let body = (List.assoc_opt key variants |> Option.value ~default:variant_a) data in
  Dream.html (layout ~current:key ~slot:body)
```

The slot lives in a container htmx can target:

```html
<div id="variant-slot"><%s body %></div>
<%s prototype_switcher ~variants:["A";"B";"C"] ~current:key %>
```

For sub-shape A (existing page): keep all the existing data loading above this;
only the rendered slot changes per variant. For sub-shape B: the throwaway route
renders the same slot + switcher.

### 4. Build the floating switcher

A small fixed-position bar at the bottom-centre of the screen with three pieces:

- **Left arrow** — cycles to the previous variant (wraps around).
- **Variant label** — shows the current variant key and, if the variant has a name, that name too. e.g. `B — Sidebar layout`.
- **Right arrow** — cycles forward (wraps around).

Behaviour:

- Each arrow is an htmx request that swaps the slot and pushes the URL, so the variant is shareable and reload-stable (the server-side handler in step 3 renders the same variant on a fresh load):

  ```html
  <button
    hx-get="?variant=B"
    hx-target="#variant-slot"
    hx-select="#variant-slot"
    hx-swap="outerHTML"
    hx-push-url="true">→</button>
  ```

- Keyboard `←`/`→`: add a tiny inline `<script>` (or `_hyperscript`) that clicks
  the arrows on arrow-key press. Don't fire when an `<input>`, `<textarea>`, or
  `[contenteditable]` is focused.
- Visually distinct from the page (high-contrast pill, subtle shadow) so it's obviously not part of the design being evaluated.
- Dev-only — mount the prototype route (and switcher) behind a check like
  `if Sys.getenv_opt "PROTOTYPE" <> None then Dream.get ...`, or keep prototype
  routes in a router that production never mounts, so a stray merge can't ship the
  bar to users.

Put the switcher in a single shared function so both sub-shapes can reuse it.

### 5. Hand it over

Surface the URL (and the `?variant=` keys). The user will flip through whenever they get to it. The interesting feedback is usually **"I want the header from B with the sidebar from C"** — that's the actual design they want.

### 6. Capture the answer and clean up

Once a variant has won, write down which one and why (commit message, ADR, issue, or a `NOTES.md` next to the prototype if running AFK and the user hasn't responded yet). Then:

- **Sub-shape A** — delete the losing variant functions and the switcher; fold the winner into the existing handler/template.
- **Sub-shape B** — promote the winning variant to a real route, delete the throwaway route and the switcher.

Don't leave variant functions or the switcher lying around. They rot fast and confuse the next reader.

## Anti-patterns

- **Variants that differ only in colour or copy.** That's a tweak, not a prototype. Real variants disagree about structure.
- **Sharing too much markup between variants.** A shared header partial is fine; a shared layout defeats the point. Each variant should be free to throw out the layout.
- **Wiring variants to real mutations.** Read-only prototypes are fine. If a variant needs to mutate, point it at a stub — the question is "what should this look like", not "does the backend work".
- **Reaching for js_of_ocaml/Bonsai when htmx would do.** A build pipeline for throwaway UI is wasted effort. Server-render and swap.
- **Promoting the prototype directly to production.** The variant code was written under prototype constraints (no tests, minimal error handling). Rewrite it properly when you fold it in.
