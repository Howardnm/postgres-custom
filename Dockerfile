# 直接使用单阶段构建，确保环境一致性
FROM postgres:17-bookworm

LABEL maintainer="YourName"
LABEL description="Universal PG 17: Rust + pgvectorscale + vector + zhparser + cron"

# 接收构建参数
ARG TARGETARCH

# =================================================================
# 1. 准备环境 (安装后不删除列表，方便后续清理)
# =================================================================
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    postgresql-server-dev-17 \
    make gcc g++ ca-certificates \
    wget tar bzip2 libc6-dev \
    libssl-dev pkg-config clang libclang-dev \
    curl git \
    locales \
    libssl3 libgcc-s1

# 设置中文环境
RUN localedef -i zh_CN -c -f UTF-8 -A /usr/share/locale/locale.alias zh_CN.UTF-8
ENV LANG=zh_CN.utf8

WORKDIR /tmp

# =================================================================
# 2. 编译 C 语言插件
# =================================================================

# [A] SCWS
RUN wget -q -O - http://www.xunsearch.com/scws/down/scws-1.2.3.tar.bz2 | tar xjf - && \
    cd scws-1.2.3 && \
    ./configure --prefix=/usr/local && \
    make && make install && \
    ldconfig

# [B] zhparser
RUN GIT_TERMINAL_PROMPT=0 git clone https://github.com/amutu/zhparser.git && \
    cd zhparser && \
    make && make install

# [C] pg_cron
RUN GIT_TERMINAL_PROMPT=0 git clone https://github.com/citusdata/pg_cron.git && \
    cd pg_cron && \
    make && make install

# =================================================================
# 3. 编译 Rust 语言插件
# =================================================================

ENV RUSTUP_HOME=/usr/local/rustup \
    CARGO_HOME=/usr/local/cargo \
    PATH=/usr/local/cargo/bin:$PATH \
    CARGO_NET_GIT_FETCH_WITH_CLI=true

# [D] 安装 Rust
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --default-toolchain stable && \
    chmod -R a+w $RUSTUP_HOME $CARGO_HOME

# [E] 安装 pgrx (配合 pgvectorscale 0.5.1 使用 0.12.6)
RUN cargo install --locked cargo-pgrx --version 0.12.5 && \
    cargo pgrx init --pg17 /usr/lib/postgresql/17/bin/pg_config

# [F] pgvector (C语言)
RUN GIT_TERMINAL_PROMPT=0 git clone --branch v0.8.1 https://github.com/pgvector/pgvector.git && \
    cd pgvector && \
    make OPTFLAGS="" && \
    make install

# [G] pgvectorscale (Rust语言)
#     0.5.1 版本配合 pgrx 0.12.6
RUN GIT_TERMINAL_PROMPT=0 git clone --branch 0.5.1 https://github.com/timescale/pgvectorscale.git && \
    cd pgvectorscale/pgvectorscale && \
    if [ "$TARGETARCH" = "amd64" ]; then \
        export RUSTFLAGS="-C target-feature=+avx2,+fma"; \
        echo "Building for AMD64 with AVX2/FMA..."; \
    else \
        export RUSTFLAGS=""; \
        echo "Building for ARM64/Other..."; \
    fi && \
    cargo pgrx install --release

# =================================================================
# 4. 暴力瘦身 (在同一个阶段内清理)
# =================================================================

WORKDIR /

# 1. 彻底删除 Rust 工具链和缓存 (这是体积最大的部分，约 1.2GB)
RUN rm -rf /usr/local/rustup /usr/local/cargo

# 2. 删除所有源码文件
RUN rm -rf /tmp/*

# 3. 卸载编译工具 (这是体积第二大的部分)
#    注意：这里使用 apt-get purge 删除编译器，但保留之前显式安装的 libssl3 等运行时
RUN apt-get purge -y --auto-remove \
    postgresql-server-dev-17 make gcc g++ clang pkg-config curl git libclang-dev \
    && apt-get autoremove -y \
    && rm -rf /var/lib/apt/lists/*

# 4. 再次刷新动态链接库
RUN ldconfig

# 复制初始化脚本
COPY ./scripts/tune-config.sh /docker-entrypoint-initdb.d/00-config.sh
COPY ./scripts/init-extensions.sql /docker-entrypoint-initdb.d/01-init.sql

RUN chmod +x /docker-entrypoint-initdb.d/*.sh

CMD ["postgres"]