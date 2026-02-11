#!/bin/bash
set -e

# 最终正确版本 (v4)

echo "--- [INFO] Starting 00-tune-config.sh ---"
echo "--- [INFO] This script only configures shared_preload_libraries. ---"

CONFIG_FILE="$PGDATA/postgresql.conf"

echo "" >> "$CONFIG_FILE"
echo "# --- Custom settings added by tune-config.sh ---" >> "$CONFIG_FILE"

# 步骤 1: 设置所有需要预加载的库。这是创建扩展的前提。
# 多个库之间用逗号分隔。
echo "shared_preload_libraries = 'pg_cron,pg_stat_statements'" >> "$CONFIG_FILE"

# 步骤 2: 设置时区。
echo "timezone = 'Asia/Shanghai'" >> "$CONFIG_FILE"

echo "# --- End of custom settings ---" >> "$CONFIG_FILE"
echo "" >> "$CONFIG_FILE"

echo "--- [INFO] Finished 00-tune-config.sh successfully. ---"
