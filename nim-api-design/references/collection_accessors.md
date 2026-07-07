# One Coherent Container Surface

Use one lookup name per result and expose mutation only for values callers may freely edit.

```nim
type
  PackageId* = distinct string

  PackageMeta* = object
    title*: string
    version*: string
    tags*: seq[string]
    downloads*: int

  PackageCatalog* = object
    ids: seq[PackageId]
    entries: seq[PackageMeta]

proc `==`*(a, b: PackageId): bool {.borrow.}
proc `$`*(id: PackageId): string {.borrow.}
proc hash*(id: PackageId): Hash {.borrow.}

proc raiseMissingPackage(id: PackageId) {.noinline, noreturn.} =
  raise newException(KeyError, "unknown package: " & $id)

proc initPackageCatalog*(initialSize = 8): PackageCatalog =
  PackageCatalog(
    ids: newSeqOfCap[PackageId](initialSize),
    entries: newSeqOfCap[PackageMeta](initialSize)
  )

proc toPackageCatalog*(pairs: openArray[(PackageId, PackageMeta)]): PackageCatalog =
  result = initPackageCatalog(pairs.len)
  for (id, meta) in pairs:
    result.ids.add id
    result.entries.add meta

proc findIndex(catalog: PackageCatalog; id: PackageId): int {.inline.} =
  for i, existing in catalog.ids:
    if existing == id:
      return i
  raiseMissingPackage(id)

proc len*(catalog: PackageCatalog): int {.inline.} =
  catalog.ids.len

proc meta*(catalog: PackageCatalog; id: PackageId): lent PackageMeta {.inline.} =
  result = catalog.entries[findIndex(catalog, id)]

proc tags*(catalog: PackageCatalog; id: PackageId): lent seq[string] {.inline.} =
  result = catalog.entries[findIndex(catalog, id)].tags

proc tags*(catalog: var PackageCatalog; id: PackageId): var seq[string] {.inline.} =
  result = catalog.entries[findIndex(catalog, id)].tags

proc downloads*(catalog: PackageCatalog; id: PackageId): int {.inline.} =
  catalog.entries[findIndex(catalog, id)].downloads
```

## Key points

- Keep one representation and one constructor surface: `PackageCatalog`, `initPackageCatalog`, and `toPackageCatalog`.
- Route missing ids through one private error helper.
- Return `tags` as `lent` and `var` because callers may freely edit it; return scalar `downloads` by value.
