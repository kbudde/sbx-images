# Contributing

## Conventional commits

This repository uses [Conventional Commits](https://www.conventionalcommits.org/) for both
commit messages and PR titles. Commitlint enforces them in CI on pull requests (PR title only,
squash-merge workflow); merge commits are ignored.

### Format

```text
<type>(<scope>): <subject>
```

- `type` (required): one of `feat`, `fix`, `docs`, `style`, `refactor`, `perf`, `test`,
  `build`, `ci`, `chore`, `revert`.
- `scope` (optional): kit name (`opencode2`, `skills`, `ai-tools-mixin`, `go-mixin`) or
  infra area (`ci`, `lint`, `scripts`, `docs`).
- `subject`: imperative, lowercase, no trailing period.

### Examples

```text
feat(opencode2): add mcp gateway bootstrap
fix(go-mixin): pin go version arg pattern
docs: document yaml frontend build
ci(build): add nightly rebuild schedule
chore: seed initial kit tags
```

### Why it matters

Per-kit semantic versions are derived with git-cliff using these commit types. A `feat` bumps
the minor version, a `fix` bumps the patch version, and `BREAKING CHANGE` bumps the major.
Commit types must match git-cliff's parsers so per-kit version bumps work.

### Local enforcement (optional)

A commit-msg hook can be installed via the mise task:

```sh
mise run commitlint   # if available
```

## How to add a kit

1. **Create the directory.** Use a lowercase, hyphenated name: `my-kit/`.
2. **Add the manifest** `my-kit/my-kit.yaml`:

   ```yaml
   # syntax=docker/sandbox-kit:3
   # yaml-language-server: $schema=https://raw.githubusercontent.com/docker/sandbox-kit-spec/main/schema/kit.schema.json
   schemaVersion: "3"
   kind: mixin # or workload
   displayName: My kit

   provides:
     - "my-kit@0.1.0"

   capabilities: []
   ```

   The `# syntax=` line makes the YAML a BuildKit frontend; the modeline enables editor
   validation against the official schema. Do not invent a custom schema.

3. **Add the companion Dockerfile** `my-kit/my-kit.dockerfile`. It is discovered by naming
   convention; a kit without it is validated but not built.
4. **Add supporting files** as needed (`context.md`, `start.sh`, etc.).
5. **Validate locally**:

   ```sh
   scripts/discover-kits.sh
   scripts/check-kit.sh my-kit
   sbx kit validate my-kit   # if the sbx CLI is installed
   ```

6. **Lint and format**:

   ```sh
   mise run lint
   mise run fmt-check
   ```

7. **Build locally**:

   ```sh
   KIT=my-kit mise run build:kit
   ```

8. **Commit** using a conventional commit, e.g. `feat(my-kit): add initial kit`.

### Rules

- Discovery is automatic: any root dir with `<dir>/<dir>.yaml` is a kit. No allow-list.
- `agent/` is not a kit (no matching yaml).
- Keep the yaml/dockerfile names aligned with the directory name.
- Do not change kit runtime behaviour as part of infra work.

## CI runs mise tasks

Every workflow step that runs a command runs a mise task, so a local run and CI execute the
same code with the same pinned versions:

- each job sets up the toolchain with `jdx/mise-action`, which runs
  `mise install --locked` against `mise.lock` (commit `mise.lock` together with the
  `.mise/locks/<tool>/<version>` sidecars it references);
- each command step is a single `mise run …` — `lint`, `fmt-check`, `security`,
  `security:gitleaks`, `security:zizmor`;
- GitHub-only mechanics stay as actions (`uses:` steps): checkout, paths-filter, artifact
  and SARIF upload, Docker login/push.

To add a check: add a mise task first, then one `mise run` step for it. Do not inline a
command in a workflow — that is how `dockerfmt` ended up running on a runner that does not
ship it.

## Pull request process

1. Fork/branch from `main` using a descriptive branch name.
2. Make focused changes; keep commits conventional.
3. Run the local gate before pushing:

   ```sh
   mise run ci
   ```

4. Open a PR against `main`. The PR title must be a conventional commit (it becomes the
   squash-merge commit message).
5. CI runs lint, security, and (for changed kits) build verification (`--output type=cacheonly`).
   Fix any failures; matrix legs are independent (`fail-fast: false`).
6. Request review. Address feedback with new commits (they will be squashed on merge).
7. On merge to `main`, changed kits are published as multi-arch images and versioned with
   git-cliff tags (`<kit>-v<semver>`).

### Branch protection

Branch protection is documented only and not enforced by this repository's automation. Maintainers
should require the lint, security, and build checks before merge.

### Versioning

Each kit is versioned independently. The initial seed tag is `<kit>-v0.1.0`. git-cliff
calculates the next tag from conventional commits scoped to `<kit>/**`. "Nothing to bump" is
detected when the calculated tag equals the latest existing tag.
