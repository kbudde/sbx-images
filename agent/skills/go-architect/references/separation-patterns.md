# In-process separation patterns

Four structures, one dependency rule, different ceremony budgets. All four are
correct; they differ in what they cost and when that cost is justified.

The shared rule everywhere below: **dependencies point inward.** `cmd` knows
about adapters, adapters know about features, features know about nothing but
themselves and the standard library.

---

## 1. Package-by-feature (the default)

Everything for one feature in one directory. The repository-wide organization is
business-shaped, not layer-shaped.

```
cmd/
  api/
    main.go              # composition root
internal/
  orders/
    order.go             # Order, OrderID, validation
    service.go           # Create, Cancel — business rules
    store.go             # postgres implementation of the store
    http.go              # HTTP handlers -> service
  billing/
    invoice.go
    service.go
    store.go
    http.go
  platform/
    postgres/            # pool, migrations
    otel/                # tracing setup
```

**Dependency rule:** `internal/orders/` imports no other feature package.
Sharing happens through a package that both sides deliberately import.

| | |
|---|---|
| Costs | Nothing. Same test cost as anything else. |
| Testable without a DB | Only if you write the test double; nothing forces it. |
| Failure mode | Shared rules get copied between features, or dumped in `platform/`. |
| Use when | One team owns the product and there is no reason to split. |

---

## 2. Hexagonal architecture (ports and adapters)

The core declares what it needs; adapters are plugged in at the edge. Go's
implicit interfaces make this unusually cheap — the implementation never
declares that it implements anything.

```
cmd/
  api/
    main.go              # wires postgres.NewStore() into orders.NewService()
internal/
  orders/
    domain.go            # entities + rules, stdlib only
    service.go           # use cases, deps as interfaces
    ports.go             # type Store interface; type Notifier interface
  adapters/
    postgres/
      orders.go          # implements orders.Store
    smtp/
      notify.go          # implements orders.Notifier
    httpapi/
      orders.go          # inbound: HTTP -> orders.Service
```

```go
// internal/orders/ports.go — the core owns the port
package orders

type Store interface {
    Save(ctx context.Context, o Order) error
}

type Notifier interface {
    OrderPlaced(ctx context.Context, id OrderID) error
}
```

```go
// internal/adapters/postgres/orders.go — the adapter depends on the core
package postgres

func (s *Store) Save(ctx context.Context, o orders.Order) error { /* ... */ }
```

**Dependency rule:** `internal/adapters/**` imports `internal/orders/`; never
the reverse. `internal/orders/` imports only stdlib and its own files.

| | |
|---|---|
| Costs | An extra package per adapter; a port interface per dependency. |
| Testable without a DB | Yes — the core compiles and runs with zero infrastructure. This is the whole point. |
| Failure mode | Ports multiply until every function takes eight interfaces. Delete a port when only one implementation exists and nothing varies. |
| Use when | The domain has rules worth testing without infrastructure, or a second adapter is genuinely planned. |

---

## 3. Clean architecture

The same inward rule as hexagonal, drawn as four concentric circles. Entities
and use cases are the inner two; interface adapters and drivers the outer two.

```
internal/
  entities/              # pure domain objects, no use cases, no I/O
    order.go
  usecases/              # orchestration of entities
    create_order.go
    cancel_order.go
  interface_adapters/    # implements the boundaries the use cases declare
    postgres/
    http/
  drivers/               # main(), CLI, cron, consumers
```

| vs hexagonal | |
|---|---|
| Entities split from use cases | More ceremony, clearer home for domain objects |
| Ports vs adapters naming | Same idea, four names instead of two |
| Worth it when | The domain is large enough to be worth its own layer |
| Not worth it when | The domain is a handful of CRUD paths — you get a pass-through layer that never earns its keep |

Uncle Bob's framing: the inner layers know nothing about frameworks, UI,
databases, or external agencies. The Go translation is "stdlib only" for
`entities/`.

---

## 4. Vertical slice

One package per feature containing handler, logic, and query together. The
opposite of package-by-layer: nothing is shared until it is proven twice.

```
internal/
  orders/
    create.go            # handler + use case + query
    cancel.go
    list.go
  billing/
    charge.go
```

| | |
|---|---|
| Costs | Duplication of cross-cutting concerns early. |
| Testable without a DB | Per-slice, yes — a slice is small enough to test end to end. |
| Failure mode | The third copy of a shared rule forces a refactor to package-by-feature. Acceptable — the duplication is the signal. |
| Use when | Early-stage product, thin domain, many small features. |

---

## Comparison

| | Package-by-feature | Hexagonal | Clean | Vertical slice |
|---|---|---|---|---|
| Ceremony | None | One port per dep | Highest | None |
| Domain testable with no infra | Manual | Structural | Structural | Per-slice |
| Packages per feature | 1 | 2–3 | 4+ | 1 |
| Refactor cost once wrong | Low | Low | Medium | Low |
| Scales past ~20 features | Yes | Yes | With effort | No |

## Choosing

- Nothing varies and there is one team → package-by-feature. Do not start at
  hexagonal; you can add ports later, and you will know exactly which ones you
  need.
- Rules that must be proven without a database → hexagonal.
- A domain complex enough to have its own spec → clean architecture.
- Many small features and no shared rules yet → vertical slice.

See `decisions.md` for when any of this should become a network boundary.