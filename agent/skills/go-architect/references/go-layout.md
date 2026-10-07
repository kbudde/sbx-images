# Go layout and idioms

Everything here is either from `go.dev/doc/modules/layout` (the only official
guidance) or from the Go proverb "clear over clever" and the standard library's
own shape. Where the community disagrees with the official docs, the official
docs win.

---

## Official module layout

The Go docs organize a module by project type, not by a single template. The
relevant cases:

**Basic package** — everything in the root, one package, name matching the
module path's last element.

**Basic command** — one directory, files in `package main`, `func main` in a
file conventionally called `main.go`. Install with `go install <module>@latest`.

**Command with supporting packages** — supporting code goes in `internal/`:

```
project-root/
  go.mod
  internal/
    auth/
    hash/
  modname.go            # package modname
```

**Multiple packages** — each importable package gets its own directory, and may
nest: `auth/token/`. Private code stays in `internal/`.

**Multiple commands** — one directory per program, `package main` in each:

```
project-root/
  go.mod
  internal/
    ... shared internal packages
  prog1/
    main.go
  prog2/
    main.go
```

**Server project** — the case that matters most here. Servers are usually a
self-contained binary, so there is nothing to export; the Go docs say to keep
the server's logic in `internal/` and group commands in `cmd/`:

```
project-root/
  go.mod
  internal/
    auth/
    metrics/
    model/
  cmd/
    api-server/
      main.go
    metrics-analyzer/
      main.go
  ... other directories with non-Go content
```

And the explicit instruction for growth: *"In case the server repository grows
packages that become useful for sharing with other projects, it's best to split
those off to separate modules."* A separate **module**, not a `pkg/` directory.

## `internal/` vs `pkg/`

| | `internal/` | `pkg/` |
|---|---|---|
| Enforced by | The compiler | Nothing. Convention only. |
| Who can import | Anything under the parent of `internal/` | Anyone |
| In `go.dev/doc/modules/layout` | Yes | **Never mentioned** |
| Verdict | Default for server code | Skip it |

The `golang-standards/project-layout` repo popularized `pkg/`, `api/`,
`configs/`, `scripts/`, `deployments/`. It is not a standard, it is not what the
Go team recommends, and it has a well-known dissent: `pkg/` holds code that can
always be moved to the root, `util/`/`common/` should never exist, and
Kubernetes is not an idiomatic Go reference project because it was converted
from Java.

## `cmd/` — do you need it?

For a repository that is only commands, `cmd/` is unnecessary: `prog1/` and
`prog2/` work. `cmd/` earns its place in a mixed repository that also ships
importable packages, and it makes the install surface greppable:

```
go install example.com/proj/cmd/api-server@latest
```

Keep `main.go` thin. It should read as a wiring diagram and nothing else — the
one place in the program where every adapter is chosen.

## The composition root

Go has no DI framework, and it does not need one. Interfaces are satisfied
implicitly and wired by hand in `main()`:

```go
func main() {
    ctx := context.Background()

    pool := postgres.Open(ctx, cfg.DatabaseURL)
    defer pool.Close()

    store := postgres.NewOrderStore(pool)     // implements orders.Store
    notify := smtp.NewNotifier(cfg.SMTP)      // implements orders.Notifier
    svc := orders.NewService(store, notify)   // core, knows neither

    srv := httpapi.NewServer(svc)             // inbound adapter
    grpcsrv := grpcapi.NewServer(svc)         // second inbound adapter

    go srv.ListenAndServe(":8080")
    srv.WaitForShutdown(ctx)
}
```

If adding a dependency to a use case ever requires editing a file other than
`main.go`, the wiring leaked into the domain.

## Interface idioms

**Define interfaces where they are consumed, not where they are implemented.**
This is the single most consequential Go rule. The provider does not need to
know it satisfies anything; swapping the implementation is a `main.go` edit.

```go
// internal/orders/ports.go — consumer declares
package orders
type Store interface{ Save(ctx context.Context, o Order) error }

// internal/adapters/postgres — provider just implements it
package postgres
type Store struct{ /* ... */ }
func (s *Store) Save(ctx context.Context, o orders.Order) error { /* ... */ }
```

**Accept interfaces, return structs.** A returned interface forces callers to
assert the concrete type, which is a tax with no benefit.

**Small interfaces.** One or two methods, named for capability
(`type OrderStore interface`, `type UserStore interface`) rather than one fat
`Repository`. A twelve-method repository interface is a database wearing a
struct.

**No interfaces with a single implementation** unless a test needs a
substitute.

**`context.Context` first**, on anything that can block or make a call. Never
store it in a struct field; pass it down explicitly.

**Errors**: return `error`, wrap with `%w`, branch with `errors.Is`. Declare
exported sentinel or typed errors when callers are expected to branch:

```go
var ErrOrderNotFound = errors.New("order not found")
```

Never return bare strings for errors callers must distinguish.

## Transactions: the UnitOfWork port

`*sql.Tx` passed through the service layer leaks the database into the domain
and makes use cases untestable without a real transaction. Declare a port:

```go
// internal/orders/ports.go
type UnitOfWork interface {
    Do(ctx context.Context, fn func(Store) error) error
}
```

The adapter opens and commits a real transaction; the core sees only a callback.
This is the one place a structural abstraction pays for itself immediately.

## Test seams

| Layer | Needs | Cost |
|---|---|---|
| Domain / core | Nothing but stdlib | Microseconds; no Docker |
| Use cases | Hand-written fakes of the ports | Fast; fakes stay small because ports are small |
| Adapters | A real dependency (testcontainers) | Slow; keep few |
| Inbound adapters | `httptest.NewServer` | Fast; never touch a real listener |

Table-driven tests are the Go default. `t.Run` subtests with named cases read
better than a loop with `t.Errorf` and a shared `t`. Use `t.Parallel()` when
the test holds no shared state.

## Naming

Short, lowercase, no underscores or mixedCaps: `ReadOrder`, `httpapi`,
`postgres`. Package names are singular or a mass noun. Never `util`. Interfaces
take an `-er` agent suffix (`Store`, `Notifier`, `Reader`) or a `-er` (`Reader`,
`Writer`) — not `-ify` verbs.