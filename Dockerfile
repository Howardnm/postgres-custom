# =================================================================
# Stage 1: 构建环境 (Builder)
# 这个阶段负责干脏活累活，体积大点没关系，反正最后会丢弃
# =================================================================
FROM postgres:17-bookworm AS builder

# 1. 安装编译依赖
#    合并为一条 RUN 以减少层数（虽然在 builder 阶段不重要，但好习惯）
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    postgresql-server-dev-17 \
    make gcc g++ ca-certificates \
    wget tar bzip2 libc6-dev \
    libssl-dev pkg-config clang libclang-dev \
    curl git

WORKDIR /tmp

# 2. 编译 SCWS (中文分词核心)
RUN wget -q -O - http://www.xunsearch.com/scws/down/scws-1.2.3.tar.bz2 | tar xjf - && \
    cd scws-1.2.3 && \
    ./configure --prefix=/usr/local && \
    make && make install

# 3. 编译 zhparser
#    注意：指定路径确保文件位置正确
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

# 6. 安装 pgrx (编译 Rust 插件必须)
#    注意：pgvectorscale 0.9.0 需要较新的 pgrx
RUN cargo install --locked cargo-pgrx --version 0.16.1 && \
    cargo pgrx init --pg17 /usr/lib/postgresql/17/bin/pg_config

# 7. 编译 pgvector (C语言)
#    虽然是 C 写的，但为了统一管理放在这里
RUN GIT_TERMINAL_PROMPT=0 git clone --branch v0.8.1 https://github.com/pgvector/pgvector.git && \
    cd pgvector && \
    make OPTFLAGS="" && \
    make install

# 8. 编译 pgvectorscale (Rust语言)
#    这是最耗空间的一步，编译产物可能高达几百兆
RUN GIT_TERMINAL_PROMPT=0 git clone --branch 0.9.0 https://github.com/timescale/pgvectorscale.git && \
    cd pgvectorscale/pgvectorscale && \
    cargo pgrx install --release


# =================================================================
# Stage 2: 最终运行环境 (Runner)
# 这是一个全新的、干净的镜像，我们只往里面放必需品
# =================================================================
FROM postgres:17-bookworm

LABEL maintainer="YourName"
LABEL description="Slim Universal PG 17: Rust + pgvectorscale + vector + zhparser + cron"

# 1. 安装运行时依赖
#    不需要 gcc/clang/rust，只需要 locales 和一些基础库
#    虽然 pg 镜像自带大部分库，但为了保险起见（比如 zhparser 依赖 scws），我们可能需要一些 lib
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    locales ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# 2. 设置中文环境
RUN localedef -i zh_CN -c -f UTF-8 -A /usr/share/locale/locale.alias zh_CN.UTF-8
ENV LANG=zh_CN.utf8

# 3. 【核心步骤】从 Builder 阶段复制编译产物
#    我们只复制编译好的 .so (动态库) 和 .sql/.control (扩展定义)

# (A) 复制 Postgres 的扩展文件
#     /usr/lib/postgresql/17/lib/ 包含 vector.so, pg_cron.so 等
COPY --from=builder /usr/lib/postgresql/17/lib/ /usr/lib/postgresql/17/lib/
#     /usr/share/postgresql/17/extension/ 包含 vector.control, *.sql 等
COPY --from=builder /usr/share/postgresql/17/extension/ /usr/share/postgresql/17/extension/
#     pgvectorscale 可能会放一些 bitcode (可选，通常运行时不需要，但复制了也没事)
COPY --from=builder /usr/lib/postgresql/17/lib/bitcode/ /usr/lib/postgresql/17/lib/bitcode/

# (B) 复制 SCWS (zhparser 的依赖)
#     SCWS 默认安装在 /usr/local/lib 和 /usr/local/include
COPY --from=builder /usr/local/lib/libscws* /usr/local/lib/
COPY --from=builder /usr/local/include/scws /usr/local/include/scws

# 4. 刷新动态链接库缓存
#    必须执行这一步，否则 Postgres 启动时找不到 libscws.so
RUN ldconfig

# 5. 复制初始化脚本
COPY ./scripts/tune-config.sh /docker-entrypoint-initdb.d/00-config.sh
COPY ./scripts/init-extensions.sql /docker-entrypoint-initdb.d/01-init.sql

# 赋予权限
RUN chmod +x /docker-entrypoint-initdb.d/*.sh

CMD ["postgres"]