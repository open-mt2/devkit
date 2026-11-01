# syntax=docker/dockerfile:1.7
# ======================================================
# OpenMT2 client - Docker development kit
# ======================================================
#
# Thin layer on top of the published toolchain base (dockerfile.base): it only
# adds the workspace scaffolding and fetches sources/assets, so ordinary
# rebuilds do not reinstall the toolchain or recompile the Windows deps.
#
#   docker build -f dockerfile.base -t ghcr.io/open-mt2/devkit-base:bookworm .
#   docker build -f dockerfile -t openmt2/client .
#
# Override DEVKIT_BASE to use a locally built base image.

ARG DEVKIT_BASE=ghcr.io/open-mt2/devkit-base:bookworm
FROM ${DEVKIT_BASE}

LABEL org.opencontainers.image.title="OpenMT2 Client Development Kit"
LABEL org.opencontainers.image.description="Build and package the OpenMT2 client"
LABEL org.opencontainers.image.source="https://github.com/open-mt2/client"
LABEL org.opencontainers.image.licenses="GPL-2.0-or-later"

SHELL ["/bin/bash", "-euxo", "pipefail", "-c"]

# ---------------------------------------------------------------------------
# Workspace scaffolding
# ---------------------------------------------------------------------------
WORKDIR /workspace

COPY docker/root/CMakeLists.txt /workspace/CMakeLists.txt
COPY docker/root/cmake/Platform.cmake /workspace/cmake/Platform.cmake
COPY scripts/ /workspace/scripts/
COPY treecache/ /workspace/treecache/
COPY docker/entrypoint.sh /usr/local/bin/openmt2-entrypoint

RUN chmod +x /workspace/scripts/*.sh /usr/local/bin/openmt2-entrypoint \
    && cp /workspace/scripts/build.sh /workspace/build.sh \
    && chmod +x /workspace/build.sh

# ---------------------------------------------------------------------------
# Client packages (src/<Package>)
# ---------------------------------------------------------------------------
ARG SRC_ORG=open-mt2
ARG SRC_REF=main
ARG SRC_CACHE_BUST=0
RUN echo "[sources] source cache bust: ${SRC_CACHE_BUST}" \
    && SRC_ORG="${SRC_ORG}" SRC_REF="${SRC_REF}" /workspace/scripts/fetch-sources.sh /workspace

# ---------------------------------------------------------------------------
# Original client assets (bin/)
# ---------------------------------------------------------------------------
ARG WITH_BIN=1
ARG BIN_REF=master
ARG BIN_REPO_URL=https://git.old-metin2.com/metin2/client.git
ARG BIN_ARCHIVE_URL=
ARG BIN_REQUIRED=0
RUN if [ "${WITH_BIN}" = "1" ]; then \
    BIN_REF="${BIN_REF}" \
    BIN_REPO_URL="${BIN_REPO_URL}" \
    BIN_ARCHIVE_URL="${BIN_ARCHIVE_URL}" \
    BIN_REQUIRED="${BIN_REQUIRED}" \
    /workspace/scripts/fetch-bin.sh /workspace; \
    else \
    echo "Skipping bin/ fetch (WITH_BIN=${WITH_BIN})"; \
    fi

# ---------------------------------------------------------------------------
# Tree geometry cache
#
# treecache/ is vendored in this repository (see treecache/README.md) and is
# copied into the image in the scaffolding stage above. It was generated once
# with open-mt2/speedtreebkr from bin/pack/**/*.spt; the image build never
# compiles the dumper and never runs Wine. Verify the manifest and, when bin/
# was fetched, that every .spt still has a matching cache entry.
# ---------------------------------------------------------------------------
RUN python3 /workspace/scripts/verify-treecache.py \
    --treecache /workspace/treecache --bin /workspace/bin

# ---------------------------------------------------------------------------
# Runtime
# ---------------------------------------------------------------------------
ENV OPENMT2_WORKSPACE=/workspace
ENV LD_LIBRARY_PATH=/usr/local/lib

WORKDIR /workspace

ENTRYPOINT ["/usr/local/bin/openmt2-entrypoint"]
CMD []
