# syntax=docker/dockerfile:1.7
# ======================================================
# OpenMT2 client - complete Docker development kit
# ======================================================
#
# The image assembles the reference client workspace:
#
#   /workspace
#   ├── CMakeLists.txt              root project (docker/root/CMakeLists.txt)
#   ├── build.sh                    build + dist packaging entrypoint
#   ├── build.bat                   Windows equivalent
#   ├── cmake/Platform.cmake        compiler/platform flags
#   ├── scripts/                    fetch/build/bake helpers
#   ├── src/<Package>/              every pkg_* repository
#   ├── bin/                        original client assets (when available)
#   ├── tools/speedtree_baker/      SpeedTree geometry baker
#   └── treecache/                  baked SpeedTree geometry (optional)
#
# Starting the image runs build.sh immediately. See docker/entrypoint.sh.

ARG BASE_IMAGE=debian:bookworm
FROM ${BASE_IMAGE}

LABEL org.opencontainers.image.title="OpenMT2 Client Development Kit"
LABEL org.opencontainers.image.description="Build, package and bake the OpenMT2 Linux client"
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
# i386 is enabled only for Wine's 32-bit support, which the SpeedTree dumper
# needs in order to call the original PE32 SpeedTreeRT.dll.
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
        xvfb \
        libgl1-mesa-dri \
        clang \
        lld \
        gcc-mingw-w64-i686 \
        g++-mingw-w64-x86-64 \
        wine \
        wine32 \
        libwine-dev:i386 \
    && rm -rf /var/lib/apt/lists/*

RUN cmake --version \
    && python3 --version \
    && clang --version | head -n 1

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
COPY cmake/toolchain-i686-windows-gnu.cmake /workspace/cmake/toolchain-i686-windows-gnu.cmake
COPY CMakePresets.json /workspace/CMakePresets.json
COPY scripts/ /workspace/scripts/
COPY docker/entrypoint.sh /usr/local/bin/openmt2-entrypoint

RUN chmod +x /workspace/scripts/*.sh /usr/local/bin/openmt2-entrypoint \
    && cp /workspace/scripts/build.sh /workspace/build.sh \
    && cp /workspace/scripts/build.bat /workspace/build.bat \
    && chmod +x /workspace/build.sh

# ---------------------------------------------------------------------------
# Client packages (src/<Package>)
# ---------------------------------------------------------------------------
ARG PKG_ORG=open-mt2
ARG PKG_REF=main
# Changing this value (CI passes the run id) invalidates the source layer, so a
# cached image never pins stale package commits.
ARG PKG_CACHE_BUST=0
RUN echo "[packages] source cache bust: ${PKG_CACHE_BUST}" \
    && PKG_ORG="${PKG_ORG}" PKG_REF="${PKG_REF}" /workspace/scripts/fetch-packages.sh /workspace

# ---------------------------------------------------------------------------
# Original client assets (bin/)
# ---------------------------------------------------------------------------
# Access to git.old-metin2.com may be unavailable. A failure is non-fatal: the
# C++ client still compiles, and assets can be mounted or fetched later with
#   docker run ... fetch
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

# Optionally bake treecache/ during the image build. Disabled by default: it
# needs bin/SpeedTreeRT.dll and Wine, and adding ~100 small cache files to the
# image is better controlled by the image consumer.
ARG BAKE_TREES=0
RUN if [ "${BAKE_TREES}" = "1" ]; then \
        /workspace/scripts/bake-trees.sh --force \
        || echo "warning: tree baking failed; treecache/ will be empty"; \
    fi

# ---------------------------------------------------------------------------
# Fuzzing support (TA.3)
# ---------------------------------------------------------------------------
# Debian's `clang` package does not pull compiler-rt, so -fsanitize=fuzzer and
# -fsanitize=address fail at link time without this.
RUN apt-get update \
    && apt-get install -y --no-install-recommends libclang-rt-14-dev \
    && rm -rf /var/lib/apt/lists/*

# ---------------------------------------------------------------------------
# Runtime
# ---------------------------------------------------------------------------
ENV OPENMT2_WORKSPACE=/workspace
ENV LD_LIBRARY_PATH=/usr/local/lib
ENV WINEDEBUG=-all
ENV WINEDLLOVERRIDES=mscoree,mshtml=

# Keep the packaged client reproducible and easy to export.
WORKDIR /workspace

ENTRYPOINT ["/usr/local/bin/openmt2-entrypoint"]
CMD []
