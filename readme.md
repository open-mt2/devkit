# OpenMT2 Devkit

Docker image with the OpenMT2 client toolchain, sources, build scripts and the
vendored tree geometry cache. It does not build anything on start; run the
`build` command when ready.

## Requirements

- Docker (BuildKit)
- Git

## Quick start

```bash
# Pull the published toolchain base and build the client image
docker pull ghcr.io/open-mt2/devkit-base:bookworm
docker build -f dockerfile -t openmt2/client .

# Compile and assemble dist/
docker run --rm -v "$PWD/dist:/workspace/dist" openmt2/client build
```

Code-only image without the ~2.3 GB `bin/` asset tree:

```bash
docker build -f dockerfile --build-arg WITH_BIN=0 -t openmt2/client:slim .
```

Rebuild the base locally (it is built and published manually; there is no CI
job for it):

```bash
docker build -f dockerfile.base -t ghcr.io/open-mt2/devkit-base:bookworm .
docker build -f dockerfile -t openmt2/client .
```

## Commands

| Command | Purpose |
| --- | --- |
| `build [build.sh options]` | Compile and assemble `dist/` |
| `windows [options]` | Cross-build the Windows client |
| `fetch` | Refresh `pkg_*` sources and `bin/` assets |
| `shell` | Interactive shell in the workspace |
| `help` | Show usage |

```bash
docker run --rm -v "$PWD/dist:/workspace/dist" openmt2/client build --clean
docker run --rm -v "$PWD/dist:/workspace/dist" openmt2/client build --skip-pack
docker run --rm -it openmt2/client fetch
docker run --rm --entrypoint python3 openmt2/client \
  scripts/verify-treecache.py --bin bin --strict
```

## Build arguments

| Argument | Default | Purpose |
| --- | --- | --- |
| `DEVKIT_BASE` | `ghcr.io/open-mt2/devkit-base:bookworm` | Toolchain base image |
| `SRC_ORG` / `SRC_REF` | `open-mt2` / `main` | Source organization and branch |
| `WITH_BIN` | `1` | Fetch the original `bin/` assets |
| `BIN_REF` | `master` | Branch used for `bin/` |
| `BIN_REPO_URL` | old-metin2 Gitea repo | Alternative asset repository |
| `BIN_ARCHIVE_URL` | empty | Optional asset archive |
| `BIN_REQUIRED` | `0` | Fail when no assets can be fetched |

## Tree geometry cache

`treecache/` is vendored in this repository and copied into the image;
`build.sh` copies it to `dist/treecache/`. Normal builds do not compile the
SpeedTree dumper and do not need Wine, `clang` or `lld`.

Regenerate it with [speedtreebkr](https://github.com/open-mt2/speedtreebkr)
when adding or editing trees; see [`treecache/README.md`](treecache/README.md).

## Published image

Tagging pushes `ghcr.io/open-mt2/client`. The image contains the sources, the
toolchain, the build scripts and `treecache/`; it does not contain `bin/`, the
pack archives or `dist/`.

## Links

- [OpenMT2 documentation](https://github.com/open-mt2/docs)
- [Client packages](https://github.com/orgs/open-mt2/repositories?q=pkg_)
