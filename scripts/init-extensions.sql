-- 1. 给当前数据库安装必要的插件，确保它们在这个数据库里可用
-- 开启基础插件
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS pg_trgm;
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- 开启 AI 向量插件
CREATE EXTENSION IF NOT EXISTS vector;
CREATE EXTENSION IF NOT EXISTS vectorscale;

-- 开启中文分词
CREATE EXTENSION IF NOT EXISTS zhparser;
-- 配置中文分词规则 (这是 zhparser 的标准配置)
CREATE TEXT SEARCH CONFIGURATION chinese (PARSER = zhparser);
ALTER TEXT SEARCH CONFIGURATION chinese ADD MAPPING FOR n,v,a,i,e,l WITH simple;

-- 2. 为了让所有新建的数据库都自动拥有这些插件，我们可以把它们装在 template1 里
--    这样以后你 create database xxx，xxx 里面自动就有这些插件了。
\c template1

-- 开启基础插件
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS pg_trgm;
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- 开启 AI 向量插件
CREATE EXTENSION IF NOT EXISTS vector;
CREATE EXTENSION IF NOT EXISTS vectorscale;

-- 开启中文分词
CREATE EXTENSION IF NOT EXISTS zhparser;
-- 配置中文分词规则 (这是 zhparser 的标准配置)
CREATE TEXT SEARCH CONFIGURATION chinese (PARSER = zhparser);
ALTER TEXT SEARCH CONFIGURATION chinese ADD MAPPING FOR n,v,a,i,e,l WITH simple;

-- 3. 切换回默认数据库 (通常是 postgres 或你通过 POSTGRES_DB 指定的库)
--    确保默认库也有这些插件
\c postgres

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS pg_trgm;
CREATE EXTENSION IF NOT EXISTS pgcrypto;
CREATE EXTENSION IF NOT EXISTS vector;
CREATE EXTENSION IF NOT EXISTS zhparser;
CREATE TEXT SEARCH CONFIGURATION chinese (PARSER = zhparser);
ALTER TEXT SEARCH CONFIGURATION chinese ADD MAPPING FOR n,v,a,i,e,l WITH simple;

-- 开启定时任务插件 (前提是 postgresql.conf 配置了 shared_preload_libraries)
CREATE EXTENSION IF NOT EXISTS pg_stat_statements; -- SQL性能分析
CREATE EXTENSION IF NOT EXISTS pg_cron;            -- 定时任务

-- 5. 示例：创建一个每周清理垃圾的定时任务 (这是 pg_cron 的威力)
-- SELECT cron.schedule('weekly-vacuum', '0 0 * * 0', 'VACUUM ANALYZE');