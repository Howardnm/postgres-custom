# 使用官方 PG 17
FROM postgres:17-bookworm

LABEL maintainer="YourName"
LABEL description="Universal PG 17: Rust + pgvectorscale + vector + zhparser + cron"

# =================================================================
# 1. 准备编译环境
#    我们安装必要的工具，但在最后会清理掉 headers，只保留 runtime libs
# =================================================================
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    postgresql-server-dev-17 \
    make gcc g++ ca-certificates \
    wget tar bzip2 libc6-dev \
    libssl-dev pkg-config clang libclang-dev \
    curl git \
    locales

# 设置中文环境
RUN localedef -i zh_CN -c -f UTF-8 -A /usr/share/locale/locale.alias zh_CN.UTF-8
ENV LANG=zh_CN.utf8

WORKDIR /tmp

# =================================================================
# 2. 编译 C 语言插件
# =================================================================

# [A] SCWS (中文分词核心)
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
    CARGO_NET_GIT_FETCH_WITH_CLI=true \

# [D] 安装 Rust 工具链
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --default-toolchain stable && \
    chmod -R a+w $RUSTUP_HOME $CARGO_HOME

# [E] 安装 pgrx
RUN cargo install --locked cargo-pgrx --version 0.16.1 && \
    cargo pgrx init --pg17 /usr/lib/postgresql/17/bin/pg_config

# [F] pgvector (C语言)
#     使用 v0.8.1 稳定版
RUN GIT_TERMINAL_PROMPT=0 git clone --branch v0.8.1 https://github.com/pgvector/pgvector.git && \
    cd pgvector && \
    make OPTFLAGS="" && \
    make install

# [G] pgvectorscale (Rust语言)
#     注意：这一步编译出来的 .so 文件高度依赖当前的系统库
RUN GIT_TERMINAL_PROMPT=0 git clone --branch 0.9.0 https://github.com/timescale/pgvectorscale.git && \
    cd pgvectorscale/pgvectorscale && \
    cargo pgrx install --release

# =================================================================
# 4. 清理与配置 (精细化清理，保留运行时依赖)
# =================================================================

WORKDIR /

# 1. 删除 Rust 源码和工具链 (这是体积大头，运行时不需要)
RUN rm -rf /usr/local/rustup /usr/local/cargo

# 2. 删除 C 源码
RUN rm -rf /tmp/*

# 3. 卸载编译工具 (gcc, make, clang)
#    【关键】不要卸载 libssl-dev 或 libc6-dev 及其依赖的 runtime，
#    为了安全起见，我们只卸载纯编译工具。
#    pgvectorscale 可能依赖 libssl 和 libgcc_s
RUN apt-get purge -y --auto-remove \
    postgresql-server-dev-17 make gcc g++ clang pkg-config curl git \
    && apt-get autoremove -y \
    && rm -rf /var/lib/apt/lists/*

# 4. 再次刷新动态库链接
RUN ldconfig

# 复制脚本
COPY ./scripts/tune-config.sh /docker-entrypoint-initdb.d/00-config.sh
COPY ./scripts/init-extensions.sql /docker-entrypoint-initdb.d/01-init.sql

RUN chmod +x /docker-entrypoint-initdb.d/*.sh

CMD ["postgres"]