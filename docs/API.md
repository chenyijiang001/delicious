# Delicious - API 文档

Base URL: `http://localhost:8000/api/v1`

## 认证

所有 `/foods` 和 `/ai` 接口需要 `Authorization: Bearer <token>` 请求头。

### POST /auth/register
注册新用户。

```
Request:
{
  "email": "user@example.com",
  "nickname": "美食家小王",
  "password": "123456"
}

Response 201:
{
  "access_token": "eyJ...",
  "token_type": "bearer",
  "user": {
    "id": "uuid",
    "email": "user@example.com",
    "nickname": "美食家小王"
  }
}
```

### POST /auth/login
登录。

```
Request:
{
  "email": "user@example.com",
  "password": "123456"
}

Response 200:
{
  "access_token": "eyJ...",
  "token_type": "bearer",
  "user": { ... }
}
```

## AI 识别

### POST /ai/recognize
上传食物图片，返回 AI 识别结果。

```
Request: multipart/form-data
  image: <binary file>

Response 200:
{
  "dish_name": "番茄炒蛋",
  "category": "家常菜",
  "ingredients": [
    {"name": "番茄", "amount": 2, "unit": "个", "estimated_price": 3.0},
    {"name": "鸡蛋", "amount": 3, "unit": "个", "estimated_price": 2.5}
  ],
  "steps": [
    {"step_num": 1, "description": "鸡蛋打散加盐", "duration_minutes": 2},
    {"step_num": 2, "description": "番茄切块", "duration_minutes": 2}
  ],
  "total_cost": 8.5,
  "serving_size": 2,
  "difficulty": "简单",
  "tips": ["鸡蛋先炒盛出再炒番茄口感更嫩"],
  "image_url": "http://minio:9000/delicious-images/foods/xxx.jpg",
  "thumbnail_url": "http://minio:9000/delicious-images/foods/xxx_thumb.jpg"
}
```

## 美食记录

### GET /foods
获取当前用户的美食记录列表。

```
Query: ?page=1&size=20&q=番茄&category=家常菜

Response 200:
{
  "items": [ FoodRecord ],
  "total": 100,
  "page": 1,
  "size": 20
}
```

### GET /foods/:id
获取单条记录详情。

### POST /foods
保存新的美食记录。

```
Request:
{
  "image_url": "http://...",
  "thumbnail_url": "http://...",
  "dish_name": "番茄炒蛋",
  "category": "家常菜",
  "ingredients": [...],
  "steps": [...],
  "total_cost": 8.5,
  "serving_size": 2,
  "difficulty": "简单",
  "tips": [...],
  "notes": "妈妈的味道"
}

Response 201: FoodRecord
```

### PUT /foods/:id
更新记录（仅需传要修改的字段）。

### DELETE /foods/:id
删除记录。Response 204。

## 健康检查

### GET /health
```
Response: {"status": "ok", "app": "Delicious API"}
```

## 错误码

| 状态码 | 说明 |
|--------|------|
| 400 | 请求参数错误 |
| 401 | 未认证或 Token 过期 |
| 404 | 记录不存在 |
| 409 | 邮箱已注册 |
| 413 | 图片过大 |
| 502 | AI 服务调用失败 |
