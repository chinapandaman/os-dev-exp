FROM debian:bookworm

ARG TARGET=i686-elf
ARG PREFIX=/opt/cross
ARG BINUTILS_VERSION=2.46.0
ARG GCC_VERSION=16.1.0

ENV PATH="${PREFIX}/bin:${PATH}"

# Build dependencies for the OSDev GCC cross-compiler guide.
# libisl-dev is optional, but GCC can use it when available.
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

WORKDIR /tmp/src

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

WORKDIR /tmp/src

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

WORKDIR /workspace

CMD ["bash"]
