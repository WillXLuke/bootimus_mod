# Stage 1: Build the binary
FROM golang:1.25 AS builder

WORKDIR /build

ENV GOPROXY=https://goproxy.cn,direct
ENV GOSUMDB=sum.golang.google.cn

COPY go.mod go.sum ./

RUN --mount=type=cache,target=/go/pkg/mod \
    --mount=type=cache,target=/root/.cache/go-build \
    go mod download

COPY cmd/ ./cmd/
COPY internal/ ./internal/
COPY web/ ./web/
COPY bootloaders/ ./bootloaders/
COPY main.go .

ARG VERSION=dev
ARG TARGETOS=linux
ARG TARGETARCH

RUN --mount=type=cache,target=/go/pkg/mod \
    --mount=type=cache,target=/root/.cache/go-build \
    CGO_ENABLED=1 GOOS=${TARGETOS} GOARCH=${TARGETARCH} go build \
    -a -ldflags="-w -s -X bootimus/internal/server.Version=${VERSION}" \
    -o /out/bootimus-${TARGETOS}-${TARGETARCH} .

RUN cp /out/bootimus-${TARGETOS}-${TARGETARCH} /out/bootimus

FROM scratch AS binaries
COPY --from=builder /out/ /

# Runtime
FROM debian:trixie-slim

# Switch Debian mirror to Tsinghua
RUN sed -i 's|deb.debian.org|mirrors.tuna.tsinghua.edu.cn|g' /etc/apt/sources.list.d/debian.sources \
    && sed -i 's|security.debian.org|mirrors.tuna.tsinghua.edu.cn|g' /etc/apt/sources.list.d/debian.sources

RUN apt-get update && apt-get install -y --no-install-recommends \
    wimtools \
    samba \
    ca-certificates \
    libarchive-tools \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

COPY --from=builder /out/bootimus /bootimus

EXPOSE 69/udp 8080/tcp 8081/tcp 10809/tcp 445/tcp

USER root

VOLUME [ "/data" ]
ENTRYPOINT ["/bootimus"]
CMD ["serve"]
