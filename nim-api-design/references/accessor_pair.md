# Accessor Pair Pattern

Minimal example showing one read accessor, one mutable accessor, and one shared
error helper.

```nim
type
  PackageMeta = object
    version: string
    tags: seq[string]

  PackageCatalog = object
    ids: seq[string]
    entries: seq[PackageMeta]

proc raiseAccessorError(msg: string) {.noinline, noreturn.} =
  raise newException(KeyError, msg)

proc findIndex(catalog: PackageCatalog; id: string): int {.inline.} =
  for i, existing in catalog.ids:
    if existing == id:
      return i
  raiseAccessorError("unknown package id: " & id)

proc meta*(catalog: PackageCatalog; id: string): lent PackageMeta {.inline.} =
  result = catalog.entries[findIndex(catalog, id)]

proc tags*(catalog: PackageCatalog; id: string): lent seq[string] {.inline.} =
  result = catalog.entries[findIndex(catalog, id)].tags

proc tags*(catalog: var PackageCatalog; id: string): var seq[string] {.inline.} =
  result = catalog.entries[findIndex(catalog, id)].tags
```

## Key points

- One shared `{.noinline, noreturn.}` helper defines the missing-item failure path.
- Read accessors borrow with `lent`; mutable access is exposed only for the
  `seq[string]` field that callers are expected to edit.
- Accessors return directly from the owner field. No temp locals.
- There is no `var` accessor for scalar fields.
