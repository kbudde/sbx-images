# TypeScript build infra reference

## mise tools

```toml
[tools]
node = "latest"
biome = "latest"
```

## Formatter/linter (`biome.json`, greenfield default)

```json
{
  "$schema": "https://biomejs.dev/schemas/latest/schema.json",
  "linter": { "enabled": true, "rules": { "recommended": true } },
  "formatter": { "enabled": true, "indentStyle": "space", "indentWidth": 2 },
  "organizeImports": { "enabled": true }
}
```

Fallback when an ESLint config already exists: keep ESLint + Prettier and add `eslint-plugin-security`; do not replace without approval.

## Tasks

```toml
[tasks.fmt]
run = "biome format --write ."

[tasks.lint]
run = "biome lint ."

[tasks.typecheck]
run = "tsc --noEmit"

[tasks.sast]
run = "npm audit --audit-level=high"

[tasks.test]
run = "npm test"
```

## Notes

- Type-check via `tsc --noEmit`.
- SAST also via Semgrep at the root for mixed stacks.
