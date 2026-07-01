# Constructor and Conversion Surface

Use `initX` for value construction, `toX` for conversion, and `newX` only for a required reference form.

```nim
type
  Catalog* = object
    items: seq[string]

proc initCatalog*(initialSize = 8): Catalog =
  Catalog(items: newSeqOfCap[string](initialSize))

proc toCatalog*(items: openArray[string]): Catalog =
  result = initCatalog(items.len)
  for item in items:
    result.items.add item

proc toCatalog*(item: string): Catalog =
  result = initCatalog(1)
  result.items.add item
```

Optional compatibility wrapper when shared identity is part of the contract:

```nim
type
  CatalogRef* = ref Catalog

proc newCatalog*(initialSize = 8): CatalogRef =
  new(result)
  result[] = initCatalog(initialSize)
```

## Key points

- Use `initX()` for value types and overload `toX()` for common input forms.
- Keep the simple constructor call free of tuning arguments by giving them defaults.
- Add `newX()` only when shared identity is part of the contract; reuse `initX()` for initialization.
