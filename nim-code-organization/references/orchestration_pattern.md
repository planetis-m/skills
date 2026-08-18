Use explicit inventory state when reservation operations must preserve stock across calls.

```nim
type
  InventoryState = object
    onHand: int
    reserved: int

func initInventory(onHand: int): InventoryState =
  InventoryState(onHand: max(onHand, 0))

func available(state: InventoryState): int =
  state.onHand - state.reserved

proc ensure(state: InventoryState) =
  assert state.reserved >= 0 and state.reserved <= state.onHand

proc restock(state: var InventoryState; quantity: int) =
  if quantity > 0:
    inc state.onHand, quantity
    ensure state

proc reserve(state: var InventoryState; quantity: int): bool =
  if quantity > 0 and quantity <= state.available:
    inc state.reserved, quantity
    ensure state
    result = true

proc cancelReservation(state: var InventoryState; quantity: int): bool =
  if quantity > 0 and quantity <= state.reserved:
    dec state.reserved, quantity
    ensure state
    result = true

proc shipReserved(state: var InventoryState; quantity: int): bool =
  if quantity > 0 and quantity <= state.reserved:
    dec state.reserved, quantity
    dec state.onHand, quantity
    ensure state
    result = true

proc countNonEmpty(names: openArray[string]): int =
  for name in names:
    if name.len > 0:
      inc result
```

## Key points

- The operations preserve `0 <= reserved <= onHand` across calls.
- `countNonEmpty` is self-contained, so its result is sufficient local state.
