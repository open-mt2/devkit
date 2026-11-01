# OpenMT2 Devkit

## Requirements

- Docker (BuildKit enabled, which is the default)
- Git, for local development

## How it works

The repository contains no game code. The Docker image assembles a complete
client workspace from the OpenMT2 projects:

- the original client assets (`bin/`) are fetched from
  [git.old-metin2.com](https://git.old-metin2.com/metin2/client/src/branch/master/bin)
  when reachable;
- the build scripts from `scripts/` are installed at the workspace root.

The image does not build anything on start. It ships the toolchain, sources and
build scripts; run the build yourself when you are ready.

## Build the image

The devkit is built from two images:

- **toolchain base** (`dockerfile.base`) — Debian build dependencies, CPython
  2.7, miniaudio and the Windows cross-build dependency set. It only depends on
  the recipes, so it changes rarely and is published as
  `ghcr.io/open-mt2/devkit-base:bookworm`.
- **client image** (`dockerfile`) — `FROM` the base plus the workspace
  scaffolding, sources, optional `bin/` assets and the SpeedTree baker.

Pulling the published base is enough to build the client:

```bash
docker pull ghcr.io/open-mt2/devkit-base:bookworm
docker build -f dockerfile -t openmt2/client .
```

To build the base locally instead (or after changing `dockerfile.base`):

```bash
docker build -f dockerfile.base -t ghcr.io/open-mt2/devkit-base:bookworm .
docker build -f dockerfile -t openmt2/client .
```

The default client image includes the full `bin/` asset tree (~2.3 GB) and
therefore takes a while to build. For a code-only image:

```bash
docker build -f dockerfile \
  --build-arg WITH_BIN=0 \
  --build-arg BAKE_TREES=0 \
  -t openmt2/client:slim .
```

Base image arguments (`dockerfile.base`):

| Argument               | Default           | Purpose                                      |
| ---------------------- | ----------------- | -------------------------------------------- |
| `BASE_IMAGE`           | `debian:bookworm` | Debian base image                            |
| `PYTHON27_VERSION`     | `2.7.18`          | CPython built into the base                  |
| `MINIAUDIO_VERSION`    | `0.11.25`         | miniaudio header version                     |
| `WIN64_DEPS_PREFIX`    | `/opt/openmt2/win64` | Windows cross-dependency prefix           |

Client image arguments (`dockerfile`):

| Argument                 | Default               | Purpose                                      |
| ------------------------ | --------------------- | -------------------------------------------- |
| `DEVKIT_BASE`            | `ghcr.io/open-mt2/devkit-base:bookworm` | Toolchain base image |
| `SRC_ORG` / `SRC_REF`    | `open-mt2` / `main`   | Source organization and branch               |
| `WITH_BIN`               | `1`                   | Fetch the original `bin/` assets             |
| `BIN_REF`                | `master`              | Branch used for `bin/`                       |
| `BIN_REPO_URL`           | old-metin2 Gitea repo | Alternative asset repository                 |
| `BIN_ARCHIVE_URL`        | empty                 | Optional `tar.gz`/`zip` asset archive        |
| `BIN_REQUIRED`           | `0`                   | Fail the build when no assets can be fetched |
| `WITH_SPEEDTREE`         | `1`                   | Fetch `speedtreebkr`                         |
| `BUILD_SPEEDTREE_DUMPER` | `0`                   | Install/compile `speedtree_dumper.exe`       |
| `SPEEDTREE_DUMPER`       | empty                 | Path to a prebuilt `speedtree_dumper.exe`    |
| `SPEEDTREE_DUMPER_URL`   | empty                 | Download URL for the prebuilt dumper         |
| `BAKE_TREES`             | `0`                   | Bake `treecache/` during image build         |

The base is rebuilt by `.github/workflows/base.yml` on every change to
`dockerfile.base`, `scripts/build-windows-deps.sh` or
`scripts/fetch-windows-python.sh`; run it manually with
`gh workflow run base`. Use the dated tag (`:bookworm-YYYYMMDD`) or a digest if
you need a pinned base.

## Published image

Pushing a version tag publishes the image to the GitHub Container Registry:

```bash
git tag v0.1.0
git push origin v0.1.0
```

This builds and pushes `ghcr.io/open-mt2/client:v0.1.0` and updates `:latest`.
Only tags matching `vX.Y.Z` (optionally with a prerelease suffix) are published.

The published image is **source-only**: it contains the OpenMT2 sources, the
toolchain and the build scripts, but not the original client `bin/` tree, the
`pack/` archives or a baked `treecache/`. Fetch those into a container with
`docker run ... fetch` from your own asset source; the publish job refuses to
push an image that contains them.

The SpeedTree dumper is **not compiled during the image build by default**.
`speedtreebkr`'s toolchain requires `clang`/`lld`, which the build-only image no
longer ships ([devkit#143](https://github.com/open-mt2/devkit/issues/143)).
Two paths exist:

- point `SPEEDTREE_DUMPER_URL` at the release asset from
  [speedtreebkr#1](https://github.com/open-mt2/speedtreebkr/issues/1) (or set
  `SPEEDTREE_DUMPER` to a local path) and pass
  `--build-arg BUILD_SPEEDTREE_DUMPER=1`; or
- set `BUILD_SPEEDTREE_DUMPER=1` without a prebuilt dumper to compile it,
  which requires `clang` + `lld` in the image.

No `.spt` files or baked tree data are included. `scripts/bake-trees.sh` reads
`SPEEDTREE_DUMPER` / `SPEEDTREE_DUMPER_URL` at build and at run time, so the
published image can download the dumper and bake without a rebuild.

## Compile and package

Run the `build` command explicitly (no arguments just prints the usage):

```bash
docker run --rm -v "$PWD/dist:/workspace/dist" openmt2/client build
```

`build.sh` options are forwarded:

```bash
# Fast rebuild without re-zipping the packs
docker run --rm -v "$PWD/dist:/workspace/dist" openmt2/client build --skip-pack

# Clean build
docker run --rm -v "$PWD/dist:/workspace/dist" openmt2/client build --clean
```

The resulting package is written to the mounted `dist/` directory:
`metin2client`, the asset directories, and `pack/*.zip`.

The Linux package is self-contained: `dist/runtime/` holds the non-system
libraries the client links (`libzip.so.4`, `libpython2.7.so.1.0`) and
`dist/lib/` holds the CPython 2.7 standard library. The executable resolves
`runtime/` relative to its own location, so it must be run from `dist/` but
does not need `LD_LIBRARY_PATH` or host Python 2.7 packages.

## Cross-build for Windows

The same image cross-compiles the client with MinGW-w64 (no Windows host or
DirectX SDK needed):

```bash
docker run --rm \
  --user "$(id -u):$(id -g)" -e HOME=/tmp \
  -v "$PWD/src:/workspace/src" \
  -v "$PWD/build:/workspace/build" \
  -v "$PWD/dist:/workspace/dist" \
  openmt2/client windows
```

`windows` accepts the same `-j/--jobs`, `--clean` and `--skip-pack` options.
The tree mirrors the Linux package: same assets, same `pack/*.zip` archives,
plus `metin2client.exe` and its runtime DLLs (`python27.dll`, `msvcr90.dll`,
`libstdc++-6.dll`, `libgcc_s_seh-1.dll`). SDL2 is linked statically.

Build both targets side by side:

```bash
OPENMT2_DIST_DIR=dist-linux   docker run ... openmt2/client build --skip-pack
OPENMT2_DIST_DIR=dist-windows docker run ... openmt2/client windows --skip-pack
```

Keep the C++ runtime DLLs and the Python runtime next to the executable when
copying `dist/` to a Windows machine.

## Other commands

```bash
# Interactive shell in the prepared workspace
docker run --rm -it openmt2/client shell

# Refresh pkg_* sources and bin/ inside a container
docker run --rm -it openmt2/client fetch

# Bake treecache/ (needs a dumper: --build-arg SPEEDTREE_DUMPER_URL=... at
# image build time, or -e SPEEDTREE_DUMPER_URL=... here)
docker run --rm -e SPEEDTREE_DUMPER_URL="<release asset URL>" \
  -v "$PWD/treecache:/workspace/treecache" openmt2/client bake --force

# Help
docker run --rm openmt2/client help
```

## Related links

- [OpenMT2 documentation](https://github.com/open-mt2/docs)
- [Client packages](https://github.com/orgs/open-mt2/repositories?q=pkg_)
