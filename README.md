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
| `product-readme-examples` | User-facing README and example writing |

## Install

Clone anywhere, then run `install.sh` to symlink skills into one or more
agent roots. The script also prunes stale symlinks for skills that have
been removed or renamed.

```bash
git clone <repo-url> ~/src/nim-skills
cd ~/src/nim-skills

./install.sh                          # default: ~/.agents
./install.sh ~/.claude                 # Claude Code
./install.sh ~/.agents ~/.claude       # multiple targets
./install.sh -n ~/.claude              # dry run
```

Skills are linked into `TARGET/skills/<skill-name>`. Re-run after `git pull`
to pick up new skills and prune deleted ones. See `./install.sh --help`.

## Skill naming

- Lowercase kebab-case.
- `nim-` prefix for Nim-specific skills.
- Plural form for broad guidance areas.
- Folder name matches the `name:` field in `SKILL.md`.

## License

CC BY-NC-SA 4.0 — see [LICENSE](LICENSE).
