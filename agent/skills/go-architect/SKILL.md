---
name: go-architect
description: Use when the user asks how to structure, decompose, or review the architecture of a Go codebase or system — triggers include "how should I structure this Go project", "clean architecture in Go", "hexagonal architecture", "should this be microservices", "split this monolith", "review this package layout", "design this service", "where do these bounded contexts go". Decides between a single binary, a modular monolith, and services, then emits a package tree with its dependency rule, the ports each package owns, and the trade-off accepted. Produces a design, not code.
---

# Design the architecture of a Go system

Chooses a structure and defends it. Emits a package tree, the dependency rule
that holds it together, and the cost the user is knowingly accepting. Does not
write implementation code — see "Do not".

**Default answer, until the signals say otherwise:** one binary, structured
package-by-feature, everything under `internal/`. Microservices are a
distribution decision with a real tax, not a starting posture.

## Steps

1. **Read before proposing.** `go.mod`, then the tree, then the import graph.
   `go list -deps ./...` shows the import graph; `go list -f '{{.ImportPath}}'`
   lists packages. Never design against a hypothetical codebase.

2. **Classify the shape.** Answer four questions out loud before naming a
   pattern:

   | Question | If yes |
   |---|---|
   | One team, one deployment cadence? | Stay in one binary |
   | Modules change for unrelated reasons at the same time? | Split into packages now, extract a service later |
   | One part needs different scaling, runtime, or compliance scope? | That part is the extraction candidate |
   | Can the team own CI/CD, on-call, and a data store per service? | Only then is services the honest answer |

   Three "no" answers and no scaling reason: it is a modular monolith. Say so
   plainly rather than designing a distributed system nobody asked for.

3. **Pick the in-process pattern.** Four are worth knowing; they differ in how
   much ceremony they cost, not in their correctness:

   - **Package-by-feature** — default. `internal/orders/` holds the entities,
     the use cases, and the SQL. Best when one team owns the whole product.
   - **Hexagonal / ports and adapters** — `internal/orders/` holds the domain
     and declares `type Store interface`; `internal/adapters/postgres/`
     implements it. Worth it when the domain has rules worth testing without a
     database.
   - **Clean architecture** — the same dependency rule as hexagonal, drawn as
     four layers: entities / use cases / interface adapters / drivers. Use when
     the domain is large enough to deserve its own layer; otherwise the extra
     layer is cost without benefit.
   - **Vertical slice** — one package per feature containing handler, logic,
     and query. Cheap, and it scales worse than package-by-feature once shared
     rules appear.

   Full trees, what each pattern costs, and the failure mode for each are in
   `references/separation-patterns.md`.

4. **Draw the tree, then write the dependency rule under it.** The rule is the
   deliverable; the tree is only its picture. State it as one sentence that a
   `go list` import-graph check could confirm. Default rule:

   ```
   cmd/<service>/main.go   imports adapters, wires them into use cases, and
                           nothing else — the only composition root
   internal/<feature>/     imports its own packages and stdlib only; declares
                           the interfaces its own code needs
   internal/adapters/      imports internal/<feature>/ to satisfy its
                           interfaces; never the reverse
   ```

5. **Name the ports.** For every package that touches the outside world, list
   the interface it owns and who implements it. Rules:

   - Define the interface in the **consuming** package, never next to the
     implementation. Go's implicit interfaces make the provider need not know.
   - Interfaces stay small: one or two methods, per capability. A repository
     interface with twelve methods is a database in disguise.
   - **Accept interfaces, return structs.** Returning an interface hides the
     type behind an abstraction nobody needs.
   - Take `context.Context` as the first parameter of anything that can block.
   - Return `error`; use wrapped errors with `%w` and `errors.Is`, and a
     package-level typed error per failure the caller is expected to branch on.
   - Do not pass `*sql.Tx` through the service layer. Declare a `UnitOfWork`
     port instead, so the domain never names a database type.

6. **State the trade-off you accepted.** One short paragraph, naming what the
   chosen structure costs: an extra package, an extra hop, a test double, an
   extra deployable. If the cost cannot be named, the design is not finished.

7. **Hand back the design, then stop.** Present: classification answers, chosen
   pattern, package tree, dependency rule, port list, trade-off. Ask before
   creating any file. If the user approves scaffolding, that is a normal
   editing task — this skill's job ends at the design.

## When to read what

| Question | File |
|---|---|
| Which in-process pattern, and what does it cost? | `references/separation-patterns.md` |
| How many services, where the boundaries, how they talk, who owns the data | `references/microservices.md` |
| `cmd/` vs `internal/` vs `pkg/`, composition root, interface idioms, test seams | `references/go-layout.md` |
| Monolith or services? Writing it up as a decision | `references/decisions.md` |

## Traps

- **`pkg/` is not idiomatic and not official.** `go.dev/doc/modules/layout`
  never mentions it; the `internal/` directory has real compiler enforcement and
  `pkg/` has none. Skip it.
- **An interface next to its only implementation is dead weight.** Interfaces
  earn their keep at the point of variation — a second implementation, or a
  test that needs to substitute. Everywhere else, use the concrete type.
- **`utils`, `common`, `shared`, and `helpers` are a smell**, not a package.
  Anything that lands there belongs next to its callers. The Go proverb is
  "package by feature", not "package by layer".
- **Kubernetes is not an idiomatic Go reference.** It was converted from Java
  and violates basic Go rules including accept-interfaces-return-structs.
- **A bounded context is not a service.** A bounded context defines the
  *largest* coherent model; a service is that context cut smaller. Drawing a
  service per bounded context tends to produce monoliths with network latency.
- **A distributed monolith is the worst outcome**: separately deployed binaries
  that share a database or form synchronous call chains deeper than two hops.
  You pay the network and keep the coupling. Detect it explicitly.
- **Remote calls are coarse-grained.** A naive in-process call converted to RPC
  becomes a chatty N-hop chain. Coalesce before you split.
- **Every remote call needs an explicit timeout, a retry budget, and a
  degradation path** before it ships, not after the first incident.

## Do not

- Write or scaffold implementation files from this skill — emit the design and
  get approval first.
- Invent a DI framework, a service mesh, or a database-per-service store
  because the pattern mentions them. Go wires dependencies in `main()`.
- Recommend splitting into services without a stated scaling, team-autonomy, or
  regulatory reason. "Microservices" as an aspiration is not a reason.
- Introduce a package manager, build config, or CI to a repo that has none.
- Touch `bundles/` — this skill designs code; use `wiki-page` for wiki edits.
- Claim that a design "tests clean". Verification here is reading `git diff`
  and re-reading what you wrote.