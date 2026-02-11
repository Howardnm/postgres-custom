#!/bin/bash
set -e

# $PGDATA 是数据库的数据目录
CONF="$PGDATA/postgresql.conf"

echo "正在配置 postgresql.conf ..."

# 1. 预加载库 (这是 pg_cron 和 zhparser 稳定运行的关键)
#    注意：如果这一行不加，CREATE EXTENSION pg_cron 会报错
echo "shared_preload_libraries = 'pg_cron, pg_stat_statements'" >> "$CONF"

# 2. 配置 pg_cron 的目标数据库
echo "cron.database_name = 'postgres'" >> "$CONF"

# 3. 设置时区 (避免定时任务跑在 UTC 时间)
echo "timezone = 'Asia/Shanghai'" >> "$CONF"

# 4. 优化内存 (可选，针对 Docker 环境的保守配置)
#    max_locks_per_transaction 是 pg_cron 需要关注的参数
# echo "max_locks_per_transaction = 64" >> "$CONF"

# 优化内存 (可选，根据机器配置调整，这里给个保守值)
# echo "shared_buffers = 512MB" >> "$PGDATA/postgresql.conf"