# Domain Safety with Distinct Types

Use `distinct` when two concepts share a base type but should not be mixed.

## Pattern

```nim
type
  PackageId = distinct string
  UserId = distinct string

proc `==`*(a, b: PackageId): bool {.borrow.}
proc `$`*(id: PackageId): string {.borrow.}

proc `==`*(a, b: UserId): bool {.borrow.}
proc `$`*(id: UserId): string {.borrow.}
```

## What distinct gives you

1. **Compile-time type safety** — cannot pass a `string` where `PackageId` is expected.
2. **No accidental mixing** — `PackageId("a")` and `UserId("a")` stay incompatible.
3. **Borrowed operations** — `{.borrow.}` keeps equality and display usable without
   re-implementing them.

## When to use

- When two concepts share a base type but represent different domains.
- When you want semantic type safety without the runtime cost of wrapper objects.

## When not to use

- When the base type operations should remain fully interchangeable.
- When the value never leaves a tiny local scope and no domain confusion is possible.
