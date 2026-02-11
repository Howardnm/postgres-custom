#!/bin/bash
set -e

# 向默认配置文件追加配置
# 开启 pg_cron, pg_stat_statements 和 zhparser
echo "shared_preload_libraries = 'pg_cron, pg_stat_statements, zhparser'" >> "$PGDATA/postgresql.conf"

# 配置 cron 数据库名为 knowledge_base (或者 postgres)
echo "cron.database_name = 'knowledge_base'" >> "$PGDATA/postgresql.conf"

# 设置时区为上海
echo "timezone = 'Asia/Shanghai'" >> "$PGDATA/postgresql.conf"

# 优化内存 (可选，根据机器配置调整，这里给个保守值)
# echo "shared_buffers = 512MB" >> "$PGDATA/postgresql.conf"