---
name: atlas-package-cloner
description: Use Atlas to initialize Nim projects, install or update Atlas-managed dependencies, configure dependency directories, inspect Atlas-generated nim.cfg paths, handle Atlas overrides, features, plugins, lockfiles, and local Nim environments. Use when setting up or repairing Nim dependency workflows that use Atlas instead of Nimble's global package path.
---

# Atlas Package Cloner

# Rules

## Project State

- Treat either root `atlas.config` or `<deps>/atlas.config` as Atlas config. Atlas prefers root
  `atlas.config` when present, but `atlas init` creates `deps/atlas.config` by default.
- Use `atlas init` from the project root to initialize Atlas state.
- Use `atlas init --deps=DIR` or `atlas --deps=DIR init` when the project intentionally uses a
  dependency directory other than `deps/`.
- After initialization, inspect `<deps>/atlas.config`; the default config records `deps`,
  `nameOverrides`, `urlOverrides`, `pkgOverrides`, `plugins`, `resolver`, and `graph`.
- Do not assume `atlas init` creates `nim.cfg`. Atlas has code paths that patch `nim.cfg` when
  dependency operations need compiler paths.

## Commands

- Use `atlas use <url|pkgname>` to add a dependency.
- Use `atlas install` when the Nimble file already contains requirements and Atlas should
  materialize the dependency graph.
- Use `atlas update [filter]` to refresh dependency refs. Prefer a filter when only one dependency
  needs an update.
- Use `atlas link <path>` only for local project linking tasks; be prepared to inspect generated
  link files and the linked project's dependency graph state.
- Use `atlas pin [atlas.lock]` to pin current dependency checkouts.
- Use `atlas rep [atlas.lock]` to replay a lockfile. `atlas replay` and `atlas reproduce` are aliases.
- Use `atlas --noexec rep [atlas.lock]` when replay should avoid build actions that may run
  arbitrary code.
- Use `atlas env <nimversion>` for project-local Nim environments, for example `atlas env 1.6.12`
  or `atlas env devel`.

## Package Names, URLs, And Indexes

- Package names are resolved through Atlas' package lookup table, populated from `packages.json`, plus configured `nameOverrides`.
- URL inputs are parsed as URLs and can be rewritten with `urlOverrides`.
- Forge aliases are valid package references:

| Alias | Expands to |
|-------|------------|
| `gh:user/repo` or `github:user/repo` | `https://github.com/user/repo` |
| `gl:user/repo` or `gitlab:user/repo` | `https://gitlab.com/user/repo` |
| `srht:user/repo` or `sourcehut:user/repo` | `https://git.sr.ht/~user/repo` |
| `cb:user/repo`, `cberg:user/repo`, or `codeberg:user/repo` | `https://codeberg.org/user/repo` |

- Atlas downloads `packages.json` into the package cache by default, using `packages.nim-lang.org`
  with GitHub fallback.
- Use `--packagesRepo` only when the workflow needs the full `nim-lang/packages` git repository behavior.
- Use `--forceGitToHttps` when dependency URLs need `git://` rewritten to `https://`.
- If a package name or URL resolves incorrectly, fix `nameOverrides`, `urlOverrides`, or
  `pkgOverrides` in `<deps>/atlas.config` instead of editing generated paths by hand.

## Generated nim.cfg Paths

- Atlas' `nim.cfg` patcher uses this section shape:

```text
############# begin Atlas config section ##########
--noNimblePath
--path:"deps/pkg"
############# end Atlas config section   ##########
```

- Inspect the Atlas section in `nim.cfg` when imports fail.
- Preserve user-written content outside the Atlas begin/end section.
- Do not hand-edit generated `--path` entries as the first fix. Correct the dependency graph,
  package metadata, or config overrides instead.

## Resolution And Overrides

- Atlas supports `MinVer`, `SemVer`, and `MaxVer` resolver algorithms.
- The generated default config uses `SemVer`.
- Set resolver policy in `<deps>/atlas.config` or with `--resolver=minver|semver|maxver` when the
  task requires a specific policy.
