Expose one required lookup, explicit membership, free mutation only for
unconstrained values, and mutation procs for invariant-bearing fields.

```nim
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

func findIndex(inventory: Inventory; sku: Sku): int =
  for idx, existing in inventory.ids:
    if existing == sku:
      return idx
  result = -1

func contains*(inventory: Inventory; sku: Sku): bool =
  inventory.findIndex(sku) >= 0

proc add*(inventory: var Inventory; sku: Sku; product: sink Product) =
  if inventory.contains(sku):
    raise newException(ValueError, "duplicate sku")
  inventory.ids.add sku
  inventory.products.add product

proc product*(inventory: Inventory; sku: Sku): lent Product =
  let idx = inventory.findIndex(sku)
  if idx < 0:
    raiseMissing(sku)
  result = inventory.products[idx]

proc labels*(inventory: var Inventory; sku: Sku): var seq[string] =
  let idx = inventory.findIndex(sku)
  if idx < 0:
    raiseMissing(sku)
  result = inventory.products[idx].productLabels

proc setStock*(inventory: var Inventory; sku: Sku; stock: Natural) =
  let idx = inventory.findIndex(sku)
  if idx < 0:
    raiseMissing(sku)
  inventory.products[idx].productStock = stock

let hammer = Sku("hammer")
var inventory: Inventory
inventory.add hammer, initProduct("Hammer", ["tool"], 4)
doAssert inventory.contains(hammer)
doAssert inventory.product(hammer).name == "Hammer"
inventory.labels(hammer).add "steel"
inventory.setStock(hammer, 6)
doAssert inventory.product(hammer).labels.len == 2
doAssert inventory.product(hammer).stock == 6
```

## Key points

- `contains` is the explicit optional path; `product` is the required lookup
  and raises one specific exception.
- The borrowed result is returned directly from owner storage.
- Labels are freely editable, so a `var seq[string]` inventory accessor is
  appropriate.
- Stock remains private and changes through a proc because its public contract
  constrains the value.
