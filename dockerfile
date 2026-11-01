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
LABEL org.opencontainers.image.description="Build, package and bake the OpenMT2 client"
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
# SpeedTree geometry baker
#
# The dumper is not compiled here by default: speedtreebkr's toolchain needs
# clang/lld, which the build-only image no longer ships (devkit#143). Point
# SPEEDTREE_DUMPER_URL at the release asset from open-mt2/speedtreebkr#1 (or
# use SPEEDTREE_DUMPER with a local path) and set BUILD_SPEEDTREE_DUMPER=1 to
# bake the prebuilt dumper into the image; bake-trees.sh falls back to
# compiling only when neither is provided.
# ---------------------------------------------------------------------------
ARG WITH_SPEEDTREE=1
ARG SPEEDTREE_REF=main
ARG BUILD_SPEEDTREE_DUMPER=0
ARG SPEEDTREE_DUMPER=
ARG SPEEDTREE_DUMPER_URL=
RUN if [ "${WITH_SPEEDTREE}" = "1" ]; then \
    export WINEPREFIX=/tmp/openmt2-speedtree-wine WINEDEBUG=-all WINEDLLOVERRIDES=mscoree,mshtml=; \
    export SPEEDTREE_DUMPER="${SPEEDTREE_DUMPER}" SPEEDTREE_DUMPER_URL="${SPEEDTREE_DUMPER_URL}"; \
    SPEEDTREE_REF="${SPEEDTREE_REF}" /workspace/scripts/bake-trees.sh --fetch-only; \
    if [ "${BUILD_SPEEDTREE_DUMPER}" = "1" ]; then \
    /workspace/scripts/bake-trees.sh --build-only; \
    fi; \
    rm -rf /tmp/openmt2-speedtree-wine; \
    else \
    echo "Skipping speedtree baker (WITH_SPEEDTREE=${WITH_SPEEDTREE})"; \
    fi

ARG BAKE_TREES=0
RUN if [ "${BAKE_TREES}" = "1" ]; then \
    ( export WINEPREFIX=/tmp/openmt2-bake-wine WINEDEBUG=-all WINEDLLOVERRIDES=mscoree,mshtml=; \
      export SPEEDTREE_DUMPER="${SPEEDTREE_DUMPER}" SPEEDTREE_DUMPER_URL="${SPEEDTREE_DUMPER_URL}"; \
      /workspace/scripts/bake-trees.sh --force ) \
    || echo "warning: tree baking failed; treecache/ will be empty"; \
    rm -rf /tmp/openmt2-bake-wine; \
    fi

# ---------------------------------------------------------------------------
# Runtime
# ---------------------------------------------------------------------------
ENV OPENMT2_WORKSPACE=/workspace
ENV LD_LIBRARY_PATH=/usr/local/lib
ENV WINEDEBUG=-all
ENV WINEDLLOVERRIDES=mscoree,mshtml=

WORKDIR /workspace

ENTRYPOINT ["/usr/local/bin/openmt2-entrypoint"]
CMD []
