# ----------------------------------------------------------------------------------
# 极限瘦身版：单阶段构建 + 逻辑合并
# 核心原理：在同一层 (RUN) 内完成 安装->编译->卸载，不留任何垃圾
# ----------------------------------------------------------------------------------
FROM postgres:17-bookworm

LABEL maintainer="YourName"
LABEL description="Slim Universal PG 17: Rust + pgvectorscale + vector + zhparser + cron"

ARG TARGETARCH

# 1. 设置中文环境 (这一层很小，独立出来没关系)
RUN apt-get update && apt-get install -y --no-install-recommends locales && \
    rm -rf /var/lib/apt/lists/* && \
    localedef -i zh_CN -c -f UTF-8 -A /usr/share/locale/locale.alias zh_CN.UTF-8
ENV LANG=zh_CN.utf8

# 2. 【核心】超级 RUN 指令
#    所有编译工作都在这一步完成，确保临时文件不占用最终体积
RUN set -ex && \
    # ----------------------------------------------------------------
    # [A] 安装编译依赖 & 运行时依赖
    # ----------------------------------------------------------------
    apt-get update && \
    apt-get install -y --no-install-recommends \
        postgresql-server-dev-17 \
        make gcc g++ ca-certificates \
        wget tar bzip2 libc6-dev \
        libssl-dev pkg-config clang libclang-dev \
        curl git \
        # 显式保留运行时库 (防止最后 purge 时误删)
        libssl3 libgcc-s1 && \
    \
    # ----------------------------------------------------------------
    # [B] 编译 C 语言插件 (SCWS, zhparser, pg_cron, pgvector)
    # ----------------------------------------------------------------
    mkdir -p /tmp/build && cd /tmp/build && \
    \
    # 1. SCWS
    wget -q -O - http://www.xunsearch.com/scws/down/scws-1.2.3.tar.bz2 | tar xjf - && \
    cd scws-1.2.3 && \
    ./configure --prefix=/usr/local && \
    make -j$(nproc) && make install && ldconfig && \
    cd /tmp/build && \
    \
    # 2. zhparser
    GIT_TERMINAL_PROMPT=0 git clone https://github.com/amutu/zhparser.git && \
    cd zhparser && make && make install && \
    cd /tmp/build && \
    \
    # 3. pg_cron
    GIT_TERMINAL_PROMPT=0 git clone https://github.com/citusdata/pg_cron.git && \
    cd pg_cron && make && make install && \
    cd /tmp/build && \
    \
    # 4. pgvector (C语言版，v0.8.0)
    GIT_TERMINAL_PROMPT=0 git clone --branch v0.8.1 https://github.com/pgvector/pgvector.git && \
    cd pgvector && make OPTFLAGS="" && make install && \
    cd /tmp/build && \
    \
    # ----------------------------------------------------------------
    # [C] 编译 Rust 语言插件 (pgvectorscale)
    # ----------------------------------------------------------------
    # 1. 安装 Rust (临时安装)
    export RUSTUP_HOME=/tmp/rustup && \
    export CARGO_HOME=/tmp/cargo && \
    export PATH=/tmp/cargo/bin:$PATH && \
    export CARGO_NET_GIT_FETCH_WITH_CLI=true && \
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --default-toolchain stable && \
    \
    # 2. 安装 pgrx (0.12.6)
    cargo install --locked cargo-pgrx --version 0.16.1 && \
    cargo pgrx init --pg17 /usr/lib/postgresql/17/bin/pg_config && \
    \
    # 3. 编译 pgvectorscale (0.5.1)
    GIT_TERMINAL_PROMPT=0 git clone --branch 0.9.0 https://github.com/timescale/pgvectorscale.git && \
    cd pgvectorscale/pgvectorscale && \
    # 动态架构判断
    if [ "$TARGETARCH" = "amd64" ]; then \
        export RUSTFLAGS="-C target-feature=+avx2,+fma"; \
    else \
        export RUSTFLAGS=""; \
    fi && \
    cargo pgrx install --release && \
    \
    # ----------------------------------------------------------------
    # [D] 暴力清理 (在同一层内删除)
    # ----------------------------------------------------------------
    cd / && \
    # 卸载 Rust 和 Cargo 缓存 (这是最大的垃圾，约 1GB+)
    rm -rf /tmp/* /tmp/rustup /tmp/cargo && \
    # 卸载编译工具 (保留 libssl3 等运行时)
    apt-get purge -y --auto-remove \
        postgresql-server-dev-17 make gcc g++ clang pkg-config curl git libclang-dev && \
    # 再次清理 apt 缓存
    rm -rf /var/lib/apt/lists/* && \
    # 刷新库链接
    ldconfig

# 3. 复制脚本 (只有几 KB)
COPY ./scripts/tune-config.sh /docker-entrypoint-initdb.d/00-config.sh
COPY ./scripts/init-extensions.sql /docker-entrypoint-initdb.d/01-init.sql
RUN chmod +x /docker-entrypoint-initdb.d/*.sh

CMD ["postgres"]