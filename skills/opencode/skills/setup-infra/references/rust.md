# Rust build infra reference

## mise tools

```toml
[tools]
rust = { version = "latest", components = "rustfmt,clippy" }
"cargo:cargo-audit" = "latest"
"cargo:cargo-deny" = "latest"
```

## Formatter (`rustfmt.toml`)

```toml
edition = "2024"
```

## Lint config (`clippy.toml` or `[lints.clippy]` in `Cargo.toml`)

```toml
# deny warnings in CI via: cargo clippy -- -D warnings
```

## SAST (`deny.toml`, generate via `cargo deny init`)

```toml
# advisories, bans, licenses, sources
```

## Tasks

```toml
[tasks.fmt]
run = "cargo fmt"

[tasks.lint]
run = "cargo clippy -- -D warnings"

[tasks.sast]
run = "cargo deny check && cargo audit"

[tasks.test]
run = "cargo test"
```

## Notes

- Commit `Cargo.lock`.
- Pin toolchain in `rust-toolchain.toml` if needed.
