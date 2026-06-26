# Delicious - 部署文档

## 前置条件

- Docker & Docker Compose
- OpenAI API Key

## 本地开发

### 1. 启动基础设施

```bash
cd backend
docker compose up -d db redis minio
```

### 2. 初始化 Python 环境

```bash
cd backend
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt

# 数据库迁移
alembic upgrade head

# 启动 API 服务
uvicorn app.main:app --reload --port 8000
```

### 3. 设置环境变量

```bash
export OPENAI_API_KEY=sk-xxx
```

或在 `backend/.env` 文件中：

```env
OPENAI_API_KEY=sk-xxx
DATABASE_URL=postgresql+asyncpg://delicious:password@localhost:5432/delicious
REDIS_URL=redis://localhost:6379/0
S3_ENDPOINT=http://localhost:9000
S3_ACCESS_KEY=minioadmin
S3_SECRET_KEY=minioadmin
S3_BUCKET=delicious-images
JWT_SECRET=dev-secret-do-not-use-in-prod
```

### 4. 完整 Docker 启动

```bash
cd backend
OPENAI_API_KEY=sk-xxx docker compose up -d
```

### 5. 验证

```bash
curl http://localhost:8000/api/v1/health
# {"status":"ok","app":"Delicious API"}
```

MinIO 控制台：http://localhost:9001 (minioadmin / minioadmin)

## 生产部署

### 环境变量（必须修改）

```env
OPENAI_API_KEY=sk-xxx        # 必填
JWT_SECRET=<随机生成64字符>
DATABASE_URL=postgresql+asyncpg://user:pass@host:5432/delicious
S3_ENDPOINT=https://xxx.r2.cloudflarestorage.com
S3_ACCESS_KEY=xxx
S3_SECRET_KEY=xxx
S3_BUCKET=delicious-images
```

### Docker 部署

```bash
docker compose -f docker-compose.prod.yml up -d
```

### Nginx 反向代理

```nginx
server {
    listen 443 ssl;
    server_name api.delicious.app;

    location / {
        proxy_pass http://127.0.0.1:8000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        client_max_body_size 10M;
    }
}
```

### CI/CD (GitHub Actions)

```yaml
name: Deploy
on:
  push:
    branches: [main]
jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Deploy
        run: |
          ssh server "cd /app/delicious && git pull && docker compose up -d --build"
```

## Flutter 打包

### iOS
```bash
cd app
flutter build ios --release
# 然后用 Xcode Archive + 上传 App Store
```

### Android
```bash
cd app
flutter build apk --release   # APK
flutter build appbundle        # Play Store
```
