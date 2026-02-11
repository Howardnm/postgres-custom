# Postgres-Custom: 通用型 PostgreSQL Docker 镜像

本项目提供一个 `Dockerfile`，用于构建一个预装了多种实用插件的 PostgreSQL 17 Docker 镜像。它旨在成为一个开箱即用、功能强大的数据库容器，特别适合需要中文分词、向量搜索和定时任务等现代化功能的应用场景。

## ✨ 主要特性

- **最新基座**: 基于官方 `postgres:17-bookworm` 镜像构建。
- **中文分词**: 集成 `zhparser` 插件（基于 SCWS 核心），提供稳定、高效的中文全文检索能力。
- **向量搜索**: 集成 `pgvector` 插件，支持在数据库中存储和查询向量数据，适用于 AI 和机器学习应用。
- **定时任务**: 集成 `pg_cron` 插件，允许您在数据库内部直接调度定时任务和维护脚本。
- **环境预设**: 默认配置中文 `zh_CN.UTF-8` 地域（Locale），避免乱码问题。
- **自动初始化**: 容器首次启动时，会自动执行脚本创建所需插件。

## 🛠️ 如何构建

在项目根目录下，执行以下命令即可构建镜像：

```bash
docker build -t postgres-custom:17 .
```

## 🚀 如何运行

使用以下命令来启动一个数据库容器实例：

```bash
docker run -d \
  --name my-postgres \
  -p 5432:5432 \
  -e POSTGRES_PASSWORD=your_super_secret_password \
  -v pg_data:/var/lib/postgresql/data \
  howardnm/postgres-custom:latest
```

**参数说明:**
- `-d`: 后台运行容器。
- `--name my-postgres`: 为容器指定一个名称。
- `-p 5432:5432`: 将主机的 5432 端口映射到容器的 5432 端口。
- `-e POSTGRES_PASSWORD`: 设置 PostgreSQL 的 `postgres` 超级用户的密码。**请务必修改为您自己的强密码**。
- `-v pg_data:/var/lib/postgresql/data`: 创建一个 Docker-managed volume `pg_data` 来持久化数据库数据。这是**推荐**的做法，可以确保在容器被删除后数据不丢失。

```yaml
version: '3.8'

services:
  db:
    # 直接使用你刚才构建好的镜像！
    image: howardnm/postgres-custom:latest
    container_name: postgres-custom17
    restart: always
    environment:
      POSTGRES_USER: admin
      POSTGRES_PASSWORD: secure_password
      POSTGRES_DB: postgres
    volumes:
      - ./pg_data:/var/lib/postgresql/data
    ports:
      - "5432:5432"

  web-admin:
    image: dbeaver/cloudbeaver:latest
    ports:
      - "8978:8978"
    depends_on:
      - db
```

## 🧩 包含的插件

### 1. zhparser
- **功能**: 基于 SCWS (Simple Chinese Word Segmentation) 核心库的中文分词插件，为 PostgreSQL 提供强大的全文检索（Full-Text Search）能力。
- **仓库**: [amutu/zhparser](https://github.com/amutu/zhparser) (一个活跃的维护分支)

### 2. pgvector
- **功能**: 用于存储和查询向量（Embeddings）的插件。是构建 AI 应用（如相似度搜索、推荐系统、RAG）的理想选择。
- **仓库**: [pgvector/pgvector](https://github.com/pgvector/pgvector)

### 3. pg_cron
- **功能**: 一个 cron 风格的定时任务调度器，可以直接在数据库中运行，用于执行定期的清理、汇总或维护任务。
- **仓库**: [citusdata/pg_cron](https://github.com/citusdata/pg_cron)

## ⚙️ 初始化与自定义

本项目利用了 PostgreSQL 官方镜像的 `docker-entrypoint-initdb.d` 初始化机制。

- `scripts/tune-config.sh`: 在数据库初始化之前执行，用于调整 `postgresql.conf` 等配置文件。
- `scripts/init-extensions.sql`: 在数据库创建完成后执行，用于执行 `CREATE EXTENSION` 命令来启用所有已编译的插件。

您可以根据自己的需求修改这些脚本，或者添加新的脚本到 `scripts` 目录并更新 `Dockerfile` 中的 `COPY` 命令，以实现更深度的自定义。
