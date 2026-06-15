# Deep Modules

From "A Philosophy of Software Design":

**Deep module** = small interface + lots of implementation

```
┌─────────────────────┐
│   Small Interface   │  ← Few values, simple params
├─────────────────────┤
│                     │
│                     │
│  Deep Implementation│  ← Complex logic hidden
│                     │
│                     │
└─────────────────────┘
```

**Shallow module** = large interface + little implementation (avoid)

```
┌─────────────────────────────────┐
│       Large Interface           │  ← Many values, complex params
├─────────────────────────────────┤
│  Thin Implementation            │  ← Just passes through
└─────────────────────────────────┘
```

## In OCaml

The `.mli` is the interface; the `.ml` is the deep implementation. A deep module
has a short `.mli` over a substantial `.ml`. OCaml's module system makes this the
natural unit: hide types with abstract signatures (`type t`), expose only the
values callers genuinely need, and let everything else stay private to the `.ml`.

When designing interfaces, ask:

- Can I reduce the number of values exposed in the `.mli`?
- Can I make the type abstract (`type t`) instead of leaking its shape?
- Can I simplify the parameters?
- Can I hide more complexity inside the `.ml`?
