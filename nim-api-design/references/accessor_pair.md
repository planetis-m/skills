# Accessor Pair Pattern

Pair `lent` and `var` accessors only when callers need both borrowed reads and unrestricted mutation.

```nim
type
  PackageMeta* = object
    version*: string
    tags*: seq[string]

  PackageCatalog* = object
    ids: seq[string]
    entries: seq[PackageMeta]

proc raiseAccessorError(msg: string) {.noinline, noreturn.} =
  raise newException(KeyError, msg)

proc findIndex(catalog: PackageCatalog; id: string): int {.inline.} =
  for i, existing in catalog.ids:
    if existing == id:
      return i
  raiseAccessorError("unknown package id: " & id)

proc meta*(catalog: PackageCatalog; id: string): lent PackageMeta
    {.inline.} =
  result = catalog.entries[findIndex(catalog, id)]

proc tags*(catalog: PackageCatalog; id: string): lent seq[string]
    {.inline.} =
  result = catalog.entries[findIndex(catalog, id)].tags

proc tags*(catalog: var PackageCatalog; id: string): var seq[string]
    {.inline.} =
  result = catalog.entries[findIndex(catalog, id)].tags
```

## Key points

- Use one private `{.noinline, noreturn.}` helper for missing items.
- Return `lent` for reads and `var` only for values callers may freely edit; keep scalar fields read-only.
- Return borrows directly from owner storage, without temporary locals.
