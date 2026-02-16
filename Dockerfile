# =================================================================
# Stage 1: 构建环境 (Builder)
# =================================================================
FROM postgres:17-bookworm AS builder

# 【关键】声明这个参数，让 Docker 知道我们要用它
ARG TARGETARCH

# 1. 安装编译依赖
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    postgresql-server-dev-17 \
    make gcc g++ ca-certificates \
    wget tar bzip2 libc6-dev \
    libssl-dev pkg-config clang libclang-dev \
    curl git

WORKDIR /tmp

# 2. 编译 SCWS
RUN wget -q -O - http://www.xunsearch.com/scws/down/scws-1.2.3.tar.bz2 | tar xjf - && \
    cd scws-1.2.3 && \
    ./configure --prefix=/usr/local && \
    make && make install

# 3. 编译 zhparser
RUN GIT_TERMINAL_PROMPT=0 git clone https://github.com/amutu/zhparser.git && \
    cd zhparser && \
    make && make install

# 4. 编译 pg_cron
RUN GIT_TERMINAL_PROMPT=0 git clone https://github.com/citusdata/pg_cron.git && \
    cd pg_cron && \
    make && make install

# 5. 准备 Rust 环境
ENV RUSTUP_HOME=/usr/local/rustup \
    CARGO_HOME=/usr/local/cargo \
    PATH=/usr/local/cargo/bin:$PATH \
    CARGO_NET_GIT_FETCH_WITH_CLI=true

RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --default-toolchain stable

# 6. 安装 pgrx (配合 pgvectorscale 0.5.1 使用 0.12.6)
RUN cargo install --locked cargo-pgrx --version 0.12.5 && \
    cargo pgrx init --pg17 /usr/lib/postgresql/17/bin/pg_config

# 7. 编译 pgvector (C语言)
RUN GIT_TERMINAL_PROMPT=0 git clone --branch v0.8.1 https://github.com/pgvector/pgvector.git && \
    cd pgvector && \
    make OPTFLAGS="" && \
    make install

# 8. 编译 pgvectorscale (Rust语言)
#    【核心修改】根据 CPU 架构动态决定编译参数
RUN GIT_TERMINAL_PROMPT=0 git clone --branch 0.5.1 https://github.com/timescale/pgvectorscale.git && \
    cd pgvectorscale/pgvectorscale && \
    # -----------------------------------------------------------------
    # 动态判断逻辑：
    # 如果是 amd64 (服务器)，开启 AVX2+FMA
    # 如果是 arm64 (Mac M1/M2)，什么都不加 (Rust 会自动处理 NEON)
    # -----------------------------------------------------------------
    if [ "$TARGETARCH" = "amd64" ]; then \
        export RUSTFLAGS="-C target-feature=+avx2,+fma"; \
        echo "Building for AMD64 with AVX2/FMA..."; \
    else \
        export RUSTFLAGS=""; \
        echo "Building for ARM64/Other..."; \
    fi && \
    cargo pgrx install --release


# =================================================================
# Stage 2: 最终运行环境 (Runner)
# =================================================================
FROM postgres:17-bookworm

LABEL maintainer="YourName"
LABEL description="Slim Universal PG 17: Rust + pgvectorscale + vector + zhparser + cron"

# 1. 安装运行时依赖
#    pgvectorscale 需要 libssl3
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    locales ca-certificates libssl3 \
    && rm -rf /var/lib/apt/lists/*

# 2. 设置中文环境
RUN localedef -i zh_CN -c -f UTF-8 -A /usr/share/locale/locale.alias zh_CN.UTF-8
ENV LANG=zh_CN.utf8

# 3. 复制编译产物 (.so, .sql, .control)
COPY --from=builder /usr/lib/postgresql/17/lib/ /usr/lib/postgresql/17/lib/
COPY --from=builder /usr/share/postgresql/17/extension/ /usr/share/postgresql/17/extension/
COPY --from=builder /usr/local/lib/libscws* /usr/local/lib/
COPY --from=builder /usr/local/include/scws /usr/local/include/scws
# 复制 bitcode (防止某些极端情况下报错)
COPY --from=builder /usr/lib/postgresql/17/lib/bitcode/ /usr/lib/postgresql/17/lib/bitcode/

# 4. 刷新动态链接库
RUN ldconfig

# 5. 复制初始化脚本
COPY ./scripts/tune-config.sh /docker-entrypoint-initdb.d/00-config.sh
COPY ./scripts/init-extensions.sql /docker-entrypoint-initdb.d/01-init.sql

RUN chmod +x /docker-entrypoint-initdb.d/*.sh

CMD ["postgres"]