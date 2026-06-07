FROM mirror.gcr.io/library/golang:1.23 AS go-provider
FROM mirror.gcr.io/library/rust:1.82 AS rust-provider

# Stage 3: Custom Bottlerocket SDK
FROM public.ecr.aws/docker/library/ubuntu:16.04

# Install cross-compilation tools via apt (HTTP-based, accessible)
RUN apt-get update && apt-get install -y \
    gcc-aarch64-linux-gnu \
    g++-aarch64-linux-gnu \
    binutils-aarch64-linux-gnu \
    gcc \
    g++ \
    make \
    pkg-config \
    cmake \
    ninja-build \
    curl \
    ca-certificates \
    file \
    git \
    tar \
    xz-utils \
    gzip \
    bzip2 \
    cpio \
    patch \
    python3 \
    perl \
    rpm \
    && rm -rf /var/lib/apt/lists/*

# Create the bottlerocket cross-compilation sysroot structure
# Map aarch64-bottlerocket-linux-gnu -> aarch64-linux-gnu
RUN mkdir -p /aarch64-bottlerocket-linux-gnu/sys-root && \
    ln -sfn /usr/aarch64-linux-gnu /aarch64-bottlerocket-linux-gnu/sys-root/usr && \
    mkdir -p /aarch64-bottlerocket-linux-gnu/bin

# Create wrapper scripts that translate bottlerocket triplet to standard triplet
RUN for tool in gcc g++ gcc-ar gcc-nm gcc-ranlib cpp ld ld.bfd ld.gold \
                as nm objcopy objdump ranlib strip readelf; do \
      REAL_BIN="/usr/bin/aarch64-linux-gnu-${tool}" ; \
      if [ -f "$REAL_BIN" ] || [ -L "$REAL_BIN" ]; then \
        printf '#!/bin/bash\nexec /usr/bin/aarch64-linux-gnu-%s "$@"\n' "$tool" \
          > /usr/bin/aarch64-bottlerocket-linux-gnu-${tool} && \
        chmod +x /usr/bin/aarch64-bottlerocket-linux-gnu-${tool} ; \
      fi ; \
    done

# gcc-ar needs special handling
RUN if [ -f /usr/bin/aarch64-linux-gnu-gcc-ar ] || [ -L /usr/bin/aarch64-linux-gnu-gcc-ar ]; then \
      printf '#!/bin/bash\nexec /usr/bin/aarch64-linux-gnu-gcc-ar "$@"\n' \
        > /usr/bin/aarch64-bottlerocket-linux-gnu-gcc-ar ; \
    else \
      printf '#!/bin/bash\nexec /usr/bin/aarch64-linux-gnu-ar "$@"\n' \
        > /usr/bin/aarch64-bottlerocket-linux-gnu-gcc-ar ; \
    fi && chmod +x /usr/bin/aarch64-bottlerocket-linux-gnu-gcc-ar

# Verify wrappers exist
RUN ls -la /usr/bin/aarch64-bottlerocket-linux-gnu-gcc \
           /usr/bin/aarch64-bottlerocket-linux-gnu-gcc-ar

# Install Go from the golang Docker image
COPY --from=go-provider /usr/local/go /usr/local/go
ENV PATH="/usr/local/go/bin:${PATH}"
RUN go version

# Install Rust from the rust Docker image (avoids rustup SSL issues)
ENV RUSTUP_HOME=/usr/local/rustup \
    CARGO_HOME=/usr/local/cargo
COPY --from=rust-provider /usr/local/rustup /usr/local/rustup
COPY --from=rust-provider /usr/local/cargo /usr/local/cargo
ENV PATH="/usr/local/cargo/bin:${PATH}"
RUN rustc --version && cargo --version

# Install aarch64-unknown-linux-gnu std library from pre-downloaded archive
# (static.rust-lang.org is accessible from host but blocked inside Docker build)
COPY rust-std-aarch64.tar.xz /tmp/
COPY rust-src.tar.xz /tmp/
RUN TOOLCHAIN=$(ls /usr/local/rustup/toolchains/) && \
    TOOLCHAIN_DIR="/usr/local/rustup/toolchains/${TOOLCHAIN}" && \
    tar -xJf /tmp/rust-std-aarch64.tar.xz -C /tmp/ && \
    cp -a /tmp/rust-std-1.82.0-aarch64-unknown-linux-gnu/rust-std-aarch64-unknown-linux-gnu/lib/rustlib/aarch64-unknown-linux-gnu \
          "${TOOLCHAIN_DIR}/lib/rustlib/" && \
    echo "aarch64-unknown-linux-gnu" >> "${TOOLCHAIN_DIR}/lib/rustlib/components" && \
    tar -xJf /tmp/rust-src.tar.xz -C /tmp/ && \
    cp -a /tmp/rust-src-1.82.0/rust-src/lib/rustlib/src "${TOOLCHAIN_DIR}/lib/rustlib/" && \
    echo "rust-src" >> "${TOOLCHAIN_DIR}/lib/rustlib/components" && \
    rm -rf /tmp/rust-std-1.82.0-aarch64-unknown-linux-gnu /tmp/rust-src-1.82.0 \
           /tmp/rust-std-aarch64.tar.xz /tmp/rust-src.tar.xz && \
    rustup target list --installed

# Create custom Rust target spec for aarch64-bottlerocket-linux-gnu
RUN mkdir -p /usr/local/rust-targets
COPY targets/aarch64-bottlerocket-linux-gnu.json /usr/local/rust-targets/
COPY targets/aarch64-bottlerocket-linux-musl.json /usr/local/rust-targets/
ENV RUST_TARGET_PATH=/usr/local/rust-targets

# Install SDK RPM macros
RUN mkdir -p /usr/lib/rpm/macros.d
COPY macros/ /tmp/sdk-macros/
RUN for f in /tmp/sdk-macros/*; do \
      name=$(basename "$f") ; \
      cp "$f" "/usr/lib/rpm/macros.d/macros.bottlerocket-${name}" ; \
    done

# Set up user for builds (RPM build system often uses non-root)
RUN useradd -m -u 1000 builder
RUN mkdir -p /home/builder/.cargo && \
    chown -R builder:builder /home/builder

# Set PATH for the bottlerocket tools
ENV PATH="/usr/local/cargo/bin:/usr/local/go/bin:/usr/bin:${PATH}"

WORKDIR /home/builder
