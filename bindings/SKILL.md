---
name: bindings
description: Operational rules for reliable Nim to C bindings across Linux, macOS, and Windows.
---

# Nim ↔ C Bindings — Operational Rules

## Scope
- This is a prescriptive rulebook for building Nim bindings to C libraries across Linux, macOS, and Windows.
- Use it as a checklist for reliable CI builds and portable runtime behavior.

## Core Workflow (Binding + Build)
- Use `importc` with `callconv: cdecl` for C APIs unless the library explicitly uses a different calling convention.
- Represent opaque C handles as `distinct pointer` types in Nim.
- For partial or opaque C structs, use `incompleteStruct` to avoid size/layout mismatches.
- For value structs that Nim must pass by value, use `bycopy`.
- Declare the C header in the binding (`header: "<...>"`) when the compiler needs definitions.

## System vs Local/Third-Party Libraries
- System libraries:
  - Link with `-l<name>` only; do not hardcode `-L` paths when the OS toolchain can locate them.
- Local/third-party libraries (vendored or downloaded):
  - Add `-L<dir>` plus `-l<name>` (or the platform import library on Windows).
  - Use repository-relative paths (e.g., `third_party/...`) to keep builds hermetic.

## Runtime and Portability Assumptions
- For local/third-party libs (e.g., PDFium), colocate the shared library next to the executable at runtime.
- For system-installed libs (e.g., curl), do not copy DLLs; rely on environment variables (`LD_LIBRARY_PATH`, `DYLD_LIBRARY_PATH`, `PATH`) for runtime resolution.
- On Linux, add rpath only for tests/apps that load colocated shared libs:
  - `--passL:"-Wl,-rpath,\\$ORIGIN"`

## CI-Driven Constraints (Generalized)
- Treat CI as the authoritative spec for supported platforms, toolchains, and flags.
- Any local workflow not compatible with CI is disallowed.
- Keep test builds simple and reproducible: compile, then run, with minimal environment mutation.
- Ensure the CI toolchain and the dependency toolchain match (e.g., MSVC + vcpkg `x64-windows-release` with `--cc:vcc`).

## Platform-Specific Rules

### Linux
- Toolchain: system GCC/Clang on the CI image.
- System deps: install via the OS package manager.
- Link flags (typical):
  - `--passL:"-l<systemlib>"`
  - `--passL:"-L<local_lib_dir> -l<locallib>"`
- Runtime: copy local shared libraries next to the executable when used.
- Incompatible: rpath pointing to build-tree-only locations.

### macOS
- Toolchain: Apple Clang on the CI image.
- System deps: install via the platform’s package manager (e.g., Homebrew).
- Include/link flags (typical):
  - `--passC:"-I" & staticExec("brew --prefix <formula>") & "/include"`
  - `--passL:"-L" & staticExec("brew --prefix <formula>") & "/lib"`
  - `--passL:"-l<systemlib>"`
  - `--passL:"-L<local_lib_dir> -l<locallib>"`
- Runtime: copy local shared libraries next to the executable.
- Incompatible: relying on `DYLD_LIBRARY_PATH` or full-path linking to a `.dylib`.

### Windows
- Toolchain: MSVC via `--cc:vcc` as used by Nim on CI.
- System deps: prefer `vcpkg` only. Avoid Chocolatey. Never use MSYS2.
- For vcpkg on CI: export `VCPKG_ROOT` to the installed triplet root and add its `bin` directory to `PATH` for runtime DLL resolution (see `.github/workflows/ci.yml` and `src/config.nims`).
- Include/link flags (typical):
  - `--passC:"-I<dep_root>/include"`
  - `--passL:"-L<dep_root>/lib"`
  - `--passL:"<dep_root>/lib/<name>.lib"` (MSVC import libs from vcpkg)
  - `--passL:"<local_lib_dir>/<name>.dll.lib"` (for DLL import libraries)
- Runtime: copy required `.dll` files next to the executable.
- Incompatible: guessing dependency paths.

#### Windows CI Do/Don’t (from recent churn in `ci.yml`)
- Do: keep Windows steps minimal and deterministic (vcpkg install, set `VCPKG_ROOT`, prepend `VCPKG_ROOT\\bin` to `PATH`, copy runtime DLLs).
- Do: align Nim config with CI (MSVC + vcpkg triplet `x64-windows-release`).
- Don’t: mix toolchains (MSVC + MSYS2/MinGW) or switch package managers midstream.
- Don’t: rely on implicit `-l<name>` for MSVC; use `.lib`/`.dll.lib` paths instead.

## How to Locate Include/Lib Directories
- Use explicit, deterministic paths:
  - Linux: package manager default locations (`/usr/include`, `/usr/lib`) via toolchain search.
  - macOS: resolve prefixes via `staticExec("brew --prefix <formula>")`.
- Windows: use the known install root from the package manager (avoid probing `PATH`).
- For vendored libs, always prefer repository-relative paths under `third_party/`.

## Anti-Patterns
- Relying on environment variables for runtime discovery of vendored/local shared libs; colocate them instead.
- Using build-tree-only rpaths or absolute paths to non-system shared libraries.
