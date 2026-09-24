# anki-sync-server

The [Anki](https://github.com/ankitects/anki) sync server, compiled from Anki's
own source into a distroless image. Nothing else is in it: no shell, no package
manager, one static binary.

```
ghcr.io/cba44/anki-sync-server:latest
ghcr.io/cba44/anki-sync-server:26.09.3
```

Built for [anki-sync-s3](https://github.com/cba44/anki-sync-s3), which adds a
dashboard, scheduled backups and offsite copies on top — but this image is
usable on its own, and is meant to be.

**Unofficial.** Ankitects publishes no Docker image; they provide a Dockerfile
and a `cargo install` recipe. This repository automates that recipe and nothing
more.

## Running it

```bash
docker run -d \
  -e SYNC_USER1=alice:a-good-password \
  -p 8080:8080 \
  -v anki-data:/data \
  ghcr.io/cba44/anki-sync-server:latest
```

Point Anki at `http://<host>:8080/`. Every setting is the sync server's own —
`SYNC_USER1..N`, `SYNC_BASE`, `SYNC_PORT`, `MAX_SYNC_PAYLOAD_MEGS` — and is
documented in the [Anki manual](https://docs.ankiweb.net/sync-server.html).

There is no healthcheck in this image, and no shell to run one with. Images
built on top add their own.

## How it is built

`cargo install --locked --git https://github.com/ankitects/anki.git --tag <version> anki-sync-server`,
targeting musl so the result is static, into
`gcr.io/distroless/static-debian12:nonroot`.

Two details are load-bearing and easy to lose:

- `RUSTFLAGS=-Atext_direction_codepoint_in_literal` — Anki's source contains
  bidirectional codepoints that rustc denies by default, so the build fails
  outright without it.
- protobuf is a build dependency of Anki's `rslib`.
- Anki pins a Rust version in `rust-toolchain.toml`, and it changes between
  releases. `cargo install --git` does not read that file
  ([rust-lang/cargo#11036](https://github.com/rust-lang/cargo/issues/11036)),
  so the build reads it separately and pins the build image to it.

Each architecture is built on its own runner — `ubuntu-latest` and
`ubuntu-24.04-arm` — and the two are merged into one manifest afterwards.
Building natively rather than under emulation is what makes that worthwhile.

To build locally for your own architecture:

```bash
docker build --build-arg ANKI_VERSION=26.09.3 -t anki-sync-server:local .
```

`RUST_VERSION` in the Dockerfile is the pin for the default `ANKI_VERSION`;
if you build a different version locally, pass the Rust version from that
release's `rust-toolchain.toml` too. In CI that is automatic — the workflow
reads it from the tag it is building.

## Keeping up with Anki

`.github/workflows/watch-anki.yml` runs at midnight UTC, compares the newest
Anki release with the version label on the published image, and rebuilds when
they differ. Prereleases are excluded — it reads the releases API rather than
tags, because the repository also carries betas and tags like `release` and
`packaging-test`.

Nothing is stored to remember what was built: the published image's own label is
the record, so a missed or failed run costs nothing but a day.

## Licence

AGPL-3.0-or-later. The image contains Anki's binary under the same licence — see
[NOTICE](NOTICE) for what that means and where the source is.
