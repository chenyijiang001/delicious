# Delicious - AI 美食记录

拍照即得食谱。AI 自动识别食物，生成制作步骤、耗材清单和成本估算。

## 技术栈

| 层 | 技术 |
|---|------|
| 客户端 | Flutter 3.x + Riverpod |
| 后端 | Python FastAPI |
| AI | OpenAI GPT-4o Vision |
| 数据库 | PostgreSQL + Redis |
| 存储 | MinIO (dev) / Cloudflare R2 (prod) |

## 快速开始

```bash
# 启动后端
cd backend
OPENAI_API_KEY=sk-xxx docker compose up -d

# 启动 Flutter
cd app
flutter run
```

## 项目结构

```
delicious/
├── app/          # Flutter 客户端 (iOS + Android)
├── backend/      # Python FastAPI
└── docs/         # 文档
```
