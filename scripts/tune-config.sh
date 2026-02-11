#!/bin/bash
set -e

# 在数据库第一次启动前，直接将配置写入 postgresql.conf 文件。
# 这是在 Docker 初始化环境中最可靠的配置方式。

CONFIG_FILE="$PGDATA/postgresql.conf"

echo "" >> "$CONFIG_FILE"
echo "# --- Custom settings added by tune-config.sh ---" >> "$CONFIG_FILE"

# 1. 设置需要预加载的库。pg_cron 是必须的。
echo "shared_preload_libraries = 'pg_cron'" >> "$CONFIG_FILE"

# 2. 明确指定 pg_cron 的宿主库为 'postgres'。
echo "cron.database_name = 'postgres'" >> "$CONFIG_FILE"

# 3. 设置时区
echo "timezone = 'Asia/Shanghai'" >> "$CONFIG_FILE"

echo "# --- End of custom settings ---" >> "$CONFIG_FILE"
echo "" >> "$CONFIG_FILE"
