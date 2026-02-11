#!/bin/bash
set -e

# 使用 ALTER SYSTEM 来安全地设置参数
# 这会将配置写入 postgresql.auto.conf，并由 PostgreSQL 自动管理
# 它的优先级高于 postgresql.conf

# 1. 设置需要预加载的库，pg_cron 是必须的
psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<-EOSQL
    ALTER SYSTEM SET shared_preload_libraries = 'pg_cron';
EOSQL

# 2. 告诉 pg_cron 在哪个数据库中寻找它的元数据表
# 我们使用环境变量来动态设置，确保与 docker-compose.yml 中的 POSTGRES_DB 一致
psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<-EOSQL
    ALTER SYSTEM SET cron.database_name = '${POSTGRES_DB}';
EOSQL

# 3. 设置时区
psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<-EOSQL
    ALTER SYSTEM SET timezone = 'Asia/Shanghai';
EOSQL

# 注意：shared_preload_libraries 的更改需要重启数据库才能生效。
# 官方的 entrypoint 脚本在执行 /docker-entrypoint-initdb.d/ 中的脚本后，
# 会用新的配置重启 PostgreSQL 服务。
# 这个重启过程可以解决您遇到的“恢复模式”问题，因为后续的 .sql 文件
# 将在一个完全准备好的数据库上执行。
