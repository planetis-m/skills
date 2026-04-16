# Agent Skills Repo

This repository contains custom Codex skills.

Each skill lives in its own folder and includes a `SKILL.md` file.

## Current skills

- `nim-c-bindings`: Nim-to-C binding rules, platform linking, and cross-platform CI/release workflows.
- `nim-ownership-hooks`: Nim ARC/ORC ownership hooks and move semantics guidance.
- `nim-style-guide`: Nim formatting, naming, call-style, and readability conventions.
- `nim-api-design`: Nim API contracts, data modeling, and accessor design guidance.
- `nim-error-handling`: Nim exception, propagation, and failure-boundary guidance.
- `nim-code-organization`: Nim module hygiene, orchestration structure, and export-surface guidance.
- `product-readme-examples`: Guidance for user-facing README and example writing.
- `nim-doc-comments`: Nim doc comment placement, writing, and `nim doc` verification guidance.
- `nimonyplugins`: Nimony plugin `Tree`/`Node` traversal, construction, and API usage patterns.
- `nim-c-wrappers`: Guidelines for building idiomatic Nim wrappers on top of C FFI bindings.

## Repository conventions

Skill names in this repository use these conventions:

- Use lowercase kebab-case only.
- Prefer short, descriptive names over generic nouns.
- Namespace Nim-specific skills with `nim-` when it improves clarity.
- Use plural forms for broad guidance areas when the skill covers a category rather than one artifact.
- Keep the skill folder name and the `name:` value in `SKILL.md` identical.

## Where to install skills

Codex loads skills from these scopes:

- Project scope: `<project>/.agents/skills`
- User scope: `~/.agents/skills`
- Admin scope: `/etc/codex/skills`
- System scope: bundled with Codex (for example `skill-creator`, `skill-installer`)

Use `~/.agents/skills` for personal skills across repositories, and `<project>/.agents/skills` when a skill should apply only to one codebase.

## Recommended setup for this git repo

Keep this repository anywhere (for example `~/src/skills`) and symlink the skill folders into the Codex skills directory.

### User-wide setup (`~/.agents/skills`)

```bash
mkdir -p ~/.agents/skills

# from this repo root
for d in nim-c-bindings nim-ownership-hooks nim-style-guide nim-api-design nim-error-handling nim-code-organization nimonyplugins product-readme-examples nim-doc-comments nim-c-wrappers; do
  ln -sfn "$(pwd)/$d" "$HOME/.agents/skills/$d"
done
```

### Project-only setup (`<project>/.agents/skills`)

```bash
PROJECT=/path/to/your/project
mkdir -p "$PROJECT/.agents/skills"

# from this repo root
for d in nim-c-bindings nim-ownership-hooks nim-style-guide nim-api-design nim-error-handling nim-code-organization nimonyplugins product-readme-examples nim-doc-comments nim-c-wrappers; do
  ln -sfn "$(pwd)/$d" "$PROJECT/.agents/skills/$d"
done
```

Symlinked skill folders are supported, so updates in this repo are immediately reflected in linked skill locations.

## Alternative: clone directly into `~/.agents/skills`

If you want this repo to be your entire user skill directory:

```bash
git clone <your-repo-url> ~/.agents/skills
```

Use this only if you are okay with this repo owning that directory.

## Reloading and verification

- Codex usually auto-detects skill changes.
- If a new/updated skill does not appear, restart Codex.
- In CLI/IDE, use `/skills` (or type `$`) to confirm visibility.

## Optional: disable a skill without deleting it

Add to `~/.codex/config.toml`:

```toml
[[skills.config]]
path = "/full/path/to/skill/SKILL.md"
enabled = false
```

Then restart Codex.

## License

Licensed under **CC BY-NC-SA 4.0**. See [LICENSE](LICENSE).
