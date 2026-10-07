# Deciding, and writing the decision up

## The distribution tax

Everything on this list is what microservices cost, paid continuously. Name the
items you are accepting; if you cannot name them, you are not ready.

| Cost | What it actually means |
|---|---|
| Network latency | Every call that was a function pointer is now a round trip with tail latency. Remote calls must be coarse-grained; fine-grained call graphs become unusable. |
| Partial failure | Any call can fail. The application must be designed to tolerate it, not to assume it away. |
| No in-process transactions | Cross-service consistency is eventual, with compensating operations. |
| No type checking across boundaries | Schemas must be versioned, generated, and checked for breaking changes in CI. |
| Deployment count | N services means N pipelines, N rollback procedures, N on-call rotations. |
| Observability burden | Without distributed tracing you cannot answer "why was this request slow". |
| Operational skills | Someone has to run Kubernetes or equivalent, manage secrets, and own the data stores. |
| Test environment | No shared memory means no shared test fixtures; you need integration environments or testcontainers. |
| Organizational overhead | Requires teams that can own a service end to end, plus a platform team. |

Industry estimates put the capacity overhead of a well-run distributed system at
30–50%. A monolithic program in one process spends none of it.

## Signals that justify splitting

Extract a service when at least one of these is true **now**, not projected:

| Signal | Extraction candidate |
|---|---|
| A part needs different scaling — 100x the I/O, or GPU work, or CPU-bound batch | That part |
| A part needs a different release cadence or a different runtime | That part |
| A part must be isolated for compliance (PCI, SOC 2 scope) | That part |
| Two teams change the same code constantly and block each other | Split on the seam between their responsibilities |
| The deploy pipeline is the bottleneck, and modules are cleanly separable | The slowest-to-change module |

Monolith-first advocates (Fowler) argue you should build a well-structured
monolith and split when it hurts. Their critics (Richardson) answer that a good
in-process interface is usually *not* a good service interface, so a monolith
tends to hide services that cannot be extracted cheaply. Fowler himself
concedes this in his own article: *"a good in-process interface is usually not a
good service interface."*

There is a third position that is usually right for a single team: the
**modular monolith**. One deployable, strict internal boundaries enforced by the
compiler, organized by domain rather than by technical layer. You get the
boundary without the tax, and extraction stays an option because the modules
already have clean interfaces. A modular monolith is not "a monolith with
folders" — the boundaries need enforcement, not discipline that erodes over
six sprints.

Rough sizing guidance, offered as a heuristic rather than a law:

| Situation | Answer |
|---|---|
| Under ~30 engineers, no divergent scaling | Modular monolith |
| 30–150 engineers, one bounded product, emerging contexts | Modular monolith, extract selectively |
| 150+ engineers, a platform team, stable and team-owned contexts | Microservices for the parts that need them |
| Any size, no CI, no automated tests | Neither. Fix the delivery pipeline first. |

## Decision matrix

Fill this in before proposing a structure. Empty cells are the reason the design
will be wrong.

```
Problem shape:
  Single team?                  Y / N
  One deployable cadence?       Y / N
  Parts scale differently?      which:
  Parts release separately?     which:
  Compliance isolation needed?  which:
  Platform team exists?         Y / N

Chosen pattern:  package-by-feature / hexagonal / clean / vertical slice
Extract now?     no / <component>, because <signal above>

Cost accepted:
  <one sentence>
```

## ADR template

```markdown
# ADR <n>: <decision in one line>

- Status: proposed | accepted | superseded by ADR-<n>
- Date: YYYY-MM-DD
- Scope: <which parts of the system this covers>

## Context

<2-5 sentences. What forces a decision now? Not history.>

## Options

### Option A — <name>
- How:
- Costs:
- Rejected because:

### Option B — <name>
- How:
- Costs:
- Rejected because:

## Decision

<Option X, in the present tense.>

## Consequences

- Accepted:
- Traded away:
- Revisit when: <the concrete signal that would change this answer>
```

## Reviewing an existing layout

When asked to review rather than design, look for these in order — they are
listed by how often they turn out to be the real problem:

1. **Import cycles or feature packages importing each other.** The dependency
   rule has already been violated; layers are decorative.
2. **Interfaces declared next to their single implementation.** Ceremony with no
   variation behind it.
3. **`utils`, `common`, `shared`, or `helpers`.** Something does not belong
   anywhere.
4. **`pkg/` in a server repo.** Not idiomatic, not enforced, no benefit over
   the root.
5. **Handlers containing SQL and business rules together.** The 400-line
   handler. It always starts as a 40-line handler.
6. **`*sql.Tx` or `*sql.DB` in a signature inside the service layer.** The
   domain names the database.
7. **A `main.go` that has grown past wiring.** Composition leaked.
8. **Business logic in an adapter, with no core to hold it.** Usually the
   correct destination is a `internal/<feature>/` package, not more adapter
   code.
9. **Services sharing a schema, or synchronous chains deeper than two hops.** A
   distributed monolith.
10. **No `context.Context` deadline on an outbound call.**

Report findings as: what is wrong, which rule it breaks, the smallest fix, and
what it costs. Do not propose a rewrite where three of the ten apply.