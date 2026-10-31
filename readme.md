# OpenMT2 Devkit

## Requirements

- Docker (BuildKit enabled, which is the default)
- Git, for local development

## How it works

The repository contains no game code. The Docker image assembles a complete
client workspace from the OpenMT2 projects:

- every `pkg_*` repository from
  [github.com/orgs/open-mt2](https://github.com/orgs/open-mt2/repositories) is
  cloned into `src/<Package>/`;
- the original client assets (`bin/`) are fetched from
  [git.old-metin2.com](https://git.old-metin2.com/metin2/client/src/branch/master/bin)
  when reachable;
- [speedtreebkr](https://github.com/open-mt2/speedtreebkr) is placed in
  `tools/speedtree_baker/` and its 32-bit dumper is built;
- the build scripts from `scripts/` are installed at the workspace root.

Starting the image immediately builds the client and assembles `dist/`.

## Build the image

```bash
docker build -f dockerfile -t openmt2/client .
```

The default image includes the full `bin/` asset tree (~2.3 GB) and therefore
takes a while to build. For a code-only image:

```bash
docker build -f dockerfile \
  --build-arg WITH_BIN=0 \
  --build-arg BAKE_TREES=0 \
  -t openmt2/client:slim .
```

Useful build arguments:

| Argument                 | Default               | Purpose                                      |
| ------------------------ | --------------------- | -------------------------------------------- |
| `BASE_IMAGE`             | `debian:bookworm`     | Base image                                   |
| `PKG_ORG` / `PKG_REF`    | `open-mt2` / `main`   | Source organization and branch               |
| `WITH_BIN`               | `1`                   | Fetch the original `bin/` assets             |
| `BIN_REF`                | `master`              | Branch used for `bin/`                       |
| `BIN_REPO_URL`           | old-metin2 Gitea repo | Alternative asset repository                 |
| `BIN_ARCHIVE_URL`        | empty                 | Optional `tar.gz`/`zip` asset archive        |
| `BIN_REQUIRED`           | `0`                   | Fail the build when no assets can be fetched |
| `WITH_SPEEDTREE`         | `1`                   | Fetch `speedtreebkr`                         |
| `BUILD_SPEEDTREE_DUMPER` | `1`                   | Build `speedtree_dumper.exe` under Wine      |
| `BAKE_TREES`             | `0`                   | Bake `treecache/` during image build         |

## Compile and package

With no arguments the entrypoint runs `build.sh`:

```bash
docker run --rm -v "$PWD/dist:/workspace/dist" openmt2/client
```

`build.sh` options are forwarded:

```bash
# Fast rebuild without re-zipping the packs
docker run --rm -v "$PWD/dist:/workspace/dist" openmt2/client --skip-pack

# Clean build and run the CTest suites
docker run --rm -v "$PWD/dist:/workspace/dist" openmt2/client --clean -t
```

The resulting package is written to the mounted `dist/` directory:
`metin2client`, the asset directories, and `pack/*.zip`.

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

Build both targets side by side and compare them:

```bash
OPENMT2_DIST_DIR=dist-linux  docker run ... openmt2/client --skip-pack
OPENMT2_DIST_DIR=dist-windows docker run ... openmt2/client windows --skip-pack
python3 scripts/dist-diff.py dist-linux dist-windows
```

Keep the C++ runtime DLLs and the Python runtime next to the executable when
copying `dist/` to a Windows machine.

## Smoke test

`scripts/smoke.sh` boots a packaged tree under Xvfb (and Wine for the Windows
build), screenshots it and fails on crashes, fatal `syserr.txt` lines or a
blank screen:

```bash
docker run --rm --tmpfs /tmp/smoke-home:size=2g,mode=1777,uid=1000,gid=1000 \
  -v "$PWD/scripts:/workspace/scripts" \
  -v "$PWD/dist:/workspace/dist" \
  -v "$PWD/smoke-artifacts:/workspace/smoke-artifacts" \
  openmt2/client shell bash /workspace/scripts/smoke.sh linux --home /tmp/smoke-home
```

Use `windows` instead of `linux` for the cross-built tree; `--reference PNG`
compares the captured screenshot with `scripts/render-diff.py`.

## Other commands

```bash
# Interactive shell in the prepared workspace
docker run --rm -it openmt2/client shell

# Refresh pkg_* sources and bin/ inside a container
docker run --rm -it openmt2/client fetch

# Build the SpeedTree dumper and bake treecache/
docker run --rm -v "$PWD/treecache:/workspace/treecache" openmt2/client bake --force

# Help
docker run --rm openmt2/client help
```

## Platform parity

There is one pipeline for both targets: the image builds Linux natively and
cross-builds Windows with MinGW-w64, and both run the same CMake project,
renderer (OpenGL compatibility via SDL2), Python 2.7 runtime and packaging
scripts. The differences are limited to the binary itself, the runtime
libraries and platform extension modules; `scripts/dist-diff.py` enforces that.

Current state (see `docs/planning/windows-parity-tasks.md` for the live sheet):

- both targets compile, link and boot to the login flow (`scripts/smoke.sh`);
- `metin2client.exe` has no DirectX SDK dependency and no unresolved `gl*`;
- the legacy MSVC `build.bat` path is retired;
- IME/text input is still Linux-incomplete (T1.6) and the Windows login
  background scene is black (tracked with the Wave 5 renderer work).

## Related links

- [OpenMT2 documentation](https://github.com/open-mt2/docs)
- [Client packages](https://github.com/orgs/open-mt2/repositories?q=pkg_)
