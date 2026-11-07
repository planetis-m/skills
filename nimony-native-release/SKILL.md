---
name: nimony-native-release
description: Build release binaries of a Nimony project with the native backend (`nimony n`) on GitHub Actions, publish them as GitHub Release assets on `v*` tags, and ship one-line install scripts (`curl | sh`, `irm | iex`) with checksum verification. Use when setting up release CI for a Nimony CLI, pinning nimony in CI, or debugging a `nimony n` build that links or runs differently from `nimony c`.
---

# Nimony Native Release

## Rules

### The Native Backend

- `nimony n` compiles Leng through nativenif's `arkham` (code generator) and
  `nifasm` (assembler and linker). No C compiler or system linker is involved.
- Targets: `linux/amd64`, `linux/arm64`, `macosx/arm64`, `windows/amd64`. There
  is no macOS x86_64 or Windows ARM64 backend. Do not publish or advertise
  those targets.
- Output per OS: a static, libc-free ELF on Linux; a Mach-O linked only against
  libSystem on macOS; a PE importing only system DLLs on Windows. A release
  archive needs no runtime libraries. Assets embedded with `slurp` need no
  extra files either.
- Build on a native runner per target. Mach-O output needs `codesign` on a
  macOS host, and each runner can smoke-test its own binary.

### Libc-Free Constraints

- A libc-free executable cannot bind external C symbols. A build that reaches
  one fails in nifasm with
  ``nifasm: `<sym>` is an external symbol, which a static executable cannot bind``.
- `putEnv`/`delEnv` on POSIX bind `setenv`/`unsetenv`, so they fail this way.
  To give a child process extra variables, build a `StringTableRef` from
  `envPairs()` plus the overrides and pass it as `startProcess(env = ...)`.
  Use `modeCaseInsensitive` on Windows.
- `-d:useLibc` (Linux only) links through the system linker instead. Treat it
  as a different backend: run the project's tests under it before relying on
  it, and prefer removing the libc dependency.
- Test programs that mutate the environment cannot link natively either. Run
  the test suite with `nimony c`, and smoke-test the `nimony n` binary in the
  release job.

### Building the Toolchain in CI

- Pin only nimony: clone `nim-lang/nimony` into `nimony/` at an exact commit
  with `git init`, `git fetch --depth 1 <url> <sha>`, then
  `git checkout FETCH_HEAD`.
- Do not clone nativenif yourself. hastur clones it into `../nativenif` at
  the commit nimony's `src/nativenif.commit` pins, and builds `arkham`/`nifasm`
  from it. The nimony commit therefore fixes the whole toolchain.
- Build: `nim c -r src/hastur/hastur --release build all` from `nimony/`. It needs Nim devel (`alaviss/setup-nim` with `version: devel`).
  Copy current devel `compiler/` and `lib/packages/docutils/` over the
  nightly, because nifler compiles Nim's parser against the host's compiler
  sources.
- On Windows, building the toolchain needs MinGW (nimony's CI uses a winlibs
  GCC+LLVM bundle). `nimony n` itself needs no C compiler.
- `nimony n` uses only `nimony/bin` and `nimony/lib`. Cache `nimony/bin` keyed
  on OS, arch and the nimony commit, and skip Nim setup and the toolchain build on
  a cache hit.
- Before writing CI, build the project with `nimony c` at the pinned nimony
  commit. If the stdlib APIs the project uses are missing at that commit, the
  native build cannot succeed either.

### Packaging

- Name assets without the version, e.g. `<app>-<os>-<arch>.tar.gz` and
  `<app>-windows-amd64.zip`, so that
  `releases/latest/download/<asset>` is a stable URL.
- Use `.tar.gz` for Linux and macOS, `.zip` for Windows. Put the binary at the
  archive root.
- macOS: run `codesign -s - -f <bin>` before the smoke test, because nifasm
  reserves space for a signature but does not sign, and arm64 macOS refuses
  unsigned code. Set `COPYFILE_DISABLE=1` for `tar`.
- Run `git config --global core.autocrlf false` before the first checkout.
  Otherwise, Windows checkouts rewrite slurped assets with CRLF.
- Generate one `SHA256SUMS` in the release job over all archives.

### Install Scripts

- Keep `install.sh` and `install.ps1` in the repository and attach them to each
  release. Then `releases/latest/download/install.sh` always matches that
  release's assets, with no Pages or external hosting.
- `install.sh` must be POSIX `sh`, because it is piped to `sh`, which is
  `dash` on Ubuntu. Map `uname -s`/`uname -m`. On macOS, use
  `sysctl hw.optional.arm64`, because a Rosetta shell reports `x86_64`.
- Download with `curl` or `wget`, and verify with `sha256sum` or
  `shasum -a 256` against `SHA256SUMS`. Install into `~/.local/bin` through a
  temporary name plus `mv`. Run the binary once. Print a PATH hint instead of
  editing shell rc files.
- `install.ps1` must run on Windows PowerShell 5.1: force TLS 1.2, and use
  `Invoke-WebRequest -UseBasicParsing`, `Get-FileHash` and `Expand-Archive`.
  Install into `%LOCALAPPDATA%\Programs\<app>` and add it to the user PATH. On
  ARM64, the x64 build runs only under emulation: warn rather than claim
  support.
- Support `<APP>_VERSION` (a tag, default `latest`) and `<APP>_INSTALL_DIR`.
- Fail with a clear message on an unsupported OS or arch, a download failure,
  a missing checksum entry or a checksum mismatch.

## Workflow

1. **Check the pin.** At the chosen nimony commit, build with `nimony c`, then
   with `nimony n`. Fix libc-bound calls (see Libc-Free Constraints) and rerun
   the tests with `nimony c`.
2. **Add the workflow.** Copy `references/release.yml`. Fill in `<app>`,
   `<src/main.nim>` and the nimony commit.
3. **Add the installers.** Copy `references/install.sh` and
   `references/install.ps1`. Fill in `<owner>/<repo>`, `<app>` and `<APP>`.
4. **Test the installer locally.** Point a copy of `install.sh` at a
   `file://` directory holding an archive and `SHA256SUMS`. Check that it
   installs, and that an altered archive fails with a checksum mismatch.
5. **Document.** Put the two one-line commands and the supported targets in
   the README.
6. **Dry run.** Run the workflow with `workflow_dispatch`, then push a `v*`
   tag. The `install-test` job installs the published release on every runner.

## Common Mistakes

| Mistake | Why it's wrong |
|---------|----------------|
| Pinning or cloning nativenif separately | hastur already fetches the nativenif commit nimony pins; a second pin can drift from it |
| Calling `putEnv` in a native binary | Binds `setenv`, which a libc-free executable cannot link |
| Switching to `-d:useLibc` without rerunning tests | It is a different link path; behavior can differ |
| Shipping an unsigned macOS binary | arm64 macOS kills it on launch |
| Cross-compiling every target from one Linux host | Mach-O needs `codesign`; native runners also smoke-test |
| Versioned asset names | Breaks the stable `releases/latest/download/` URLs |
| Bash-only syntax in `install.sh` | `curl \| sh` runs `dash` on Ubuntu |
| Listing macOS x86_64 or Windows ARM64 as supported | nativenif has no backend for them |

## References

- `references/release.yml`: native-runner build matrix, toolchain cache,
  packaging, release and install test.
- `references/install.sh`: Linux/macOS installer.
- `references/install.ps1`: Windows installer.
