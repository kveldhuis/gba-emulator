FROM debian:bookworm-slim

ARG ZIG_VERSION=0.15.2
ARG ZIG_DIR=/opt/zig

RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    xz-utils \
 && rm -rf /var/lib/apt/lists/*

RUN mkdir -p /tmp/zig \
 && curl -L https://ziglang.org/download/${ZIG_VERSION}/zig-x86_64-linux-${ZIG_VERSION}.tar.xz \
    -o /tmp/zig/zig.tar.xz \
 && mkdir -p ${ZIG_DIR} \
 && tar -xJf /tmp/zig/zig.tar.xz -C ${ZIG_DIR} --strip-components=1 \
 && rm -rf /tmp/zig

ENV PATH="${ZIG_DIR}:${PATH}"

RUN zig version
