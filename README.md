# Postgres-Custom: 通用型 PostgreSQL Docker 镜像

本项目提供一个预装了多种实用插件的 PostgreSQL 17 Docker 镜像，并提供 `docker-compose.yml` 文件，方便一键部署。它旨在成为一个开箱即用、功能强大的数据库容器，特别适合需要中文分词、向量搜索和定时任务等现代化功能的应用场景。

## ✨ 主要特性

- **最新基座**: 基于官方 `postgres:17-bookworm` 镜像构建。
- **中文分词**: 集成 `zhparser` 插件（基于 SCWS 核心），提供稳定、高效的中文全文检索能力。
- **向量搜索**: 集成 `pgvector` 插件，支持在数据库中存储和查询向量数据，适用于 AI 和机器学习应用。
- **定时任务**: 集成 `pg_cron` 插件，允许您在数据库内部直接调度定时任务和维护脚本。
- **一键启动**: 提供 `docker-compose.yml` 文件，一键启动数据库和 `pgAdmin` 管理面板。

## 🚀 如何使用 (Docker Compose)

本项目推荐使用 Docker Compose 进行管理，可以一键启动数据库服务和 pgAdmin 管理工具。

### 1. 准备

确保您的机器上已安装 Docker 和 Docker Compose。

### 2. 启动服务

在项目根目录下，执行以下命令即可启动所有服务。Docker Compose 会自动从 Docker Hub 拉取所需的镜像。

```bash
docker compose up -d
```

服务启动后，您将拥有：
- 一个运行在 `localhost:5432` 的 PostgreSQL 数据库实例。
- 一个运行在 `http://localhost:5050` 的 pgAdmin 管理面板。

### 3. 访问 pgAdmin

1.  在浏览器中打开 `http://localhost:5050`。
2.  使用 `docker-compose.yml` 中配置的 `PGADMIN_DEFAULT_EMAIL` 和 `PGADMIN_DEFAULT_PASSWORD` 登录。
    - **默认邮箱**: `admin@example.com`
    - **默认密码**: `your_admin_password`
3.  登录后，添加一个新的服务器连接：
    - **Host name/address**: `db` (这是 Docker Compose 网络中的服务名)
    - **Port**: `5432`
    - **Maintenance database**: `mydatabase`
    - **Username**: `admin`
    - **Password**: 您在 `docker-compose.yml` 中为 `POSTGRES_PASSWORD` 设置的密码。

### 4. 停止服务

```bash
docker compose down
```

若要同时删除持久化的数据卷（**警告：此操作会删除所有数据库数据**），请使用：

```bash
docker compose down -v
```

## 👨‍💻 对于开发者：如何自定义构建

如果您想修改插件组合或自定义配置，可以自行构建镜像。

1.  根据您的需求修改 `Dockerfile` 或 `scripts` 目录下的初始化脚本。
2.  在 `docker-compose.yml` 文件中，将 `db` 服务的 `image` 配置项注释掉，并取消 `build: .` 的注释。
3.  执行 `docker compose build` 来构建您自己的镜像。
4.  执行 `docker compose up -d` 启动服务。

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
