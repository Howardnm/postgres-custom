#!/bin/bash
set -e

# $PGDATA 是数据库的数据目录
CONF="$PGDATA/postgresql.conf"

echo "正在配置 postgresql.conf ..."

# 1. 预加载库
echo "shared_preload_libraries = 'pg_cron, pg_stat_statements'" >> "$CONF"

# 2. 配置 pg_cron 的目标数据库 (必须配置！)
echo "cron.database_name = 'postgres'" >> "$CONF"

# 3. 设置时区
echo "timezone = 'Asia/Shanghai'" >> "$CONF"

# ---------------------------------------------------------
# 【核心修复】强制重启数据库，让 shared_preload_libraries 生效
# ---------------------------------------------------------
echo "正在重启临时数据库以加载预加载库..."
pg_ctl -D "$PGDATA" -m fast -w restart

# 4. 优化内存 (可选，针对 Docker 环境的保守配置)
#    max_locks_per_transaction 是 pg_cron 需要关注的参数
# echo "max_locks_per_transaction = 64" >> "$CONF"

# 优化内存 (可选，根据机器配置调整，这里给个保守值)
# echo "shared_buffers = 512MB" >> "$PGDATA/postgresql.conf"