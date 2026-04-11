---
name: nim-doc-comments
description: Document exported Nim modules and APIs with doc comments that `nim doc` actually picks up, including module docs, proc and type docs, field docs, and runnable examples. Use when writing documentation for a Nim library or fixing docs that are missing, attached to the wrong symbol, or rendering incorrectly.
---

# Nim Doc Comments

Write doc comments in the source layout that `nim doc` actually uses.

Larger examples live in `references/`.

## Rules

### Placement

- Module docs go at the top of the file, before imports.
- Proc/func/iterator/template/converter docs go immediately after the signature line, before the body.
- Inside `type`, `const`, and `let` blocks, attach docs to the declaration line with trailing `##`.
- For multi-line declaration docs, continue with aligned `##` lines under the declaration.
- Enum value and object field docs go on their declaration lines.
- Do not put a standalone `##` line above a declaration inside a `type` or `const` block and expect it to attach.

### Visibility

- Only exported symbols (`*`) appear in rendered docs. Non-exported symbols are hidden.

### runnableExamples

- Do not add `runnableExamples:` by default.
- If used, place `runnableExamples:` after doc text and before implementation statements.
- `nim doc` compiles and runs all `runnableExamples:` blocks.

### Content

- Start with a short summary sentence. Explain behavior, contracts, and constraints.
- Skip comments that only restate the symbol name or obvious type info.

## Workflow

1. Identify the exported API.
2. Place each doc comment using the correct source layout.
3. Run `nim doc path/to/module.nim`.
4. Check source placement and rendered output.
5. Fix the source comments. Never edit generated output.

## Common Mistakes

| Mistake | Why it's wrong |
|---------|----------------|
| Putting a proc doc comment above the proc signature | `nim doc` treats it as module documentation, not proc documentation. |
| Putting a standalone `##` line above a declaration inside a `type` or `const` block | It does not attach to that symbol; put the doc on the declaration line. |
| Checking only rendered HTML | A misplaced module-style comment can still render, so source placement still needs inspection. |

## References

- `references/module_docs.md` — Module doc patterns (line and block syntax)
- `references/proc_and_type_docs.md` — Proc, type, enum, const, and field doc placement
- `references/runnable_examples.md` — runnableExamples placement and parameterized flags

## Changelog

- 2026-04-09: Verified skill created from 14 empirically tested claims (all passing on Nim 2.3.1/ORC).
- 2026-04-09: Added empirically verified wrong-placement cases for proc docs above signatures and standalone docs above declarations inside `type`/`const` blocks.
