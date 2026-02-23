---
name: update-api-docs
description: Generate markdown API docs for Nim source files using jsondoc.
---

# Skill: Update API Documentation

Generates markdown API documentation for all Nim source files in the project.

## Steps

1. **Find all Nim source files**
   ```bash
   glob **/*.nim
   ```

2. **Create/update docs folder**
   ```bash
   mkdir -p docs/
   ```

3. **Generate JSON docs for each source file** (skip test files)
   ```bash
   nim jsondoc --out:docs/module_name.json src/path/to/module.nim
   ```

4. **Read JSON output** and convert to markdown with:
   - Module name and description
   - Type definitions with code blocks
   - Procedures with signatures, parameters, return types
   - Error handling notes
   - Usage examples where applicable

5. **Clean up JSON files**
   ```bash
   rm docs/*.json
   ```

## Output

Markdown files in `docs/` folder:
- `docs/module_name.md` for each module with exported API
- `docs/README.md` as index with quick start guide

## Notes

- Skip `app.nim` (main entry point, no exported API)
- Skip test files (`tests/` directory)
- High-level wrappers get `.md` docs
- Low-level bindings can be documented in `.json` format then deleted
