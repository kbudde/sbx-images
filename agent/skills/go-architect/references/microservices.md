# Microservices in Go

Reached only when the signals in `SKILL.md` step 2 justify it. This file is
about *how*, once you are there.

---

## Decomposition: bounded contexts, then services

**Bounded context** (Domain-Driven Design) is a region of the domain where one
ubiquitous language holds and a term has exactly one meaning. "Customer" in
sales and "customer" in support are different types.

The counterintuitive part, worth stating to any team that says "bounded context"
and means "microservice": a bounded context defines the **largest** coherent
model, not a service. If you draw one service per bounded context you have
built a monolith with network latency. You decompose *inside* a context — around
the *business capabilities* that change for different reasons at the same time
— and a service is one context cut along its seams. A microservice is a bounded
context, but not every bounded context is a microservice.

Two guides for the cut:

1. **Organize around business capability**, not technical layer. A service owns
   a slice of the domain end to end — its logic, its storage, its external
   integrations. Splitting by "we have a frontend team and a database team" is
   Conway's Law working against you.
2. **Keep things that change together together.** If you keep editing two
   services in the same commit, they are one service.

Team size anchors from Fowler & Lewis: the largest services are sized by a
two-pizza team — roughly a dozen people. The smallest they saw were one person
owning one service.

## Decomposing an existing monolith

The atomic unit is three steps, not one:

1. Decouple the capability into its own interface **together with its data**.
2. Redirect every consumer to the new interface.
3. Retire the old code path in the monolith.

Skipping step 3 is the documented anti-pattern: teams declare victory the moment
the new service exists and the monolith keeps its copy, so there are now two
implementations and no benefit. Decoupling only a facade, or only the backend
without the data, is the same mistake in different clothes — without decoupling
the data it is not a microservice, just a remote function call.

Extract capabilities that are already fairly decoupled from the monolith and do
not require many client-facing changes first.

## Communication: sync or async

| Style | Use for | Latency | Coupling |
|---|---|---|---|
| REST / HTTP JSON | Edge traffic, external APIs, third parties | Low–medium | Contract only |
| gRPC + protobuf | Internal service-to-service, high volume, needs typing | Low | Generated from a shared schema |
| Async events (NATS, Kafka) | Workflows that do not need an immediate answer, fan-out, decoupling | Medium | Producer knows nothing of consumers |

Go specifics: protobuf generation via `protoc-gen-go` and
`protoc-gen-go-grpc`; `buf` manages the schema and generates across languages.
Use `google.golang.org/grpc` for transport, `google.golang.org/protobuf` for the
wire format, `connectrpc.com/connect` if you want a single library for REST,
gRPC, and HTTP/2 without a sidecar proxy.

Two hard rules:

- **Every call carries a deadline.** `context.WithTimeout` at the client,
  always. Without one, a slow dependency becomes an unbounded goroutine leak.
- **Retries need a budget and jitter, and belong at one layer only.**
  Retrying at both the client and the gateway doubles the load on a service
  that is already failing. Cap total attempts, respect `Retry-After`, and never
  retry a non-idempotent operation without an idempotency key.

The failure mode Fowler and Lewis single out is multiplicative downtime: with
synchronous chains, the downtime of the system becomes the product of the
downtimes of its parts. Their observed rule of thumb was one synchronous call
per user request.

## Data ownership

Each service owns its data. That does not mean a separate PostgreSQL instance
per service — the goal is **autonomy**, enforced by schema ownership rules, so
no service reads or writes another's tables. Polyglot persistence (a different
store per service) follows from ownership but is not required by it.

Consequences you must accept up front:

- **No cross-service joins.** A report that needs orders and customers gets
  either a denormalized read model fed by events, or its own service.
- **Consistency is eventual.** Distributed transactions are not viable across
  service boundaries; transactional coordination is temporal coupling that
  microservices specifically give up.
- **The same noun can have different schemas in two services.** That is the
  point of a bounded context, and it needs an anti-corruption layer or a
  translation step at the boundary.
- **Cross-cutting queries need CQRS or events.** Command side writes; events
  update read models. Keep this narrow — a read replica per query is often
  enough.

## Saga for cross-service operations

