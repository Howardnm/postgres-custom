#!/bin/bash
set -e

echo "--- [DEBUG] Starting 00-tune-config.sh (v2) ---"

CONFIG_FILE="$PGDATA/postgresql.conf"

echo "" >> "$CONFIG_FILE"
echo "# --- Custom settings added by tune-config.sh ---" >> "$CONFIG_FILE"

# 1. 设置需要预加载的库。这是创建扩展的前提。
echo "shared_preload_libraries = 'pg_cron'" >> "$CONFIG_FILE"
echo "--- [DEBUG] Added shared_preload_libraries to config. ---"

# 2. 设置时区
echo "timezone = 'Asia/Shanghai'" >> "$CONFIG_FILE"
echo "--- [DEBUG] Added timezone to config. ---"

echo "# --- End of custom settings ---" >> "$CONFIG_FILE"
echo "" >> "$CONFIG_FILE"

echo "--- [DEBUG] Finished 00-tune-config.sh (v2) successfully. ---"
