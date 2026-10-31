# Go build infra reference

## mise tools

```toml
[tools]
go = "latest"
golangci-lint = "latest"
```

## Linter config (`.golangci.yml`, v2)

```yaml
version: "2"
linters:
  enable:
    - gosec
    - staticcheck
    - govet
    - errcheck
formatters:
  enable:
    - gofmt
    - goimports
```

## Tasks

```toml
[tasks.fmt]
run = "gofmt -w . && goimports -w ."

[tasks.lint]
run = "golangci-lint run ./..."

[tasks.sast]
run = "gosec ./... && govulncheck ./..."

[tasks.test]
run = "go test ./... -race"
```

## Notes

- `gosec` also runs as a golangci-lint linter (enabled above).
- `govulncheck` is reachability-aware.
- Respect `go.mod` `toolchain` directive for version pinning.
