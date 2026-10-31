# sbx-kits

Docker Sandbox kits built from this repository. Each kit is a self-contained directory
containing a kit manifest (YAML) that acts as a [BuildKit](https://github.com/moby/buildkit)
frontend, plus a companion Dockerfile.

## Kits

Kits are discovered automatically: any root directory containing `<dir>/<dir>.yaml` is a kit
(`agent/` is not a kit). Current kits:

- `opencode2` — OpenCode workload
- `skills` — skills/agents mixin for OpenCode
- `ai-tools-mixin` — AI tooling mixin (serena, archify)
- `go-mixin` — Go toolchain mixin

## Prerequisites

- [mise](https://mise.jdx.dev/) (installs the toolchain from `mise.toml`)
- Docker with BuildKit/buildx (multi-arch builds need an OCI-capable builder)
- Optional: the `sbx` CLI for `sbx kit validate`

Install tools and git hooks (one-time):

```sh
mise run init
```

(`mise run init` runs `mise install` + `lefthook install`.)

## Local build and test

```sh
mise run lint         # kit validation, hadolint, yamllint, shellcheck, actionlint, markdownlint
mise run fmt-check    # shfmt + dockerfmt + prettier (no writes)
mise run security     # trivy, skillspector, gitleaks, zizmor
mise run build        # build all kits locally
KIT=opencode2 mise run build:kit   # build a single kit
mise run check        # full local gate (lint + fmt-check + security) (`ci` is an alias)
```

### Build invocation

Kits are **not** built from a plain `Dockerfile`. The kit YAML is the BuildKit frontend and the
companion `<kit>.dockerfile` is discovered by naming convention:

```sh
docker buildx build <kit> \
  -f <kit>/<kit>.yaml \
  --platform linux/amd64,linux/arm64 \
  --provenance=mode=min \
  -t docker.io/sbx/<kit>-image:local .
```

For a single kit via mise, set `KIT=<name>` and run `mise run build:kit`.

## CI overview

GitHub Actions runs separate workflows:

- `lint.yml` — per-kit lint + `fmt-check`
- `security.yml` — trivy (fs + image) and gitleaks
- `build.yml` — matrix build/publish, gated on lint + security

Triggers: push to `main`, pull requests, `workflow_dispatch`, and a nightly schedule.
Change detection (dorny/paths-filter) runs only affected kits; shared changes (workflows/scripts)
rebuild all kits. Matrix legs use `fail-fast: false`. Concurrency cancels in-progress runs for
the same PR/branch.

- Pull requests build changed kits with `--output type=cacheonly` (no push).
- Pushes to `main` publish multi-arch images to Docker Hub as `v<semver>`.

## Kit authoring quickstart

1. Create a directory named after the kit: `mykit/`.
2. Add `mykit/mykit.yaml` starting with:

   ```yaml
   # syntax=docker/sandbox-kit:3
   # yaml-language-server: $schema=https://raw.githubusercontent.com/docker/sandbox-kit-spec/main/schema/kit.schema.json
   schemaVersion: "3"
   kind: mixin # or workload
   ```

3. Add the companion `mykit/mykit.dockerfile`.
4. Add any supporting files (e.g. `context.md`, `start.sh`).
5. Validate: `scripts/check-kit.sh mykit` and (if available) `sbx kit validate mykit`.
6. Lint: `mise run lint`.

See `CONTRIBUTING.md` for the full guide.
