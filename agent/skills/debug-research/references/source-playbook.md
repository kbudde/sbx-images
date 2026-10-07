# Source playbook — symptom class → where to look first

Read this when you have a symptom and no lead. Skip it when the error names its
own subsystem — the error text is a better lead than any table.

Each entry names the source that settles that class fastest, and the claim worth
checking there. The version-specific behaviour of the tool itself always
outranks a general habit.

## Works in CI, fails locally

The two environments differ somewhere the error message never mentions.

| Look at | Claim to check |
|---|---|
| The CI env file vs local | A variable set in CI and unset here changes the code path |
| Config precedence | Which file wins — and whether the local one is being read at all |
| Working directory | A relative path resolves differently in a different cwd |
| Version pins | CI may pin a version that local does not |

The tell: the same commit behaves differently in two places. Diff the
environments, do not debug the code — the code is identical.

## 401 / 403 / "invalid token"

Almost never a bug. The auth model decides which of these it is.

| Look at | Claim to check |
|---|---|
| The tool's auth docs | Token type, scope, and where it must be sent |
| Credential storage | Whether the agent holds a sentinel that a proxy is meant to substitute — see [/concepts/Proxy-managed credentials](/concepts/Proxy-managed%20credentials.md) in `bundles/tech/` |
| Scope and expiry | A valid token with the wrong scope returns 403, not 401 |
| Header name and case | Some servers are strict about the exact header |

403 with a valid token usually means scope or path. 401 means the token never
arrived, or arrived as the wrong thing.

## Worked before, broke after an update

The diff between the two versions is the answer. Do not read anything else
first.

1. Release notes and changelog across the boundary — grep for the error string.
2. The `BREAKING` or migration section, specifically.
3. The upstream issue, if the changelog is silent — search the exact string.
4. The source diff for the function named in the trace.

If the wiki holds a page on the tool, check whether an older page in it now
contradicts the release notes. That contradiction is itself the finding.

## Fails only inside a container or sandbox

The failure is at the isolation boundary, not in the application.

| Look at | Claim to check |
|---|---|
| What the boundary drops | Capabilities, mounts, and env the workload assumes |
| State lifetime | Whether the state the tool needs lives on a path that survives — see [/concepts/Sandbox state persistence](/concepts/Sandbox%20state%20persistence.md) in `bundles/tech/` |
| Path translation | Host paths and in-sandbox paths are not the same path |
| Networking | Whether the call leaves the boundary at all |

Order matters: confirm the request or write actually reaches the layer that
fails, before theorising about what that layer does.

## Intermittent, or only under load

Timing, ordering, or an undocumented default.

| Look at | Claim to check |
|---|---|
| Retry and timeout defaults | Documented defaults are often shorter than you assume |
| Concurrency limits | Connection pools, file descriptor limits, cgroup caps |
| Idempotency | A retry that is not idempotent produces a different second failure |
| Caching | A cache that makes the bug disappear locally and return in production |

Intermittent bugs need a lead, not a repro. The trace, the exact timestamps, and
the config are worth more than another run.

## Container exec or attach fails

| Look at | Claim to check |
|---|---|
| Lifecycle state | Running, stopped, or recreated — each loses a different set of things |
| Entrypoint vs command | An entrypoint that swallows argv produces an empty command |
| TTY allocation | Non-interactive runs without a TTY fail in TTY-dependent tools |
| Exit codes | A wrapper that reports its own code hides the real one |

## The tool does not see the config at all

Before reading code, prove the tool read the file. Most of these are a path or
a format mismatch, and all are visible in the docs.

1. Where the tool looks, in what order.
2. Whether the file parsed — a silent parse failure looks like an absent file.
3. Whether the key is at the level the tool expects.
4. Precedence against the environment variable of the same name.

## The output is wrong but nothing errored

Worse than a crash, because it is silent.

| Look at | Claim to check |
|---|---|
| Version skew | Client and server disagreeing on a wire format |
| Locale, timezone, encoding | Silent corruption in exactly this shape |
| Default changed | A documented default that changed between versions |
| Rounding and precision | Formatting applied twice, or in the wrong place |

The wiki is unusually good here: a filed source summary or concept page often
already records the behaviour that changed.

## When nothing fits

Search the exact error string and read the source. Record what you ruled out and
what would settle it. An honest "could not determine, and here is the next
probe" is a better page than a confident wrong cause — the next session can act
on the first and only re-diagnoses the second.