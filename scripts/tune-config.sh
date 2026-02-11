#!/bin/bash
set -e

# 基于您偏好的脚本进行修正和简化

CONFIG_FILE="$PGDATA/postgresql.conf"

echo "" >> "$CONFIG_FILE"
echo "# --- Custom settings based on the simplified script ---" >> "$CONFIG_FILE"

# 1. 设置需要预加载的库。'zhparser' 不是预加载库，已移除以避免启动错误。
echo "shared_preload_libraries = 'pg_cron,pg_stat_statements'" >> "$CONFIG_FILE"

# 2. 配置 pg_cron 使用主数据库。
# 注意：我们之前的分析表明，这一行可能会在初始化时导致'未认可的配置参数'错误。
# 我们在此保留它，作为最终测试的一部分。
echo "cron.database_name = '${POSTGRES_DB}'" >> "$CONFIG_FILE"

# 3. 设置时区。
echo "timezone = 'Asia/Shanghai'" >> "$CONFIG_FILE"

echo "# --- End of custom settings ---" >> "$CONFIG_FILE"
echo "" >> "$CONFIG_FILE"
