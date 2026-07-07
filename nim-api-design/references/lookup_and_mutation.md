Expose one required lookup, explicit membership, free mutation only for
unconstrained values, and mutation procs for invariant-bearing fields.

```nim
import std/hashes

type
  Sku* = distinct string

  Product* = object
    productName: string
    productLabels: seq[string]
    productStock: int

  Inventory* = object
    ids: seq[Sku]
    products: seq[Product]

proc `==`*(a, b: Sku): bool {.borrow.}
proc `$`*(sku: Sku): string {.borrow.}
proc hash*(sku: Sku): Hash {.borrow.}

proc initProduct*(name: string; labels: openArray[string];
    stock: Natural): Product =
  result = Product(productName: name, productStock: stock)
  for label in labels:
    result.productLabels.add label

func name*(product: Product): string =
  product.productName

func stock*(product: Product): int =
  product.productStock

proc labels*(product: Product): lent seq[string] =
  product.productLabels

proc raiseMissing(sku: Sku) {.noinline, noreturn.} =
  raise newException(KeyError, "unknown sku: " & $sku)

func find*(inventory: Inventory; sku: Sku): int =
  for idx, existing in inventory.ids:
    if existing == sku:
      return idx
  result = -1

func contains*(inventory: Inventory; sku: Sku): bool =
  inventory.find(sku) >= 0

proc getOrDefault*(inventory: Inventory; sku: Sku;
    default: Product): Product =
  let idx = inventory.find(sku)
  if idx >= 0:
    inventory.products[idx]
  else:
    default

proc add*(inventory: var Inventory; sku: Sku; product: sink Product) =
  if inventory.contains(sku):
    raise newException(ValueError, "duplicate sku")
  inventory.ids.add sku
  inventory.products.add product

proc del*(inventory: var Inventory; sku: Sku) =
  let idx = inventory.find(sku)
  if idx >= 0:
    inventory.ids.delete idx
    inventory.products.delete idx

proc clear*(inventory: var Inventory) =
  inventory.ids.setLen 0
  inventory.products.setLen 0

proc product*(inventory: Inventory; sku: Sku): lent Product =
  let idx = inventory.find(sku)
  if idx < 0:
    raiseMissing(sku)
  result = inventory.products[idx]

proc labels*(inventory: var Inventory; sku: Sku): var seq[string] =
  let idx = inventory.find(sku)
  if idx < 0:
    raiseMissing(sku)
  result = inventory.products[idx].productLabels

proc setStock*(inventory: var Inventory; sku: Sku; stock: Natural) =
  let idx = inventory.find(sku)
  if idx < 0:
    raiseMissing(sku)
  inventory.products[idx].productStock = stock

iterator items*(inventory: Inventory): lent Product =
  for product in inventory.products:
    yield product

iterator pairs*(inventory: Inventory): (Sku, lent Product) =
  for idx, sku in inventory.ids:
    yield (sku, inventory.products[idx])

let hammer = Sku("hammer")
var inventory: Inventory
inventory.add hammer, initProduct("Hammer", ["tool"], 4)
doAssert inventory.find(hammer) == 0
doAssert inventory.contains(hammer)
doAssert inventory.product(hammer).name == "Hammer"
doAssert inventory.getOrDefault(Sku("missing"),
  initProduct("Fallback", [], 0)).name == "Fallback"
inventory.labels(hammer).add "steel"
inventory.setStock(hammer, 6)
doAssert inventory.product(hammer).labels.len == 2
doAssert inventory.product(hammer).stock == 6
for sku, product in inventory.pairs:
  doAssert sku == hammer
  doAssert product.name == "Hammer"
inventory.del hammer
inventory.del hammer
doAssert inventory.find(hammer) == -1
inventory.clear()
doAssert inventory.find(hammer) == -1
```

## Key points

- `contains` is the explicit optional path; `product` is the required lookup
  and raises one specific exception.
- `find` returns a position, while `contains` returns boolean membership.
- `getOrDefault` is the explicit fallback path.
- Collection mutation uses `add`, keyed `del` as a no-op for absent keys, and
  `clear`.
- `hash` matches `==`, so `Sku` can be used as a table or set key.
- Collection iteration uses `items` and `pairs`.
- The borrowed result is returned directly from owner storage.
- Labels are freely editable, so the inventory exposes a deliberate mutable
  view for them.
- Stock remains private and changes through a proc because its public contract
  constrains the value.
