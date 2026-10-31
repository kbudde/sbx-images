---
name: Setup Infra
description: Set up build infrastructure (mise, linters, formatters, SAST) for a new or existing repository. Supports Go, Rust, and TypeScript, including mixed-language stacks.
---

# Setup Infra

Set up build infrastructure for a repository using [mise](https://mise.jdx.dev). Covers tool installation, linting, formatting, and SAST for Go, Rust, and TypeScript, including mixed-language (Go/Rust + web) stacks.

## Workflow

1. **Detect languages** by scanning for markers (see table below). Search the repo root and one level of subdirectories.
2. **If nothing is detected**, ask the user which languages to set up (Go, Rust, TypeScript, or a mix).
3. **Decide layout**: single language → single root `mise.toml`; mixed stack → enable mise monorepo mode.
4. **Read the relevant references** for the detected languages:
   - Go → `references/go.md`
   - Rust → `references/rust.md`
   - TypeScript → `references/typescript.md`
   - Mixed stack → `references/mixed-stack.md`
5. **Show the relevant reference blocks** to the user and **ask for changes** before writing anything. Apply user edits.
6. **Implement**, idempotently:
   - Never overwrite an existing config without showing a diff and getting approval.
   - Merge per-tool/per-task (nearest config wins); add missing pieces only.
   - Colocate language-native configs next to code in mixed stacks.
7. **Verify** by running `mise install` (or `mise install --monorepo` for mixed stacks) and the `lint`/`fmt`/`sast` tasks.

## Language detection

| Language | Markers |
|---|---|
| Go | `go.mod`, `go.work` |
| Rust | `Cargo.toml`, `rust-toolchain.toml` |
| TypeScript | `package.json`, `tsconfig.json` |

## Idempotency rules

- If a config exists, show a diff and merge; never blind-overwrite.
- Per-tool/per-task: nearest config wins; add only missing entries.
- Respect idiomatic version files (`go.mod` toolchain, `rust-toolchain.toml`, `.nvmrc`/`engines`) and also pin in `mise.toml` + `mise.lock`.
- Single language → single root `mise.toml` (no monorepo mode). Mixed → monorepo mode.

## Version pinning

Default to `latest`. Document that users can pin (e.g. `go = "1.23"`) and that CI should use `mise install --locked`.

## Out of scope (v1)

- CI pipeline generation.
- Nested per-directory configs beyond one level.
- Languages beyond Go, Rust, TypeScript.
- Auto-installing toolchains without user approval.
```