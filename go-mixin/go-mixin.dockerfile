FROM debian:trixie-slim@sha256:a72b4433de1cf7d6bae0c4cee74d0547f58601a643b3375f070c51600d63b6b2 AS build
ARG GO_VERSION
ARG TARGETARCH
RUN apt-get update && apt-get install -y --no-install-recommends curl ca-certificates tar \
  && rm -rf /var/lib/apt/lists/*
RUN case "$TARGETARCH" in \
      amd64) goarch=amd64 ;; \
      arm64) goarch=arm64 ;; \
      *) echo "unsupported TARGETARCH: $TARGETARCH" >&2; exit 1 ;; \
    esac \
 && curl -fsSL "https://go.dev/dl/go${GO_VERSION}.linux-${goarch}.tar.gz" -o /tmp/go.tar.gz \
 && mkdir -p /out/usr/local \
 && tar -C /out/usr/local -xzf /tmp/go.tar.gz \
 && rm -f /tmp/go.tar.gz 

RUN GOTOOLCHAIN=local GOBIN=/out/usr/local/bin /out/usr/local/go/bin/go install golang.org/x/tools/gopls@v0.23.0 \
  && GOTOOLCHAIN=local GOBIN=/out/usr/local/bin /out/usr/local/go/bin/go install github.com/golangci/golangci-lint/v2/cmd/golangci-lint@v2.14.0

RUN ln -s /usr/local/go/bin/go /out/usr/local/bin/go \
  && ln -s /usr/local/go/bin/gofmt /out/usr/local/bin/gofmt

FROM scratch
COPY --from=build /out/ /
