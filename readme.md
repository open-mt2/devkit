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
| `fetch`                    | Refresh sources and `bin/` assets   |
| `shell`                    | Interactive shell in the workspace  |
| `help`                     | Show usage                          |

```bash
# Build the client
docker run --rm -v "$PWD/dist:/workspace/dist" openmt2/client build --clean

# Build the client without packs
docker run --rm -v "$PWD/dist:/workspace/dist" openmt2/client build --skip-pack

# Build against an installed Neoeter package
docker run --rm -v "$PWD/dist:/workspace/dist" -v "/path/to/neoeter:/opt/neoeter" \
    openmt2/client build --neoeter-prefix /opt/neoeter

# Fetch the external client files
docker run --rm -it openmt2/client fetch
```

## Build arguments

```
WITH_BIN: Fetch external game assets (required to build a full client)
BIN_REF: Branch used for BIN
BIN_REPO_URL: Alternative asset repository (Defaults link to old-metin2 files)
```

## Links

- [OpenMT2 documentation](https://github.com/open-mt2/docs)
