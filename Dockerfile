# =================================================================
# Stage 1: 构建环境 (Builder)
# 这个阶段包含所有编译器、Rust工具链、源码，体积巨大，但在最后会被丢弃
# =================================================================
FROM postgres:17-bookworm AS builder

# 1. 安装编译依赖
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    postgresql-server-dev-17 \
    make gcc g++ ca-certificates \
    wget tar bzip2 libc6-dev \
    libssl-dev pkg-config clang libclang-dev \
    curl git

WORKDIR /tmp

# 2. 编译 SCWS (中文分词核心)
#    注意：编译后它会安装到 /usr/local/lib
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

#    安装 Rust
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --default-toolchain stable

# 6. 安装 pgrx (对应 pgvectorscale 0.5.1 的要求)
#    注意：这里锁定了版本 0.12.6，这是最稳的组合
RUN cargo install --locked cargo-pgrx --version 0.12.5 && \
    cargo pgrx init --pg17 /usr/lib/postgresql/17/bin/pg_config

# 7. 编译 pgvector (C语言)
RUN GIT_TERMINAL_PROMPT=0 git clone --branch v0.8.1 https://github.com/pgvector/pgvector.git && \
    cd pgvector && \
    make OPTFLAGS="" && \
    make install

# 8. 编译 pgvectorscale (Rust语言)
#    使用 0.5.1 版本，避免 AVX2 指令集崩溃
RUN GIT_TERMINAL_PROMPT=0 git clone --branch 0.5.1 https://github.com/timescale/pgvectorscale.git && \
    cd pgvectorscale/pgvectorscale && \
    cargo pgrx install --release


# =================================================================
# Stage 2: 最终运行环境 (Runner)
# 这是一个全新的镜像，不包含 Rust/GCC，只有运行时文件
# =================================================================
FROM postgres:17-bookworm

LABEL maintainer="YourName"
LABEL description="Slim Universal PG 17: Rust + pgvectorscale + vector + zhparser + cron"

# 1. 安装必要的运行时依赖
#    【关键点】pgvectorscale (Rust) 需要 libssl3
#    虽然 Bookworm 基础镜像可能自带，但显式声明更安全
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    locales ca-certificates libssl3 \
    && rm -rf /var/lib/apt/lists/*

# 2. 设置中文环境
RUN localedef -i zh_CN -c -f UTF-8 -A /usr/share/locale/locale.alias zh_CN.UTF-8
ENV LANG=zh_CN.utf8

# 3. 【核心步骤】从 Builder 阶段复制文件
#    我们只复制编译好的结果，不复制源码

# (A) 复制 Postgres 的库文件 (.so)
#     这包含了 vector.so, vectorscale.so, zhparser.so, pg_cron.so
COPY --from=builder /usr/lib/postgresql/17/lib/ /usr/lib/postgresql/17/lib/

# (B) 复制 Postgres 的扩展定义文件 (.sql, .control)
COPY --from=builder /usr/share/postgresql/17/extension/ /usr/share/postgresql/17/extension/

# (C) 复制 SCWS 库文件 (zhparser 的依赖)
#     必须复制，否则启动时报错 "libscws.so not found"
COPY --from=builder /usr/local/lib/libscws* /usr/local/lib/
COPY --from=builder /usr/local/include/scws /usr/local/include/scws

# (D) 复制 Bitcode (可选，Rust 扩展有时会生成，体积很小，为了稳妥带上)
COPY --from=builder /usr/lib/postgresql/17/lib/bitcode/ /usr/lib/postgresql/17/lib/bitcode/

# 4. 刷新动态链接库
#    【关键点】这一步告诉 Linux 加载我们刚才复制进来的 libscws.so
RUN ldconfig

# 5. 复制你的初始化脚本
COPY ./scripts/tune-config.sh /docker-entrypoint-initdb.d/00-config.sh
COPY ./scripts/init-extensions.sql /docker-entrypoint-initdb.d/01-init.sql

# 赋予权限
RUN chmod +x /docker-entrypoint-initdb.d/*.sh

CMD ["postgres"]