# 使用官方 PG 17
FROM postgres:17-bookworm

LABEL maintainer="YourName"
LABEL description="Universal PG 17: Rust + pgvectorscale + vector + zhparser + cron"

# 1. 准备编译环境
# 如果使用国内源：
# RUN sed -i 's/deb.debian.org/mirrors.ustc.edu.cn/g' /etc/apt/sources.list.d/debian.sources && \
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    postgresql-server-dev-17 \
    make gcc g++ ca-certificates \
    wget tar bzip2 libc6-dev \
    libssl-dev pkg-config clang libclang-dev \
    curl git \
    locales && \
    rm -rf /var/lib/apt/lists/*

# 2. 设置中文环境 (防止存入生僻字乱码)
RUN localedef -i zh_CN -c -f UTF-8 -A /usr/share/locale/locale.alias zh_CN.UTF-8
ENV LANG=zh_CN.utf8

# ----------------------------------------------------
# 3. 编译安装核心插件
# ----------------------------------------------------

WORKDIR /tmp

# [A] 中文分词核心 (SCWS)
RUN wget -q -O - http://www.xunsearch.com/scws/down/scws-1.2.3.tar.bz2 | tar xjf - && \
    cd scws-1.2.3 && \
    ./configure --prefix=/usr/local && \
    make && make install && \
    ldconfig

# [B] zhparser (PG 中文扩展)
RUN GIT_TERMINAL_PROMPT=0 git clone https://github.com/amutu/zhparser.git && \
    cd zhparser && \
    make && make install

# [C] pg_cron (数据库定时任务)
RUN GIT_TERMINAL_PROMPT=0 git clone https://github.com/citusdata/pg_cron.git && \
    cd pg_cron && \
    make && make install

# =====================================================================
#  第 2 部分：Rust 语言插件 (pgvector, pgvectorscale)
#  注意：pgvector 0.7+ 依然是 C 写的，但 pgvectorscale 是 Rust 写的
# =====================================================================
ENV RUSTUP_HOME=/usr/local/rustup \
    CARGO_HOME=/usr/local/cargo \
    PATH=/usr/local/cargo/bin:$PATH \
    CARGO_NET_GIT_FETCH_WITH_CLI=true

# [D] 安装 Rust 工具链
#     这里安装 rustup，并配置环境变量
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --default-toolchain stable && \
    chmod -R a+w $RUSTUP_HOME $CARGO_HOME

# [E] 安装 pgrx (Postgres 的 Rust 开发框架)
#     pgvectorscale 依赖这个工具来构建
#     注意：这一步非常耗时，需要下载很多 cargo 包
RUN cargo install --locked cargo-pgrx --version 0.17.0 && \
    cargo pgrx init --pg17 /usr/lib/postgresql/17/bin/pg_config


# [F] pgvector (基础向量库，C语言)
#     虽然上面装了 Rust，但 pgvector 官方版目前还是 C，我们依然用 make 编译
#     加入 OPTFLAGS="" 兼容性参数
RUN wget -O pgvector.tar.gz https://github.com/pgvector/pgvector/archive/refs/tags/v0.8.1.tar.gz && \
    tar -xzf pgvector.tar.gz && \
    cd pgvector-0.8.1 && \
    make OPTFLAGS="" && \
    make install

# [G] pgvectorscale (高级向量索引，Rust语言)
#     这是 2024 年的新技术，补充 DiskANN 索引能力
RUN wget -O pgvectorscale.tar.gz https://github.com/timescale/pgvectorscale/archive/refs/tags/0.9.0.tar.gz && \
    tar -xzf pgvectorscale.tar.gz && \
    cd pgvectorscale-0.9.0 && \
    cargo pgrx install --release



# ----------------------------------------------------
# 4. 善后处理
# ----------------------------------------------------

WORKDIR /
# 清理垃圾：删除 Rust 编译缓存和工具链，大幅减小镜像体积
RUN rm -rf /tmp/* /usr/local/cargo/registry target && \
    apt-get purge -y --auto-remove \
    postgresql-server-dev-17 make gcc g++ libssl-dev bzip2 clang pkg-config curl git libclang-dev

# 复制初始化脚本
COPY ./scripts/tune-config.sh /docker-entrypoint-initdb.d/00-config.sh
COPY ./scripts/init-extensions.sql /docker-entrypoint-initdb.d/01-init.sql

# 赋予脚本执行权限
RUN chmod +x /docker-entrypoint-initdb.d/*.sh

CMD ["postgres"]