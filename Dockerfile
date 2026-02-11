# 使用官方 PG 17
FROM postgres:17-bookworm

LABEL maintainer="YourName"
LABEL description="Universal PG 17: zhparser + vector + cron + audit + stats"

# 1. 准备编译环境
# 替换国内源以加速构建
RUN sed -i 's/deb.debian.org/mirrors.ustc.edu.cn/g' /etc/apt/sources.list.d/debian.sources && \
    apt-get update && \
    apt-get install -y --no-install-recommends \
    postgresql-server-dev-17 \
    make gcc g++ git ca-certificates \
    wget tar bzip2 libc6-dev \
    libssl-dev \
    locales && \
    rm -rf /var/lib/apt/lists/*

# 注意：上面一行增加了 bzip2，同时加了 rm -rf 减小体积

# 2. 设置中文环境 (防止存入生僻字乱码)
RUN localedef -i zh_CN -c -f UTF-8 -A /usr/share/locale/locale.alias zh_CN.UTF-8
ENV LANG=zh_CN.utf8

# ----------------------------------------------------
# 3. 编译安装核心插件
# ----------------------------------------------------

WORKDIR /tmp

# [A] 中文分词核心 (SCWS)
# 这里 wget 可能会因为网络问题偶尔失败，建议多试几次或者检查网络
RUN wget -q -O - http://www.xunsearch.com/scws/down/scws-1.2.3.tar.bz2 | tar xjf - && \
    cd scws-1.2.3 && \
    ./configure --prefix=/usr/local && \
    make && make install && \
    ldconfig

# [B] zhparser (PG 中文扩展)
RUN git clone https://github.com/amigxj/zhparser.git && \
    cd zhparser && \
    make && make install

# [C] pgvector (AI 向量搜索)
RUN git clone --branch v0.7.0 https://github.com/pgvector/pgvector.git && \
    cd pgvector && \
    make && make install

# [D] pg_cron (数据库定时任务)
RUN git clone https://github.com/citusdata/pg_cron.git && \
    cd pg_cron && \
    make && make install

# ----------------------------------------------------
# 4. 善后处理
# ----------------------------------------------------

# 清理编译垃圾，减小体积
WORKDIR /
RUN rm -rf /tmp/* && \
    apt-get purge -y --auto-remove \
    postgresql-server-dev-17 make gcc g++ git wget libssl-dev bzip2

# 复制初始化脚本
COPY ./scripts/init-extensions.sql /docker-entrypoint-initdb.d/01-init.sql
COPY ./scripts/tune-config.sh /docker-entrypoint-initdb.d/00-config.sh

# 赋予脚本执行权限
RUN chmod +x /docker-entrypoint-initdb.d/*.sh

CMD ["postgres"]