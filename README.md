# Agent Skills

Curated skill modules for AI-assisted Nim development and general tooling.

## Skills

| Skill | Purpose |
|---|---|
| `nim-api-design` | Exported types, constructors, accessors, error contracts |
| `nim-c-bindings` | C library FFI, platform linking, cross-platform CI/release |
| `nim-c-wrappers` | Idiomatic Nim APIs over raw C FFI bindings |
| `nim-code-organization` | Module structure, orchestration, export surfaces |
| `nim-debugging` | Runtime inspection, stack traces, compiler flags, sanitizers |
| `nim-defect-analysis` | Reliability defect triage, root-cause tracing, evidence reports |
| `nim-doc-comments` | Doc comments that `nim doc` picks up, runnable examples |
| `nim-error-handling` | Exception vs Option, `raises` contracts, failure boundaries |
| `nim-fuzzing` | libFuzzer harnesses, corpus management, crash triage |
| `nim-ownership-hooks` | ARC/ORC `=destroy`, `=sink`, `=copy`, move semantics |
| `nim-style-guide` | Naming, formatting, proc vs func vs template, control flow |
| `nim-testing` | Block assertions, test runners, multi-config builds, sanitizers |
| `nimonyplugins` | Nimony plugin `NifCursor`/`NifBuilder` traversal and construction |

## Install

Symlink skills into your agent skills directory:

```bash
# clone anywhere
git clone <repo-url> ~/src/skills

# link all skills (user-wide)
for d in ~/src/skills/*/; do ln -sfn "$d" ~/.agents/skills/$(basename "$d"); done

# or clone directly
git clone <repo-url> ~/.agents/skills
```

## Skill naming

- Lowercase kebab-case.
- `nim-` prefix for Nim-specific skills.
- Plural form for broad guidance areas.
- Folder name matches the `name:` field in `SKILL.md`.

## License

CC BY-NC-SA 4.0 — see [LICENSE](LICENSE).
