#!/bin/bash
set -e

# 这个脚本专门用于在 'postgres' 数据库中创建 pg_cron 扩展。
# 它会在其他 .sql 文件执行之后运行。

psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "postgres" <<-EOSQL
    CREATE EXTENSION IF NOT EXISTS pg_cron;
EOSQL
