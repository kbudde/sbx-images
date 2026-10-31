# Mixed-language stack reference (Go/Rust + web)

Enable mise monorepo mode when more than one language is detected.

## Layout

```text
repo/
  mise.toml                 # monorepo_root, shared runtimes, aggregate tasks
  services/api/             # Go: go.mod, .golangci.yml
  services/engine/          # Rust: Cargo.toml, rustfmt.toml, deny.toml
  apps/web/                 # TS: package.json, biome.json, tsconfig.json
```

## Root `mise.toml`

```toml
monorepo_root = true

[monorepo]
config_roots = ["services/*", "apps/*"]

[tools]
go = "latest"
rust = { version = "latest", components = "rustfmt,clippy" }
node = "latest"

[tasks.lint]
run = "mise run '//...:lint'"

[tasks.fmt]
run = "mise run '//...:fmt'"

[tasks.sast]
run = "semgrep scan --config p/security-audit ."

[tasks.test]
run = "mise run '//...:test'"
```

## Per-subdirectory configs

Subdirectory `mise.toml` files hold language-specific tools and tasks (see `go.md`, `rust.md`, `typescript.md`). Language-native configs (`.golangci.yml`, `rustfmt.toml`, `biome.json`) are colocated with code, not at the repo root.

## Cross-language SAST

- Root: `semgrep scan --config p/security-audit .`
- Go: `gosec`, `govulncheck`
- Rust: `cargo-deny`, `cargo-audit`
- TS: `eslint-plugin-security`, `npm audit`
