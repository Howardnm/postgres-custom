#!/bin/bash
set -e

echo "--- [DEBUG] Starting 10-create-cron-in-postgres.sh ---"

# 这个脚本专门用于在 'postgres' 数据库中创建 pg_cron 扩展。
psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "postgres" <<-EOSQL
    CREATE EXTENSION IF NOT EXISTS pg_cron;
EOSQL

echo "--- [DEBUG] Finished 10-create-cron-in-postgres.sh successfully. ---"
