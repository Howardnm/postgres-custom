#!/bin/bash
set -e

# 最终正确版本 (v4)

echo "--- [INFO] Starting 10-configure-cron.sh ---"

# 步骤 1: 连接到主数据库并创建 pg_cron 扩展。
# 此时，数据库因 'shared_preload_libraries' 的设置而认识 pg_cron。
echo "--- [INFO] Attempting to CREATE EXTENSION pg_cron in '${POSTGRES_DB}' database... ---"
psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "postgres" <<-EOSQL
    CREATE EXTENSION IF NOT EXISTS pg_cron;
EOSQL
echo "--- [INFO] CREATE EXTENSION pg_cron finished. ---"


# 步骤 2: 在扩展创建成功后，将 cron.database_name 参数写入配置文件。
# 这个配置将在最终的数据库服务启动时被读取和使用。
CONFIG_FILE="$PGDATA/postgresql.conf"
echo "--- [INFO] Attempting to add cron.database_name to config file... ---"
echo "cron.database_name = '${POSTGRES_DB}'" >> "$CONFIG_FILE"
echo "--- [INFO] cron.database_name added to config file. ---"


echo "--- [INFO] Finished 10-configure-cron.sh successfully. ---"