- Use `nameOverrides` for package-name-to-URL mapping.
- Use `urlOverrides` for URL rewrite rules.
- Use `pkgOverrides` when multiple URLs conflict for the same package shortname.
- Keep overrides in Atlas config so future `install`, `use`, `update`, and `rep` commands remain
  repeatable.

## Features

- Atlas supports Nimble `feature` statements.
- Pass feature flags explicitly with `--feature=<feature>`. Pass multiple `--feature` options when
  multiple features are required, or use `--features=<list>` for a comma- or space-separated list.
- Use `--allFeatures` only when every declared feature should be enabled.
- Use `--keepFeatures` or `-k` when the command should reuse feature defines from the current `nim.cfg`.
- Feature request flags populate runtime context; they are not saved as fields in `atlas.config`.
- In Nimble requirements, feature syntax has the shape `require "somelib[testing]"`.

## Plugins And Build Actions

- Atlas plugins are `*.nims` files read from the project-relative directory configured by the `plugins` field.
- Treat plugin execution as potentially arbitrary code execution because plugins can call external tools.
- Inspect the configured plugin directory before enabling plugins or replaying dependencies with execution enabled.
- Use `--noexec` when the task only needs dependency graph setup or lockfile replay and build actions should not run.

## Virtual Nim Environments

- `atlas env <version>` creates a project-local Nim environment under the dependency directory.
- After a successful env setup, activate it explicitly:
  - Unix: `source deps/nim-<version>/activate.sh`
  - Windows: `deps\nim-<version>\activate.bat`
- Do not assume the virtual Nim environment is active in later shell sessions.

# Workflow

1. Inspect the project root.
   Look for `*.nimble`, `nim.cfg`, `atlas.lock`, `deps/`, and any custom dependency directory.
2. Locate Atlas config.
   Check root `atlas.config` first, then `<deps>/atlas.config`; if `--deps` or `--confdir` is in
   use, inspect that configured location.
3. Choose the Atlas command.
   Use `init`, `use`, `install`, `update`, `link`, `pin`, `rep`, or `env` according to the task.
   Run commands from the project root unless `--project=path` is intentional.
4. Check policy before changing dependencies.
   Read resolver, overrides, plugins, feature needs, lockfile state, and existing Nimble requirements.
5. Run the smallest Atlas operation.
   Use filters for targeted updates and `--noexec` when arbitrary build actions should not run.
6. Verify generated state.
   Inspect `<deps>/atlas.config`, `project.nimble`, `nim.cfg`, and `atlas.lock` as applicable.
   Compile or test the smallest Nim target that imports the affected package.
7. Preserve reproducibility.
   If the dependency set must remain stable, run `atlas pin` after successful setup and keep the
   lockfile with the project when that is the repository policy.

## Task Examples

- For a new project that adds a dependency, read `references/start_project.md`.
- For custom dependency directories and overrides, read `references/custom_deps_and_overrides.md`.
- For feature flags, lockfiles, and replay, read `references/features_and_replay.md`.

# Common Mistakes

| Mistake | Why it is wrong |
|---------|-----------------|
| Looking only for root `atlas.config` | Verified `atlas init` writes `deps/atlas.config` by default even though root config is preferred when present. |
| Assuming `atlas init` creates `nim.cfg` | Verified `init` creates Atlas config only; dependency operations are what drive path patching. |
| Editing generated `nim.cfg` paths first | Atlas can regenerate that section; fix config, package metadata, or dependency resolution instead. |
| Enabling plugins without inspection | Plugins are NimScript files and may execute external commands. |

## References

- `references/start_project.md` — Atlas adoption: project setup, dependency addition, and compile flow.
- `references/custom_deps_and_overrides.md` — Custom dependency directories and URL overrides.
- `references/features_and_replay.md` — Optional features and lockfile replay commands.
