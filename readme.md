# OpenMT2 Devkit

Docker image with the OpenMT2 client toolchain, sources, build scripts and the
vendored tree geometry cache. It does not build anything on start; run the
`build` command when ready.

## Requirements

- Docker (BuildKit)
- Git

## Commands

| Command                    | Purpose                             |
| -------------------------- | ----------------------------------- |
| `build [build.sh options]` | Compile and assemble `dist/openmt2` |
| `windows [options]`        | Cross-build the Windows client      |
| `pack [entry ...]`         | Repack `dist/pack` archives         |
| `fetch`                    | Refresh sources and `bin/` assets   |
| `shell`                    | Interactive shell in the workspace  |
| `help`                     | Show usage                          |

```bash
# Build the client
docker run --rm -v "$PWD/dist:/workspace/dist" openmt2/devkit build --clean

# Build the client without packs
docker run --rm -v "$PWD/dist:/workspace/dist" openmt2/devkit build --skip-pack

# Build against an installed Neoeter package
docker run --rm -v "$PWD/dist:/workspace/dist" -v "/path/to/neoeter:/opt/neoeter" \
    openmt2/devkit build --neoeter-prefix /opt/neoeter

# Fetch the external client files
docker run --rm -it openmt2/devkit fetch

# Fetch a specific branch, tag or commit per repository
docker run --rm -v "$PWD/src:/workspace/src" openmt2/devkit fetch \
    --ref client=3f2a1b9c4d5e6f708192a3b4c5d6e7f8091a2b3c \
    --ref neoeter=v0.4.1

# Fetch all repositories and record the resolved commit hashes
docker run --rm -v "$PWD/src:/workspace/src" openmt2/devkit fetch \
    --write-lock src/sources.lock

# Build against the fetched sources
docker run --rm -v "$PWD/src:/workspace/src" -v "$PWD/dist:/workspace/dist" \
    openmt2/devkit build --clean

# Repack one archive (matches Index names case-insensitively)
docker run --rm -v "$PWD/dist:/workspace/dist" openmt2/devkit pack ETC

# Repack several archives
docker run --rm -v "$PWD/dist:/workspace/dist" openmt2/devkit pack bgm sound

# Regenerate every archive in dist/pack/
docker run --rm -v "$PWD/dist:/workspace/dist" openmt2/devkit pack
```

`--ref` accepts `neoeter`, `neoeter-python` and `client`. Refs can be branches,
tags or full 40-character commit hashes. Commit hashes can also be provided per
repository through `SRC_REF_CLIENT`, `SRC_REF_NEOETER` and
`SRC_REF_NEOETER_PYTHON`; `SRC_REF` remains the default for every repository.

## Manual packs

`pack` reads the unpacked asset directories from `bin/pack/`, packs the ones
named on the command line (or every entry in `bin/pack/Index` when none are
given) and replaces only the corresponding `dist/pack/<name>.zip` files. An
entry name that does not appear in `Index` is an error.

Mount `bin/pack` as well when the assets were changed on the host:

```bash
docker run --rm -v "$PWD/bin/pack:/workspace/bin/pack" \
    -v "$PWD/dist:/workspace/dist" openmt2/devkit pack ETC
```


## Build arguments

```
WITH_BIN: Fetch external game assets (required to build a full client)
BIN_REF: Branch used for BIN
BIN_REPO_URL: Alternative asset repository (Defaults link to old-metin2 files)
```

## Links

- [OpenMT2 documentation](https://github.com/open-mt2/docs)
