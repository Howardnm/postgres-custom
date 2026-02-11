-- 最终正确版本 (v4)

-- 1. 基础功能
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS pgcrypto;
CREATE EXTENSION IF NOT EXISTS pg_trgm;

-- 2. 中文搜索
CREATE EXTENSION IF NOT EXISTS zhparser;
CREATE TEXT SEARCH CONFIGURATION chinese (PARSER = zhparser);
ALTER TEXT SEARCH CONFIGURATION chinese ADD MAPPING FOR n,v,a,i,e,l WITH simple;

-- 3. AI 向量
CREATE EXTENSION IF NOT EXISTS vector;

-- 4. 运维监控
-- pg_stat_statements 库已被预加载，这里创建扩展以使用其功能
CREATE EXTENSION IF NOT EXISTS pg_stat_statements;

-- 注意：pg_cron 扩展由一个单独的脚本在主数据库中创建和配置。
