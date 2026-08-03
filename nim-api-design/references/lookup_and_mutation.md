Expose one required lookup, explicit membership, free mutation only for
unconstrained values, and mutation procs for invariant-bearing fields.

```nim
import std/hashes

type
  Sku* = distinct string

  Product* = object
    name: string
    labels: seq[string]
    stock: int

  Inventory* = object
    ids: seq[Sku]
    products: seq[Product]

proc `==`*(a, b: Sku): bool {.borrow.}
proc `$`*(sku: Sku): string {.borrow.}
proc hash*(sku: Sku): Hash {.borrow.}

proc initProduct*(name: string; labels: openArray[string];
    stock: Natural): Product =
  result = Product(name: name, stock: stock)
  for label in labels:
    result.labels.add label

func name*(p: Product): string {.inline.} =
  p.name

func stock*(p: Product): int {.inline.} =
  p.stock

proc labels*(p: Product): lent seq[string] {.inline.} =
  p.labels

proc raiseMissing(sku: Sku) {.noinline, noreturn.} =
  raise newException(KeyError, "unknown sku: " & $sku)

func find*(inv: Inventory; sku: Sku): int =
  for idx, existing in inv.ids:
    if existing == sku:
      return idx
  result = -1

func contains*(inv: Inventory; sku: Sku): bool {.inline.} =
  inv.find(sku) >= 0

proc getOrDefault*(inv: Inventory; sku: Sku;
    default: Product): Product =
  let idx = inv.find(sku)
  if idx >= 0:
    result = inv.products[idx]
  else:
    result = default

proc add*(inv: var Inventory; sku: Sku; p: sink Product) =
  if inv.contains(sku):
    raise newException(ValueError, "duplicate sku")
  inv.ids.add sku
  inv.products.add p

proc del*(inv: var Inventory; sku: Sku) =
  let idx = inv.find(sku)
  if idx >= 0:
    inv.ids.delete idx
    inv.products.delete idx

proc clear*(inv: var Inventory) =
  inv.ids.setLen 0
  inv.products.setLen 0

proc product*(inv: Inventory; sku: Sku): lent Product =
  let idx = inv.find(sku)
  if idx < 0:
    raiseMissing(sku)
  result = inv.products[idx]

proc labels*(inv: var Inventory; sku: Sku): var seq[string] =
  let idx = inv.find(sku)
  if idx < 0:
    raiseMissing(sku)
  result = inv.products[idx].labels

proc setStock*(inv: var Inventory; sku: Sku; stock: Natural) =
  let idx = inv.find(sku)
  if idx < 0:
    raiseMissing(sku)
  inv.products[idx].stock = stock

iterator items*(inv: Inventory): lent Product =
  for p in inv.products:
    yield p

iterator pairs*(inv: Inventory): (Sku, lent Product) =
  for idx, sku in inv.ids:
    yield (sku, inv.products[idx])
```

## Key points

- `contains` is the explicit optional path; `product` is the required lookup
  and raises one specific exception.
- `find` returns a position, while `contains` returns boolean membership.
- `getOrDefault` is the explicit fallback path.
- `hash` matches `==`, so `Sku` can be used as a table or set key.
- Collection iteration uses `items` and `pairs`.
- The borrowed result is returned directly from owner storage.
- Labels are freely editable, so the inventory exposes a deliberate mutable
  view for them.
- Stock remains private and changes through a proc because its public contract
  constrains the value.
