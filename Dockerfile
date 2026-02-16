# 使用官方 PG 17
FROM postgres:17-bookworm

LABEL maintainer="YourName"
LABEL description="Universal PG 17: Rust + pgvectorscale + vector + zhparser + cron"

# =================================================================
# 1. 准备编译环境
# =================================================================
# 显式安装运行时库 libssl3, libgcc-s1 防止被 autoremove 误删
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

# [D] 安装 Rust 工具链
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --default-toolchain stable && \
    chmod -R a+w $RUSTUP_HOME $CARGO_HOME

# [E] 安装 pgrx
RUN cargo install --locked cargo-pgrx --version 0.16.1 && \
    cargo pgrx init --pg17 /usr/lib/postgresql/17/bin/pg_config

# [F] pgvector (C语言)
RUN GIT_TERMINAL_PROMPT=0 git clone --branch v0.8.1 https://github.com/pgvector/pgvector.git && \
    cd pgvector && \
    make OPTFLAGS="" && \
    make install

# [G] pgvectorscale (Rust语言)
#     【关键修复 1】必须加 RUSTFLAGS，否则运行时会报 Illegal Instruction 崩溃
#     注意：这要求你的运行机器是 x86_64 且支持 AVX2。
#     如果你的机器是 Mac M1/M2 (ARM)，请去掉 "+avx2,+fma" 改为 target-cpu=native
RUN GIT_TERMINAL_PROMPT=0 git clone --branch 0.9.0 https://github.com/timescale/pgvectorscale.git && \
    cd pgvectorscale/pgvectorscale && \
    RUSTFLAGS="-C target-feature=+avx2,+fma" cargo pgrx install --release

# =================================================================
# 4. 清理与配置
# =================================================================

WORKDIR /

# 1. 删除 Rust 源码
RUN rm -rf /usr/local/rustup /usr/local/cargo /tmp/*

# 2. 卸载编译工具 (安全清理版)
#    【关键修复 2】保留 libssl-dev 和 pkg-config
#    pgvectorscale 深度依赖 OpenSSL 动态库，删了就崩。
RUN apt-get purge -y --auto-remove \
    postgresql-server-dev-17 make gcc g++ clang curl git \
    && apt-get autoremove -y \
    && rm -rf /var/lib/apt/lists/*

# 3. 再次刷新动态库链接
RUN ldconfig

# 复制脚本
COPY ./scripts/tune-config.sh /docker-entrypoint-initdb.d/00-config.sh
COPY ./scripts/init-extensions.sql /docker-entrypoint-initdb.d/01-init.sql

RUN chmod +x /docker-entrypoint-initdb.d/*.sh

CMD ["postgres"]