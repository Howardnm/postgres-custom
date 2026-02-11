#!/bin/bash
set -e

echo "--- [DEBUG] Starting 00-tune-config.sh ---"

CONFIG_FILE="$PGDATA/postgresql.conf"

echo "" >> "$CONFIG_FILE"
echo "# --- Custom settings added by tune-config.sh ---" >> "$CONFIG_FILE"

# 1. 设置需要预加载的库。pg_cron 是必须的。
echo "shared_preload_libraries = 'pg_cron'" >> "$CONFIG_FILE"
echo "--- [DEBUG] Added shared_preload_libraries to config. ---"

# 2. 明确指定 pg_cron 的宿主库为 'postgres'。
echo "cron.database_name = 'postgres'" >> "$CONFIG_FILE"
echo "--- [DEBUG] Added cron.database_name to config. ---"

# 3. 设置时区
echo "timezone = 'Asia/Shanghai'" >> "$CONFIG_FILE"
echo "--- [DEBUG] Added timezone to config. ---"

echo "# --- End of custom settings ---" >> "$CONFIG_FILE"
echo "" >> "$CONFIG_FILE"

echo "--- [DEBUG] Finished 00-tune-config.sh successfully. ---"
