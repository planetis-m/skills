# Constructor and Conversion Surface

Default constructor surface for a new library type.

```nim
type
  Catalog = object
    items: seq[string]

proc initCatalog(initialSize = 8): Catalog =
  Catalog(items: newSeqOfCap[string](initialSize))

proc toCatalog(items: openArray[string]): Catalog =
  result = initCatalog(items.len)
  for item in items:
    result.items.add item

proc toCatalog(item: string): Catalog =
  result = initCatalog(1)
  result.items.add item
```

Optional compatibility wrapper when shared identity is part of the contract:

```nim
type
  CatalogRef = ref object
    items: seq[string]

proc newCatalog(initialSize = 8): CatalogRef =
  new(result)
  result[] = initCatalog(initialSize)
```

## Key points

- `initX()` is the primary constructor for value types.
- `toX()` is the primary conversion surface. Overload the same name on common inputs.
- Default parameters keep the simple call path simple.
- If a ref wrapper is necessary, `newX()` should use `new(result)` and may assign
  `result[] = initX(...)` to reuse the value-type initialization logic.
