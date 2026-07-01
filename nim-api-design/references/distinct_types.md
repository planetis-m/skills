# Domain Safety with Distinct Types

Use `distinct` when two concepts share a base type but should not be mixed.

```nim
type
  PackageId* = distinct string
  UserId* = distinct string

proc `==`*(a, b: PackageId): bool {.borrow.}
proc `$`*(id: PackageId): string {.borrow.}

proc `==`*(a, b: UserId): bool {.borrow.}
proc `$`*(id: UserId): string {.borrow.}
```

## Key points

- Base values and different `distinct` types do not convert implicitly.
- Borrow only the operations the public type needs.
- Keep the base type when callers require full interchangeability.
