GitHub Actions CI workflow for a Nim project. Runs the auto-discovering test runner across Linux, macOS, and Windows in debug, release, and danger configurations. Includes an optional AddressSanitizer job on Linux.

Adapted from verified patterns in production Nim projects using `jiro4989/setup-nim-action@v2` and `actions/checkout@v6`.

## `.github/workflows/ci.yml`

```yaml
name: CI

on:
  push:
  pull_request:

jobs:
  test:
    strategy:
      fail-fast: false
      matrix:
        os: [ubuntu-latest, macos-latest, windows-latest]
        build: ["", "-d:release", "-d:danger"]
    runs-on: ${{ matrix.os }}
    steps:
      - name: Checkout
        uses: actions/checkout@v6

      - name: Install Nim
        uses: jiro4989/setup-nim-action@v2
        with:
          nim-version: stable
          repo-token: ${{ github.token }}

      - name: Run tests
        run: nim c ${{ matrix.build }} -r tests/tester.nim

  sanitizer:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout
        uses: actions/checkout@v6

      - name: Install Nim
        uses: jiro4989/setup-nim-action@v2
        with:
          nim-version: stable
          repo-token: ${{ github.token }}

      - name: Run tests with AddressSanitizer
        run: |
          nim c \
            --passC:"-fsanitize=address -fno-omit-frame-pointer" \
            --passL:"-fsanitize=address -fno-omit-frame-pointer" \
            -g -d:noSignalHandler -d:useMalloc \
            -r tests/tester.nim
```

## How it works

- **Matrix strategy:** 3 OS × 3 build modes = 9 parallel jobs. `fail-fast: false` ensures all combinations run even if one fails.
- **Runner selection:** `ubuntu-latest` (x86_64), `macos-latest` (ARM64), `windows-latest` (x86_64). These are free for public repositories.
- **Sanitizer job:** Separate single job on Linux with gcc's AddressSanitizer. Not run on macOS or Windows due to toolchain differences.
- **Test runner:** Each job runs `tests/tester.nim`, which auto-discovers and executes all `tests/t*.nim` files.

## Customization

- Add `nimble install <dep>` steps before "Run tests" if the project has dependencies.
- Add a `config.nims` at project root for project-wide defaults (allocator selection, memory manager).
- For Windows-specific compiler flags (e.g., MSVC), add a conditional step or use `tests/config.nims` with `when defined(windows)` blocks.
- To install system libraries, add OS-specific steps:
  - Linux: `sudo apt-get install -y <packages>`
  - macOS: `brew install <packages>`
  - Windows: use vcpkg or prebuilt binaries

Key points:

- The `jiro4989/setup-nim-action@v2` action installs Nim stable and adds it to PATH. `repo-token` avoids rate limits.
- The `build` matrix value is interpolated directly into the `nim c` command. Empty string means debug (default).
- The sanitizer job is separate so it does not slow down the main matrix. Remove it if the project does not use unsafe constructs.
