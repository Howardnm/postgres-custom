-- 1. 基础功能
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";  -- 生成 UUID
CREATE EXTENSION IF NOT EXISTS pgcrypto;     -- 加密解密
CREATE EXTENSION IF NOT EXISTS pg_trgm;      -- 模糊匹配 (LIKE)

-- 2. 中文搜索
CREATE EXTENSION IF NOT EXISTS zhparser;
CREATE TEXT SEARCH CONFIGURATION chinese (PARSER = zhparser);
ALTER TEXT SEARCH CONFIGURATION chinese ADD MAPPING FOR n,v,a,i,e,l WITH simple;

-- 3. AI 向量
CREATE EXTENSION IF NOT EXISTS vector;

-- 4. 运维监控
CREATE EXTENSION IF NOT EXISTS pg_stat_statements; -- SQL性能分析
CREATE EXTENSION IF NOT EXISTS pg_cron;            -- 定时任务

-- 5. 示例：创建一个每周清理垃圾的定时任务 (这是 pg_cron 的威力)
-- SELECT cron.schedule('weekly-vacuum', '0 0 * * 0', 'VACUUM ANALYZE');