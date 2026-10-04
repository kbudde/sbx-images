# AGENTS.md

Guidance for AI agents working in this repository.

## Repository Layout

This repo contains Docker Sandbox Kit v3 descriptors, mixins, and workloads:

```
examples/           Reference mixins (claude-mixin, codex-tools)
opencode-go/        Go workload (apt-based Go install)
opencode-workload/  Base OpenCode workload
go-mixin/           Go toolchain mixin (version-pinned, SHA256-verified)
ai-tools-mixin/     AI tools mixin (serena + archify)
```

## Writing a v3 Mixin

### Descriptor (`<name>.yaml`)

```yaml
# syntax=docker/sandbox-kit:3
schemaVersion: "3"
kind: mixin
displayName: My mixin

args:
  version:
    default: "1.0.0"
    pattern: '^[0-9]+\.[0-9]+\.[0-9]+$'
    buildArg: MY_VERSION

provides: ["my-tool@${{ kit.args.version }}"]

capabilities:
  - type: com.docker.sandbox/network-policy@1
    config:
      runtime:
        allow:
          - example.com
  - type: com.docker.sandbox/agent-context@1
    config:
      contentFile: ./context.md
```

### Dockerfile (`<name>.dockerfile`)

Multi-stage build with `FROM scratch` final stage:

```dockerfile
FROM debian:trixie-slim AS build
ARG MY_VERSION
ARG TARGETARCH
RUN apt-get update && apt-get install -y --no-install-recommends curl ca-certificates \
 && rm -rf /var/lib/apt/lists/*
RUN case "$TARGETARCH" in \
      amd64) arch=amd64 ;; \
      arm64) arch=arm64 ;; \
      *) echo "unsupported TARGETARCH: $TARGETARCH" >&2; exit 1 ;; \
    esac \
 && curl -fsSL "https://example.com/tool-${MY_VERSION}.linux-${arch}.tar.gz" -o /tmp/tool.tar.gz \
 && echo "<sha256>  /tmp/tool.tar.gz" | sha256sum -c - \
 && mkdir -p /out/usr/local/bin \
 && tar -C /out --strip-components=1 -xzf /tmp/tool.tar.gz

FROM scratch
COPY --from=build /out/ /
```

### Key Patterns

- **Always use `TARGETARCH`** — BuildKit supplies it; map to the tool's arch naming.
- **Verify checksums** — download `.sha256` files or embed expected hashes.
- **Final stage is `FROM scratch`** — copy only the files the mixin adds.
- **Install to `/out/`** in the build stage, then `COPY --from=build /out/ /` — this keeps the mixin image minimal.
- **Symlinks in `/usr/local/bin/`** — ensures tools are in PATH for any workload.
- **Set `GOTOOLCHAIN=local`** for Go tools to prevent runtime toolchain downloads.

### Capabilities

| Type | Purpose |
|------|---------|
| `com.docker.sandbox/network-policy@1` | Runtime network access (`runtime.allow` list) |
| `com.docker.sandbox/credential@1` | API key injection (`service`, `phase`, `apiKey`) |
| `com.docker.sandbox/agent-context@1` | Agent instructions (`contentFile`) |

### Build & Validate

```bash
# Validate YAML
python3 -c "import yaml; yaml.safe_load(open('my-mixin/my-mixin.yaml'))"

# Build (requires sandbox-kit frontend image)
docker buildx build -f my-mixin/my-mixin.yaml -t my-mixin:dev my-mixin/

# Build Dockerfile directly (no frontend needed)
docker build -f my-mixin/my-mixin.dockerfile -t my-mixin:dev my-mixin/
```

## Using Firecrawl for Research

When you need facts beyond your knowledge cutoff or need to check documentation:

```python
from firecrawl import Firecrawl
fc = Firecrawl()

# Search the web
res = fc.search("latest Go version 2026", limit=5)
for r in res.web:
    print(r.title, r.url)

# Scrape a specific page as markdown
r = fc.scrape("https://example.com/docs", formats=["markdown"])
print(r.markdown[:3000])
```

### Constraints

- **API key**: Injected by the sbx proxy — `Firecrawl()` just works.
- **No screenshots**: `formats=["screenshot"]` returns links to Firecrawl's storage host, which is outside the allow list.
- **Prefer `search` + targeted `scrape`** over `crawl` — `crawl` spends one credit per page.
- **402 = out of credits**: Report and stop, don't retry.
- **Network policy**: Only `api.firecrawl.dev` is allowed by default. Scrape URLs found in results through Firecrawl, not `curl`.

## Adding a New Mixin

1. Create a directory named after the mixin: `my-mixin/`
2. Add `my-mixin.yaml` (descriptor) and `my-mixin.dockerfile` (build recipe)
3. Optionally add `context.md` (agent instructions)
4. Validate YAML and Dockerfile build
5. Commit

## Adding a Tool to an Existing Mixin

1. Add a new `ARG` and install step to the Dockerfile
2. Add a corresponding `args` entry and `provides` entry in the YAML
3. Update `context.md` with usage instructions
4. Rebuild and verify
