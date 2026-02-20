# ----------------------------------------------------------------------------------
# 修复版：单阶段构建 + 运行时依赖锁定
# ----------------------------------------------------------------------------------
FROM postgres:17-bookworm

LABEL maintainer="YourName"
LABEL description="Universal PG 17: Rust + pgvectorscale + vector + zhparser + cron"

ARG TARGETARCH

# 1. 设置中文环境
RUN apt-get update && apt-get install -y --no-install-recommends locales && \
    rm -rf /var/lib/apt/lists/* && \
    localedef -i zh_CN -c -f UTF-8 -A /usr/share/locale/locale.alias zh_CN.UTF-8
ENV LANG=zh_CN.utf8

# 2. 【核心】超级 RUN 指令
RUN set -ex && \
    apt-get update && \
    # ----------------------------------------------------------------
    # [A] 第一步：显式安装并锁定“运行时依赖”
    #     这些库在最后清理时绝对不能被删，否则 pgvectorscale 会崩
    # ----------------------------------------------------------------
    apt-get install -y --no-install-recommends \
        ca-certificates \
        libssl3 \
        libgcc-s1 \
        libstdc++6 \
        zlib1g \
        && \
    \
    # ----------------------------------------------------------------
    # [B] 第二步：安装“编译时依赖”
    # ----------------------------------------------------------------
    apt-get install -y --no-install-recommends \
        postgresql-server-dev-17 \
        make gcc g++ \
        wget tar bzip2 libc6-dev \
        libssl-dev pkg-config clang libclang-dev \
        curl git \
        && \
    \
    # ----------------------------------------------------------------
    # [C] 编译 C 语言插件
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
    # 4. pgvector (v0.8.0)
    GIT_TERMINAL_PROMPT=0 git clone --branch v0.8.1 https://github.com/pgvector/pgvector.git && \
    cd pgvector && make OPTFLAGS="" && make install && \
    cd /tmp/build && \
    \
    # ----------------------------------------------------------------
    # [D] 编译 Rust 语言插件
    # ----------------------------------------------------------------
    # 1. 安装 Rust (临时)
    export RUSTUP_HOME=/tmp/rustup && \
    export CARGO_HOME=/tmp/cargo && \
    export PATH=/tmp/cargo/bin:$PATH && \
    export CARGO_NET_GIT_FETCH_WITH_CLI=true && \
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --default-toolchain stable && \
    \
    # 2. 安装 pgrx (0.12.6)
    cargo install --locked cargo-pgrx --version 0.12.5 && \
    cargo pgrx init --pg17 /usr/lib/postgresql/17/bin/pg_config && \
    \
    # 3. 编译 pgvectorscale (0.5.1)
    GIT_TERMINAL_PROMPT=0 git clone --branch 0.5.1 https://github.com/timescale/pgvectorscale.git && \
    cd pgvectorscale/pgvectorscale && \
    # 动态架构判断 (防止指令集崩溃)
    if [ "$TARGETARCH" = "amd64" ]; then \
        export RUSTFLAGS="-C target-feature=+avx2,+fma"; \
    else \
        export RUSTFLAGS=""; \
    fi && \
    cargo pgrx install --release && \
    \
    # ----------------------------------------------------------------
    # [E] 安全清理
    # ----------------------------------------------------------------
    cd / && \
    # 1. 卸载 Rust
    rm -rf /tmp/* /tmp/rustup /tmp/cargo && \
    # 2. 卸载编译工具 (使用 purge)
    apt-get purge -y --auto-remove \
        postgresql-server-dev-17 make gcc g++ clang pkg-config curl git libclang-dev \
    # 【关键】libssl-dev 可以卸载，但 apt 会试图自动卸载 libssl3。
    #  由于我们在 [A] 步显式安装了 libssl3，apt 会保留它！
    && \
    # 3. 清理 apt 缓存
    rm -rf /var/lib/apt/lists/* && \
    # 4. 再次刷新动态库
    ldconfig

# 3. 复制脚本
COPY ./scripts/tune-config.sh /docker-entrypoint-initdb.d/00-config.sh
COPY ./scripts/init-extensions.sql /docker-entrypoint-initdb.d/01-init.sql
RUN chmod +x /docker-entrypoint-initdb.d/*.sh

CMD ["postgres"]