# The Anki sync server, compiled from Anki's own source, in a distroless image.
#
#   docker build --build-arg ANKI_VERSION=26.08.1 -t anki-sync-server:local .

ARG ANKI_VERSION=26.08.1
# Anki's own pin for the version above. CI overrides this per Anki release from
# that release's rust-toolchain.toml, which cargo install --git does not read.
ARG RUST_VERSION=1.92.0

FROM rust:${RUST_VERSION} AS build
ARG ANKI_VERSION
ARG TARGETARCH

# Anki's source contains bidi codepoints, denied by default.
ENV RUSTFLAGS="-Atext_direction_codepoint_in_literal --cap-lints=warn" \
    CARGO_TERM_COLOR=never \
    CARGO_NET_GIT_FETCH_WITH_CLI=true

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        protobuf-compiler \
        libprotobuf-dev \
        musl-tools \
        ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# musl, so the binary is static and runs on both distroless and Alpine.
RUN set -eux; \
    case "${TARGETARCH}" in \
        amd64) target=x86_64-unknown-linux-musl ;; \
        arm64) target=aarch64-unknown-linux-musl ;; \
        *) echo "unsupported architecture: ${TARGETARCH}" >&2; exit 1 ;; \
    esac; \
    rustup target add "$target"; \
    cargo install --locked --root /out \
        --git https://github.com/ankitects/anki.git \
        --tag "${ANKI_VERSION}" \
        anki-sync-server \
        --target "$target"

FROM gcr.io/distroless/static-debian12:nonroot
ARG ANKI_VERSION

COPY --from=build /out/bin/anki-sync-server /anki-sync-server

# watch-anki.yml reads back the version label to decide whether to rebuild.
LABEL org.opencontainers.image.title="Anki sync server" \
      org.opencontainers.image.description="The Anki sync server, built from Anki source into a distroless image." \
      org.opencontainers.image.version="${ANKI_VERSION}" \
      org.opencontainers.image.source="https://github.com/ankitects/anki" \
      org.opencontainers.image.licenses="AGPL-3.0-or-later" \
      org.opencontainers.image.vendor="Ankitects Pty Ltd (source); this image built by the anki-sync-s3 project"

EXPOSE 8080
VOLUME ["/data"]

# No HEALTHCHECK: no shell in this image; images built on top add their own.
CMD ["/anki-sync-server"]
