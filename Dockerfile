# This image is the "host" build environment: it runs Debian, but it will
# produce tools that generate i686 ELF objects for our future OS.
FROM debian:bookworm

# Build arguments keep the important knobs near the top. They can be
# overridden at build time, for example:
#   docker build --build-arg TARGET=x86_64-elf -t os-dev-exp .
ARG TARGET=i686-elf

# OSDev suggests $HOME/opt/cross for a personal install. Inside a Docker image,
# /opt/cross is a conventional place for a toolchain baked into the image.
ARG PREFIX=/opt/cross

# Pinning versions makes the build reproducible. "Latest" changes over time,
# but these exact source archives should continue to build the same toolchain.
ARG BINUTILS_VERSION=2.46.0
ARG GCC_VERSION=16.1.0

# Put the cross-toolchain first in PATH. This matters while building GCC because
# GCC needs to find the i686-elf assembler/linker that Binutils installs.
ENV PATH="${PREFIX}/bin:${PATH}"

# Build dependencies for the OSDev GCC cross-compiler guide:
# - build-essential gives us the host C/C++ compiler and make.
# - bison/flex are parser-generator tools used by GNU projects.
# - GMP, MPFR, MPC, and optional ISL are math libraries GCC uses internally.
# - wget, ca-certificates, and xz-utils let us fetch and unpack source tarballs.
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
    bison \
    build-essential \
    ca-certificates \
    flex \
    libgmp3-dev \
    libisl-dev \
    libmpc-dev \
    libmpfr-dev \
    texinfo \
    wget \
    xz-utils \
    && rm -rf /var/lib/apt/lists/*

# Build from /tmp/src so source trees and intermediate object files can be
# deleted after installation. Keeping source and build directories separate is
# important for GCC, and is the pattern the OSDev guide recommends.
WORKDIR /tmp/src

# Build Binutils first. GCC's build will later look for i686-elf-as and
# i686-elf-ld, so the assembler/linker need to exist before GCC is configured.
#
# Configure flag notes:
# - --target chooses what kind of binaries these tools produce.
# - --prefix chooses where the resulting toolchain is installed.
# - --with-sysroot prepares the linker for a future target sysroot.
# - --disable-nls avoids native language support and extra dependencies.
# - --disable-werror avoids build failures from warnings in this environment.
RUN wget -q "https://ftp.gnu.org/gnu/binutils/binutils-${BINUTILS_VERSION}.tar.xz" \
    && tar -xf "binutils-${BINUTILS_VERSION}.tar.xz" \
    && mkdir build-binutils \
    && cd build-binutils \
    && "../binutils-${BINUTILS_VERSION}/configure" \
    --target="${TARGET}" \
    --prefix="${PREFIX}" \
    --with-sysroot \
    --disable-nls \
    --disable-werror \
    && make -j"$(nproc)" \
    && make install \
    && rm -rf /tmp/src

# Recreate /tmp/src for the GCC build. This is a separate Docker layer so
# Docker can reuse the Binutils layer if we tweak only the GCC build later.
WORKDIR /tmp/src

# Build the cross GCC. This intentionally does not build a full hosted compiler:
# our target OS does not have libc, system headers, or a runtime yet.
#
# Configure flag notes:
# - --enable-languages=c,c++ builds only the C and C++ frontends.
# - --without-headers tells GCC not to expect target system headers.
# - --disable-hosted-libstdcxx builds a freestanding-friendly C++ library.
#
# Make target notes:
# - all-gcc builds the compiler itself.
# - all-target-libgcc builds libgcc, which GCC expects for low-level helpers.
# - all-target-libstdc++-v3 builds freestanding C++ support.
RUN wget -q "https://ftp.gnu.org/gnu/gcc/gcc-${GCC_VERSION}/gcc-${GCC_VERSION}.tar.xz" \
    && tar -xf "gcc-${GCC_VERSION}.tar.xz" \
    && mkdir build-gcc \
    && cd build-gcc \
    && "../gcc-${GCC_VERSION}/configure" \
    --target="${TARGET}" \
    --prefix="${PREFIX}" \
    --disable-nls \
    --enable-languages=c,c++ \
    --without-headers \
    --disable-hosted-libstdcxx \
    && make -j"$(nproc)" all-gcc \
    && make -j"$(nproc)" all-target-libgcc \
    && make -j"$(nproc)" all-target-libstdc++-v3 \
    && make install-gcc \
    && make install-target-libgcc \
    && make install-target-libstdc++-v3 \
    && rm -rf /tmp/src

# The Makefile mounts this repository at /workspace, so start shells there.
WORKDIR /workspace

# Default to an interactive shell when the image is run without an explicit
# command. The Makefile's dev-shell target relies on this same idea.
CMD ["bash"]
