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

The Linux package is self-contained: `dist/runtime/` holds the non-system
libraries the client links (`libzip.so.4`, `libpython2.7.so.1.0`) and
`dist/lib/` holds the CPython 2.7 standard library. The executable resolves
`runtime/` relative to its own location, so it must be run from `dist/` but
does not need `LD_LIBRARY_PATH` or host Python 2.7 packages.

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

`scripts/build.sh` is the Linux pipeline. `scripts/build.bat` implements the
same options and `dist/` layout for MSBuild/Windows, including `treecache/`,
pack archive generation, `--clean`, and `--skip-pack`.

## Related links

- [OpenMT2 documentation](https://github.com/open-mt2/docs)
- [Client packages](https://github.com/orgs/open-mt2/repositories?q=pkg_)