A saga is a sequence of local transactions, each with a compensating action.
Two flavors:

- **Orchestration** — a coordinator calls each participant and decides the next
  step. Explicit, easy to trace, one place to look. Use this.
- **Choreography** — each service reacts to events. Fewer moving parts, but the
  flow is implicit and the logic scatters. Use for simple fan-out.

The pattern's failure modes are missing compensations and compensations that
cannot succeed. Write the compensation down next to the action it undoes, and
test the rollback path explicitly. Compensations are business operations
("release the reservation", "issue the refund"), not database rollbacks.

## Idempotency

Everything that crosses a network boundary can be delivered twice. Deduplicate
on:

- **Messages** — a message ID with a processed-messages table, or broker-level
  deduplication.
- **Commands** — an idempotency key from the caller, stored with the result.
- **Handlers** — natural keys plus an optimistic-concurrency check, or `INSERT
  ... ON CONFLICT DO NOTHING` on an outbox row.

## Resilience

For every outbound call, all four, or it is not production-ready:

1. **Timeout** — bounded, derived from the caller's own remaining budget, not
   invented per call site.
2. **Retry with budget** — exponential backoff, jitter, capped attempts.
3. **Circuit breaker** — stop calling a service that is failing; fail fast and
   degrade. Closed → open after N failures; open → half-open after a cooldown to
   probe.
4. **Bulkhead** — a separate pool per dependency so one slow service cannot
   exhaust all your goroutines or connections.

Then design for failure as a property, not an incident. Netflix's Simian Army
induced service and datacenter failures in production on purpose. In Go the
practical tools are context deadlines, `errgroup` with a limit, and
`sync/errgroup` cancellation semantics.

## Observability as an architectural concern

Not an afterthought — the non-negotiable foundation. Without it, microservices
turn a five-minute debug into a five-hour one.

| Pillar | Go tool of record |
|---|---|
| Logs | `log/slog` (stdlib since 1.21). Structured, key-value. |
| Metrics | Prometheus client, or OTel metrics exported to Prometheus. |
| Traces | OpenTelemetry: `go.opentelemetry.io/otel` + `otel/sdk`. W3C `traceparent` propagation. |

Instrument once at the transport layer — `otelhttp.NewHandler` for inbound,
interceptors for gRPC — rather than decorating every use case. Attach
`service.name`, `service.version`, and build SHA as OTel resource attributes so
telemetry can be attributed without changing code.

Set up tracing and metrics in `main()` alongside the composition root, and
return a `shutdown` func so telemetry flushes on exit. That is a five-line
function and it is the difference between a debuggable system and an opaque
one.

## Distributed monolith: how to recognise it

You have the worst of both worlds when:

- Services are separately deployed but share a database schema.
- A single user request requires a synchronous chain deeper than two hops.
- A change to one service requires a coordinated release of another.
- On-call still requires the whole system to make sense at once.

All four mean the boundary is on paper only. Fix by collapsing back to a
modular monolith in one process — the boundary is much cheaper to move there
than across a network — then re-split with data ownership included.

## Go build blocks worth knowing

| Library | Use |
|---|---|
| `google.golang.org/grpc` | gRPC server and client |
| `google.golang.org/protobuf` | Wire format and code generation |
| `connectrpc.com/connect` | One library for REST + gRPC, no proxy |
| `github.com/bufbuild/buf` | Protobuf lint, breaking-change detection, codegen |
| `go.opentelemetry.io/otel` | Traces, metrics, propagation |
| `github.com/prometheus/client_golang` | Prometheus metrics |
| `github.com/nats-io/nats.go` | Request/reply and pub/sub messaging |
| `golang.org/x/sync/errgroup` | Bounded concurrency with cancellation |
| `github.com/three-dotslabs/grpc-web` | gRPC-Web for browser clients |

## Anti-patterns to reject on sight

- Microservices as a goal, measured by how many services exist.
- One service per entity, or per table.
- A shared library holding business logic — every consumer then needs a
  coordinated release.
- `utils` replicated in every service.
- Trying to fly before you can walk: no automated tests, no CI, no runbook.
- Fine-grained chatty calls inherited from in-process method calls.
- Versioning every breaking change instead of designing tolerant readers.
- Observability added after the first outage.