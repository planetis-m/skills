---
name: nim-c-bindings
description: Bind C libraries to Nim and make them build reliably across Linux, macOS, and Windows, including headers, types, linking, shared-library loading, and CI/release workflows. Use when wrapping a C dependency, fixing Nim FFI build issues, or setting up cross-platform GitHub Actions for a Nim native library project.
---

# Nim C Bindings & CI

Rules for writing portable Nim-to-C bindings and cross-platform CI/release workflows. Reference workflows and examples live in `references/`.

## Rules

### Binding Fundamentals

1. Use `importc` with `callconv: cdecl` for C APIs unless the library explicitly requires a different calling convention (e.g., `stdcall`).
2. Represent opaque C handles as `type Name = ptr object` types. Use `incompleteStruct` for partial/opaque structs to avoid size/layout mismatches.
3. Use `{.bycopy.}` on structs that Nim must pass by value to C.
4. Declare the C header in the binding when the compiler needs the C definitions for compilation, for example `header: "foo.h"`.
5. Use `{.push callconv: cdecl, header: "foo.h".}` blocks when many declarations share the same convention and header.

### Linking

6. **System libraries**: link with `-l<name>` only. Do not hardcode `-L` paths — the OS toolchain already knows where system libs live.
7. **Local/third-party libraries**: add both `-L<dir>` and `-l<name>` (or `.lib`/`.dll.lib` paths on Windows MSVC).
8. Use repository-relative paths for vendored dependencies, for example `third_party/libfoo`, to keep builds hermetic.

### Runtime Library Resolution

9. **Vendored/local shared libs**: colocate the `.so`/`.dylib`/`.dll` next to the executable. Do not rely on environment variables for discovery.
10. **System-installed libs**: do not copy DLLs/shared libs next to the executable. Rely on the platform's normal system loader configuration. Use environment variables only as temporary overrides.
11. On Linux, add rpath `$ORIGIN` only when loading colocated shared libs. From the shell, pass `--passL:"-Wl,-rpath,\$ORIGIN"`. In Nim source, use `{.passL: "-Wl,-rpath,\\$ORIGIN".}`.
12. Do not use build-tree-only rpaths or absolute paths to non-system shared libraries.

### Platform Rules

| Platform | Toolchain | Deps | Link flags | Runtime |
|----------|-----------|------|------------|---------|
| Linux | System GCC/Clang | apt | `-l<name>` or `-L<dir> -l<name>` | Colocate local `.so`; rpath `$ORIGIN` if needed |
| macOS | Apple Clang | Homebrew | `staticExec("brew --prefix")` for `-I`/`-L` | Colocate local `.dylib` |
| Windows | MSVC (`--cc:vcc`) | vcpkg only | `.lib`/`.dll.lib` full paths | Colocate `.dll` next to `.exe` |

13. On macOS, resolve include/link paths via `staticExec("brew --prefix <formula>")`.
14. On Windows, use MSVC via `--cc:vcc`. Use vcpkg only — avoid Chocolatey and MSYS2. Never mix toolchains.
15. On Windows, do not rely on implicit `-l<name>` for MSVC. Use explicit `.lib` or `.dll.lib` paths.
16. On Windows CI, export `VCPKG_ROOT` to the installed triplet root and prepend its `bin` to `PATH`.

### CI & Release

17. CI is the authoritative spec for supported platforms, toolchains, and flags. Local workflows must be compatible with CI.
18. Keep test builds simple: compile, then run, with minimal environment mutation.
19. Align the local toolchain with CI (e.g., MSVC + vcpkg `x64-windows-release` with `--cc:vcc`).
20. Use the reference workflows as starting points — `references/ci.yml` for validation, `references/release.yml` for tagged releases.

## Workflow

1. **Identify the C API.** Determine calling convention, opaque vs value types, and ownership.
2. **Write bindings.** Use `importc`, correct calling convention, `incompleteStruct` for opaque types, `bycopy` for value types. Add `header` pragma.
3. **Set up linking.** System libs: `-l` only. Local libs: `-L` + `-l` with repo-relative paths. Windows: explicit `.lib` paths.
4. **Handle runtime.** Colocate local shared libs. For system-installed libs, rely on the normal loader search path. Add rpath `$ORIGIN` on Linux only for colocated local libs.
5. **Add CI.** Copy `references/ci.yml`, adapt placeholders (`<package>`, `<src/main.nim>`, dependency lists).
6. **Add release.** Copy `references/release.yml`, adapt placeholders, configure draft releases.
7. **Test locally, then push.** Verify the build works locally with the same flags CI uses.

## Common Mistakes

| Mistake | Why it's wrong |
|---------|----------------|
| Hardcoding `-L` paths for system libraries | OS toolchain already knows where they are; breaks portability |
| Mixing MSVC + MSYS2/MinGW on Windows | Incompatible ABIs, linker errors, runtime crashes |
| Using implicit `-l<name>` with MSVC | MSVC doesn't resolve libs the same way GCC does; use explicit `.lib` paths |
| Relying on env vars for vendored shared libs | Fragile across machines; colocate instead |
| Build-tree-only rpaths | Breaks when the binary moves; use `$ORIGIN` for colocated libs |
| Guessing Windows dependency paths | Non-deterministic; use vcpkg with known install roots |

## References

- `references/ci.yml` — Cross-platform CI workflow (Linux, macOS, Windows) with Nim, Atlas, and vcpkg
- `references/release.yml` — Tagged release workflow producing per-platform archives and a draft GitHub Release

## Changelog

- 2026-04-09: Initial verified skill created from the original `nim-c-bindings` guidance.
- 2026-04-09: Refined the linker/runtime guidance for system-installed libs and Linux `$ORIGIN` rpath usage.
