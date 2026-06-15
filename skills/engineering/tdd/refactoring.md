# Refactor Candidates

After TDD cycle, look for:

- **Duplication** → Extract a shared function or module
- **Long functions** → Break into helpers that stay out of the `.mli` (keep tests on the exported interface)
- **Shallow modules** → Combine or deepen behind a smaller `.mli`
- **Logic far from its data** → Move it into the module that owns the type
- **Primitive obsession** (bare `string`/`int` carrying meaning) → Wrap in an abstract type or a variant so the compiler enforces the distinction
- **Existing code** the new code reveals as problematic
