FROM debian:bookworm

# Build dependencies for the OSDev GCC cross-compiler guide.
# libisl-dev is optional, but GCC can use it when available.
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
    bison \
    build-essential \
    flex \
    libgmp3-dev \
    libisl-dev \
    libmpc-dev \
    libmpfr-dev \
    texinfo \
    && rm -rf /var/lib/apt/lists/*
