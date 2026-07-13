GitHub Actions CI for a Nim project: cross-platform test matrix and an AddressSanitizer job on Linux.

## `.github/workflows/ci.yml`

```yaml
name: CI

on:
  push:
    branches: [ master ]
  pull_request:
    branches: [ master ]
  workflow_dispatch:

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
        uses: actions/checkout@v7

      - name: Install Nim
        uses: jiro4989/setup-nim-action@v2
        with:
          nim-version: stable
          repo-token: ${{ github.token }}

      - name: Install Atlas
        run: nimble install -y "https://github.com/nim-lang/atlas@#head"

      - name: Install Nim dependencies
        run: atlas install

      - name: Run tests
        run: nim c ${{ matrix.build }} -r tests/tester.nim

  sanitizer:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout
        uses: actions/checkout@v7

      - name: Install Nim
        uses: jiro4989/setup-nim-action@v2
        with:
          nim-version: stable
          repo-token: ${{ github.token }}

      - name: Run tests with AddressSanitizer
        run: nim c -d:addressSanitizer -r tests/tester.nim
```

When to use:

- Copy this workflow when setting up CI for a Nim project using the `tests/tester.nim` runner.
- Replace `stable` with a pinned Nim version (e.g. `2.3.1`) when reproducibility matters.
- Remove the `sanitizer` job if the project does not use unsafe constructs.
