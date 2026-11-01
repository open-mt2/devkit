# syntax=docker/dockerfile:1.7
# ======================================================
# OpenMT2 client - Docker development kit
# ======================================================

ARG BASE_IMAGE=debian:bookworm
FROM ${BASE_IMAGE}

LABEL org.opencontainers.image.title="OpenMT2 Client Development Kit"
LABEL org.opencontainers.image.description="Build, package and bake the OpenMT2 client"
LABEL org.opencontainers.image.source="https://github.com/open-mt2/client"
LABEL org.opencontainers.image.licenses="GPL-2.0-or-later"

SHELL ["/bin/bash", "-euxo", "pipefail", "-c"]

ARG DEBIAN_FRONTEND=noninteractive
ENV DEBIAN_FRONTEND=noninteractive
ENV LANG=C.UTF-8
ENV LC_ALL=C.UTF-8
ENV PYTHONUNBUFFERED=1

# ---------------------------------------------------------------------------
# Toolchain and native dependencies
# ---------------------------------------------------------------------------
RUN dpkg --add-architecture i386 \
    && apt-get update \
    && apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    git \
    openssh-client \
    xz-utils \
    unzip \
    zip \
    p7zip-full \
    msitools \
    build-essential \
    cmake \
    ninja-build \
    pkg-config \
    libc6-dev-i386 \
    python3 \
    zlib1g-dev \
    libbz2-dev \
    libreadline-dev \
    libsqlite3-dev \
    libffi-dev \
    liblzo2-dev \
    libjpeg-dev \
    libsdl2-dev \
    libfreetype-dev \
    libgl-dev \
    libegl-dev \
    libglu1-mesa-dev \
    libzip-dev \
    libdevil-dev \
    libasound2-dev \
    gcc-mingw-w64-i686 \
    gcc-mingw-w64-x86-64 \
    g++-mingw-w64-x86-64 \
    wine \
    wine32 \
    wine64 \
    libwine-dev:i386 \
    && rm -rf /var/lib/apt/lists/*

RUN cmake --version \
    && python3 --version

# ---------------------------------------------------------------------------
# Python 2.7 (required by pkg_scriptlib / pkg_eterpythonlib)
# ---------------------------------------------------------------------------
ARG PYTHON27_VERSION=2.7.18
RUN curl -fsSL "https://www.python.org/ftp/python/${PYTHON27_VERSION}/Python-${PYTHON27_VERSION}.tgz" \
    -o /tmp/python27.tgz \
    && tar -xzf /tmp/python27.tgz -C /tmp \
    && cd "/tmp/Python-${PYTHON27_VERSION}" \
    && ./configure --prefix=/usr/local --enable-shared --enable-unicode=ucs4 --with-ensurepip=no \
    && make -j"$(nproc)" \
    && make altinstall \
    && printf '/usr/local/lib\n' > /etc/ld.so.conf.d/python2.7.conf \
    && ldconfig \
    && rm -rf "/tmp/Python-${PYTHON27_VERSION}" /tmp/python27.tgz \
    && python2.7 -c 'import sys; print(sys.version)'

# ---------------------------------------------------------------------------
# miniaudio (header-only, exposed as a static library through pkg-config)
# ---------------------------------------------------------------------------
ARG MINIAUDIO_VERSION=0.11.25
RUN mkdir -p /usr/local/include/miniaudio /usr/local/lib/pkgconfig \
    && curl -fsSL "https://raw.githubusercontent.com/mackron/miniaudio/${MINIAUDIO_VERSION}/miniaudio.h" \
    -o /usr/local/include/miniaudio/miniaudio.h \
    && printf '#define MINIAUDIO_IMPLEMENTATION\n#include <miniaudio/miniaudio.h>\n' > /tmp/miniaudio.c \
    && cc -O2 -fPIC -I/usr/local/include -c /tmp/miniaudio.c -o /tmp/miniaudio.o \
    && ar rcs /usr/local/lib/libminiaudio.a /tmp/miniaudio.o \
    && printf '%s\n' \
    'prefix=/usr/local' \
    'exec_prefix=${prefix}' \
    'libdir=${exec_prefix}/lib' \
    'includedir=${prefix}/include' \
    '' \
    'Name: miniaudio' \
    'Description: Single-file audio playback and capture library' \
    "Version: ${MINIAUDIO_VERSION}" \
    'Cflags: -I${includedir}' \
    'Libs: -L${libdir} -lminiaudio' \
    'Libs.private: -lpthread -ldl -lm' \
    > /usr/local/lib/pkgconfig/miniaudio.pc \
    && rm -f /tmp/miniaudio.c /tmp/miniaudio.o \
    && ldconfig \
    && pkg-config --modversion miniaudio

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
# Windows cross-build dependency set (T2.3)
# ---------------------------------------------------------------------------
ARG WIN64_DEPS_PREFIX=/opt/openmt2/win64
RUN /workspace/scripts/build-windows-deps.sh --prefix "${WIN64_DEPS_PREFIX}" --work /tmp/openmt2-win64-deps \
    && rm -rf /tmp/openmt2-win64-deps
RUN /workspace/scripts/fetch-windows-python.sh --prefix "${WIN64_DEPS_PREFIX}" --work /tmp/openmt2-win64-python \
    && rm -rf /tmp/openmt2-win64-python

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
# ---------------------------------------------------------------------------
ARG WITH_SPEEDTREE=1
ARG SPEEDTREE_REF=main
ARG BUILD_SPEEDTREE_DUMPER=1
RUN if [ "${WITH_SPEEDTREE}" = "1" ]; then \
    SPEEDTREE_REF="${SPEEDTREE_REF}" /workspace/scripts/bake-trees.sh --fetch-only; \
    if [ "${BUILD_SPEEDTREE_DUMPER}" = "1" ]; then \
    /workspace/scripts/bake-trees.sh --build-only; \
    fi; \
    else \
    echo "Skipping speedtree baker (WITH_SPEEDTREE=${WITH_SPEEDTREE})"; \
    fi

ARG BAKE_TREES=0
RUN if [ "${BAKE_TREES}" = "1" ]; then \
    /workspace/scripts/bake-trees.sh --force \
    || echo "warning: tree baking failed; treecache/ will be empty"; \
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
