---
name: product-readme-examples
description: Use for user-facing README/example rewrites that sell the project; skip maintainer docs and pure API refs unless asked.
---

# Product README + Example Writing Skill

Use this skill to produce user-facing READMEs and examples that make people want
to try the project quickly.

## Trigger Rules

Use this skill when:
- The user asks to create, rewrite, or improve a README.
- The user asks for better examples, clearer onboarding, or stronger positioning.
- The project needs "why this library" messaging, not just API docs.

Do not use this skill when:
- The task is CONTRIBUTING docs, release notes, changelog, or maintainer runbooks.
- The user asks for low-level exhaustive API reference only.
- The user wants internal workspace/agent instructions.

## Core Principles

- Lead with value, not internals.
- Show real usage quickly (copy-paste friendly snippets).
- Keep examples readable and focused on the happy path.
- Keep maintainer details separate and short.
- Prefer concrete, named helpers over abstract descriptions.

## README Structure (Default Order)

1. Title + one-sentence value proposition.
2. "Why try this?" bullets (differentiators vs alternatives).
3. Install section (what to add, how to resolve deps).
4. Quick start (small runnable snippet).
5. One or two high-value workflows (batching, streaming, multimodal, etc.).
6. Optional features (retry, advanced modules) in a separate section.
7. API cheat sheet (short grouped list, not exhaustive wall of symbols).
8. Run examples/tests commands.

## What to Avoid

- Do not start with internal architecture or maintainer constraints.
- Do not include agent-specific notes ("Atlas-managed nim.cfg", local workspace
  rules, CI internals) in the user-facing README.
- Do not fill examples with defensive noise:
  - excessive `doAssert`
  - verbose error branches for every call
  - tutorial-unfriendly guard spam
- Do not hide the main idea inside giant code blocks.

## Example Style Rules

- One example should teach one main concept.
- Keep naming concrete (`cfg`, `params`, `out`, `batch`, `requestId`).
- Prefer helper constructors that read like product language.
- Minimize branching in examples; keep only control flow that demonstrates the
  feature (polling loop, retry loop, etc.).
- Keep output concise (`echo` key fields that matter).
- Avoid throwing/raising in examples unless the example is specifically about
  error handling.

## Copy Guidance

- Use direct language: "why this is better", "what feels different".
- Name differentiators explicitly:
  - control (transport stays with user)
  - ergonomics (clean constructors/accessors)
  - typing/performance (direct object mapping)
- Keep bullet points punchy and concrete.

## Minimal Research Workflow

Before writing:
1. Read the public API surface (`src/*.nim` exports/helpers).
2. Read current examples to match naming and style.
3. Read one or two strong dependency READMEs for tone and structure.
4. Confirm install path is user-accurate (dependency line + resolver command).

Then write:
1. Draft value proposition and differentiators first.
2. Add quick start.
3. Add 1-2 feature examples.
4. Add cheat sheet and run commands.
5. Remove internal-only notes and noisy checks.

## Nim-Specific Install Pattern

When documenting Nim libraries, prefer:

```nim
requires "https://github.com/<org>/<repo>"
```

Then show resolver command(s) users actually run (`atlas install` and/or
`nimble sync`) based on project reality.

## Quality Checklist

- README answers:
  - What is it?
  - Why use it over alternatives?
  - How do I try it in 2 minutes?
- Quick start is runnable and matches current API names.
- Examples are readable and not cluttered with defensive boilerplate.
- No maintainer/agent-only instructions in the main flow.
- Terminology is user-facing and consistent across README/examples.
