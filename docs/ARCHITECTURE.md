# Delicious - 架构设计文档

## 架构概览

```
┌──────────────────────┐
│   Flutter Client     │  Dart, Riverpod
│  (iOS + Android)     │
└─────────┬────────────┘
          │ HTTPS / REST
          ▼
┌──────────────────────┐
│   FastAPI Gateway     │  Python 3.12
│   (REST API)          │  CORS, JWT Auth
└──┬───────┬───────┬───┘
   │       │       │
   ▼       ▼       ▼
┌────┐ ┌─────┐ ┌──────┐
│ PG │ │Redis│ │S3/R2 │
└────┘ └─────┘ └──────┘
   ▲
   │ (AI 调用)
   ▼
┌──────────┐
│ OpenAI   │
│ Vision   │
└──────────┘
```

## 技术决策

### Flutter (客户端)
- **状态管理**: Riverpod — 编译安全、可测试、无 BuildContext 依赖
- **HTTP**: Dio — 拦截器、重试、文件上传
- **图片**: image_picker (相机/相册) + flutter_image_compress (压缩)
- **分享**: share_plus (系统分享面板)

### FastAPI (后端)
- **异步**: asyncpg + SQLAlchemy 2.0 async
- **认证**: JWT (python-jose) + bcrypt (passlib)
- **AI**: OpenAI Python SDK, `response_format: json_object`
- **文件**: boto3 → MinIO (开发) / R2 (生产)
- **缓存**: Redis → ai:recipe:{hash} 缓存 24h

## 数据流

### AI 识别流程
```
1. 客户端压缩图片 (1024px, JPEG 85%)
2. POST /api/v1/ai/recognize (multipart)
3. 后端校验 (格式、大小 <10MB)
4. 计算图片 SHA256 → 查 Redis 缓存
5. ⌃ 命中缓存 → 直接返回
6. ⌃ 未命中 → 调用 OpenAI Vision
7. 解析 JSON 响应
8. 写入 Redis 缓存 (24h TTL)
9. 上传原图+缩略图到 S3
10. 返回结果 + image_urls
```

### 保存记录流程
```
1. 前端展示 AI 结果
2. 用户确认/编辑
3. POST /api/v1/foods (含 image_url)
4. 后端写入 PostgreSQL
5. 首页列表刷新
```

## 安全

- 密码 bcrypt 哈希存储
- JWT 24h 过期
- 用户只能访问自己的美食记录
- 图片上传限制 10MB，仅允许 image/* 类型
- OpenAI API Key 仅存后端，不暴露给客户端
- CORS 生产环境限制具体域名

## 性能优化

- AI 结果按图片 hash 缓存在 Redis，避免重复调用
- 客户端压缩图片至 ~300KB，加速上传
- 列表接口分页（默认 20 条）
- 缩略图 400px 宽，列表加载更快
- PostgreSQL JSONB 字段建 GIN 索引可支持未来全文搜索
