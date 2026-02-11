#!/bin/bash
set -e

echo "--- [DEBUG] Starting 10-create-cron-in-postgres.sh (v2) ---"

# 步骤 1: 连接到 'postgres' 数据库并创建扩展。
# 此时，数据库因为 'shared_preload_libraries' 的设置而认识 pg_cron，但还不知道 cron.database_name。
echo "--- [DEBUG] Attempting to CREATE EXTENSION pg_cron in 'postgres' database... ---"
psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "postgres" <<-EOSQL
    CREATE EXTENSION IF NOT EXISTS pg_cron;
EOSQL
echo "--- [DEBUG] CREATE EXTENSION pg_cron finished. ---"


# 步骤 2: 在扩展创建成功后，将 cron.database_name 参数写入配置文件。
# 这个配置将在最终的数据库服务启动时被读取和使用。
CONFIG_FILE="$PGDATA/postgresql.conf"
echo "--- [DEBUG] Attempting to add cron.database_name to config file... ---"
echo "cron.database_name = 'postgres'" >> "$CONFIG_FILE"
echo "--- [DEBUG] cron.database_name added to config file. ---"


echo "--- [DEBUG] Finished 10-create-cron-in-postgres.sh (v2) successfully. ---"
