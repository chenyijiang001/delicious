# Delicious API 文档

> 版本: v2.1 (2026-06-30 修订，配合 PRD v2 + V1.1 购物建议)
> Base URL: `http://localhost:8000/api/v1`

## 通用约定

- 所有非 `/auth/*`、`/health` 接口都需要 `Authorization: Bearer <token>`
- 时间字段统一 ISO 8601（UTC）：`2026-06-30T12:34:56Z`
- 金额字段单位「元」，浮点保留 2 位小数
- 分页：`?page=1&size=20`，响应固定 `{items, total, page, size}` 结构
- 失败响应统一：`{"detail": "<msg>", "code": "<machine_code>"}`

## 错误码

| HTTP | code | 说明 |
|---|---|---|
| 400 | bad_request | 请求参数错误 |
| 401 | unauthenticated | 未登录或 token 过期 |
| 403 | forbidden | 无权访问该资源（非本人） |
| 404 | not_found | 资源不存在 |
| 409 | conflict | 邮箱已注册 / 资源冲突 |
| 413 | payload_too_large | 图片或请求体过大 |
| 422 | validation_error | 字段校验失败 |
| 429 | rate_limited | 触发限流 |
| 422 | location_required | 购物建议接口未传位置且未传 city_code (V1.1) |
| 502 | ai_upstream_error | OpenAI 调用失败 |
| 502 | poi_upstream_error | 高德 POI API 失败 (V1.1) |
| 503 | service_unavailable | 后端服务暂不可用 |

---

## 1. 认证

### POST /auth/register
注册新用户。
```json
Request:
{ "email": "user@example.com", "nickname": "美食家小王", "password": "123456" }

Response 201:
{
  "access_token": "eyJ...",
  "token_type": "bearer",
  "user": { "id": "uuid", "email": "...", "nickname": "..." }
}
```

### POST /auth/login
```json
Request:  { "email": "...", "password": "..." }
Response 200: { "access_token": "...", "token_type": "bearer", "user": {...} }
```

### POST /auth/logout
清理服务端会话（V1.0 仅作占位，客户端丢弃 token 即可）。Response 204。

---

## 2. AI 识别

### POST /ai/recognize
上传食物图片，返回完整食谱。会自动用用户的个人价格表覆盖 AI 估算（见 §6）。

```
Request: multipart/form-data
  image: <binary file, <= 10MB, image/*>

Response 200:
{
  "dish_name": "番茄炒蛋",
  "category": "家常菜",
  "ingredients": [
    {
      "name": "番茄",
      "amount": 2,
      "unit": "个",
      "estimated_price": 3.0,
      "price_source": "user"    // "ai" | "user"，user 表示来自个人价格表覆盖
    },
    {
      "name": "鸡蛋",
      "amount": 3,
      "unit": "个",
      "estimated_price": 2.5,
      "price_source": "ai"
    }
  ],
  "steps": [
    { "step_num": 1, "description": "鸡蛋打散加盐", "duration_minutes": 2 },
    { "step_num": 2, "description": "番茄切块",     "duration_minutes": 2 }
  ],
  "total_cost": 8.5,
  "serving_size": 2,
  "difficulty": "简单",
  "tips": ["鸡蛋先炒盛出再炒番茄口感更嫩"],
  "image_url": "https://.../foods/xxx.jpg",
  "thumbnail_url": "https://.../foods/xxx_thumb.jpg",
  "cache_hit": false,            // 是否命中 Redis 缓存
  "latency_ms": 4321             // 后端整体耗时，用于客户端埋点
}

Response 422:
{ "detail": "图片中未识别到食物", "code": "no_food_detected" }
```

非食物图统一返回 422 + `code: "no_food_detected"`，由 prompt 强制要求 AI 自检后返回。

### POST /ai/feedback
用户反馈识别不准。用于 prompt 迭代和 bad-case 沉淀。

```json
Request:
{
  "food_id": "uuid | null",          // 已保存的记录，可空
  "image_url": "https://...",        // 未保存场景必填，便于回看原图
  "reasons": ["wrong_dish", "wrong_ingredients", "wrong_steps", "wrong_cost", "other"],
  "comment": "把番茄炒蛋识别成红烧肉了"
}

Response 201:
{ "id": "uuid", "created_at": "2026-06-30T..." }
```

---

## 3. 美食记录

### GET /foods
分页查询当前用户的美食记录。

| Query | 类型 | 说明 |
|---|---|---|
| `page` | int | 默认 1 |
| `size` | int | 默认 20，最大 50 |
| `q` | string | 按菜名/备注模糊搜索 |
| `category` | string | 分类筛选 |
| `ingredient` | string | **新增**：按材料名搜索（用规范化后的名字精确匹配，e.g. `?ingredient=番茄`） |
| `from` | date | 起始日期（含），按 `cooked_at` 筛选 |
| `to` | date | 结束日期（含） |

```json
Response 200:
{
  "items": [ FoodRecord, ... ],
  "total": 100, "page": 1, "size": 20
}
```

### GET /foods/:id
单条详情。

### POST /foods
保存新记录。`from` 字段标识来源：`recognize` | `manual` | `duplicate`。

```json
Request:
{
  "image_url": "...", "thumbnail_url": "...",
  "dish_name": "番茄炒蛋", "category": "家常菜",
  "ingredients": [...], "steps": [...],
  "total_cost": 8.5, "serving_size": 2, "difficulty": "简单",
  "tips": [...], "notes": "妈妈的味道",
  "cooked_at": "2026-06-30",        // 可选，默认 today
  "from": "recognize"
}

Response 201: FoodRecord
Response 200 with duplicate hint:
{
  "duplicate_of": "uuid",
  "similarity": 0.92,
  "candidate": FoodRecord
}
// 检测到同月内有近似记录时返回 200 而非 201，客户端弹窗询问「更新已有记录还是新建」。
// 客户端可在请求 query 加 `?force=true` 强制新建。
```

### PUT /foods/:id
更新记录。**仅传需修改的字段**（PATCH 语义）。

### DELETE /foods/:id
Response 204。

### POST /foods/:id/duplicate
「再做一次」：复制为今天的新记录。

```json
Request:
{ "serving_size": 4 }   // 可选，传则按比例缩放材料数量和总成本

Response 201: FoodRecord   // 新记录，cooked_at = today, from = "duplicate"
```

---

## 4. 购物清单

购物清单是用户级别的单列表（V1.0 不做多列表）。

### GET /shopping/items
```json
Response 200:
{
  "items": [
    {
      "id": "uuid",
      "name": "番茄",
      "amount": 5,
      "unit": "个",
      "estimated_price": 7.5,
      "checked": false,
      "source": "auto" | "manual",
      "from_food_ids": ["uuid", ...],     // 该条目由哪些菜累加而来
      "created_at": "2026-06-30T..."
    }
  ],
  "total_estimated_cost": 42.0,
  "unchecked_count": 8
}
```

### POST /shopping/items/from-food
从一条美食记录批量加入。后端按 §7.2 的合并算法去重相加。

```json
Request: { "food_id": "uuid" }
Response 200:
{
  "added_count": 3,
  "merged_count": 2,
  "items": [ ... 完整最新清单 ... ]
}
```

### POST /shopping/items
手动添加一条。
```json
Request: { "name": "盐", "amount": 1, "unit": "袋", "estimated_price": 2 }
Response 201: ShoppingItem
```

### PATCH /shopping/items/:id
更新数量、勾选、备注。
```json
Request: { "amount": 6, "checked": true }
```

### DELETE /shopping/items/:id
单条删除。Response 204。

### POST /shopping/clear-checked
一键清空已勾选。
```json
Response 200: { "deleted_count": 5 }
```

### GET /shopping/export
导出为可分享文本。
```json
Query: ?format=text
Response 200:
{ "text": "🛒 购物清单 (2026-06-30)\n- 番茄 × 5个\n- 鸡蛋 × 6个\n..." }
```

### POST /shopping/buy-suggestions  *(V1.1)*
"看看去哪买"——基于当前购物清单 + 用户位置，返回附近超市、配送到家、外卖买菜三个渠道的去处推荐，并由 AI 合成一句话最优策略。

#### Request
```json
{
  "location": { "lat": 31.23, "lng": 121.47 } | null,
  "city_code": "021",                        // 无定位时必填，"021" 即 adcode
  "channels": ["offline", "online", "delivery"],   // 默认全选
  "radius_m": 1500                           // offline 渠道的搜索半径，默认 1500，最大 5000
}
```

校验规则：
- `location` 与 `city_code` 至少传一项；都传则以 `location` 为准
- `lat` ∈ [-90, 90]，`lng` ∈ [-180, 180]
- 后端落库前坐标精度脱敏到 100m（约小数点后 3 位），细节见 [ARCHITECTURE §5]

#### Response 200
```json
{
  "ai_suggestion": "永辉买 7 项 + 叮咚补紫苏，约 ¥40 最省",
  "items_total": 8,
  "offline": [
    {
      "poi_id": "B0FFH...",
      "name": "永辉超市（大宁店）",
      "category": "supermarket",     // supermarket / convenience / market / fresh
      "distance_m": 220,
      "address": "上海市静安区大宁路 1898 号",
      "coverage": {
        "matched": 7,
        "total": 8,
        "missing": ["紫苏"]
      },
      "estimated_cost": 34.0,
      "navigate_url": "https://uri.amap.com/marker?position=..."
    }
  ],
  "online": [
    {
      "platform": "hema",            // hema / dingdong / pupu
      "platform_name": "盒马鲜生",
      "coverage": { "matched": 8, "total": 8, "missing": [] },
      "estimated_eta_minutes": 30,
      "scheme": "hema://...",        // 优先 deeplink
      "web_fallback": "https://www.hemaos.com/..."
    }
  ],
  "delivery": [
    {
      "platform": "meituan_maicai",
      "platform_name": "美团买菜",
      "coverage": { "matched": 6, "total": 8, "missing": ["紫苏", "豆瓣酱"] },
      "scheme": "meituanwaimai://...",
      "web_fallback": "https://i.meituan.com/..."
    }
  ],
  "cache_hit": {                     // 透出用于成本观测
    "alias": true,
    "poi": true,
    "coverage": false,
    "suggestion": false
  }
}
```

#### Response 422 - 无法定位
```json
{ "detail": "需要位置信息或城市编码", "code": "location_required" }
```

#### Response 502 - 高德 / OpenAI 上游失败
退化为仅返回 `offline` 列表（不带 AI 文案）；客户端按是否含 `ai_suggestion` 字段区分。

### POST /shopping/buy-suggestions/click  *(V1.1)*
跳转点击埋点。客户端点击任一店铺/平台跳转前调用，1xx/2xx 都返回 204 后再发起跳转。

```json
Request:
{
  "channel": "offline" | "online" | "delivery",
  "target": "<poi_id 或 platform>",
  "missing_count": 1
}
Response 204
```

> 说明：这是单独的轻量埋点接口，不走 `/events`，因为它需要立即可分析（联盟分佣对账的雏形）。

---

## 5. 个人价格表

### GET /user/ingredient-prices
```json
Response 200:
{
  "items": [
    {
      "id": "uuid",
      "name": "番茄",
      "unit": "个",
      "unit_price": 1.5,            // 每单位价格
      "last_used_at": "2026-06-29T...",
      "source": "user_edit" | "user_confirm"   // 主动改的 vs 直接采纳的
    }
  ]
}
```

### POST /user/ingredient-prices
新增或覆盖（同 name + unit upsert）。
```json
Request: { "name": "番茄", "unit": "个", "unit_price": 1.5 }
Response 200: IngredientPrice
```

### DELETE /user/ingredient-prices/:id
Response 204。

> 说明：`/foods` 的 PUT 更新材料价格时，后端会自动 upsert 到本表，前端不必显式调用。

---

## 6. 成本统计

### GET /stats/cost
```json
Query: ?range=week | month   // 默认 week
Response 200:
{
  "range": "week",
  "start": "2026-06-24",
  "end":   "2026-06-30",
  "total_cost": 156.5,
  "record_count": 9,
  "avg_per_meal": 17.4,
  "top_expensive": [ { "food_id": "...", "dish_name": "佛跳墙", "cost": 88 }, ... ],
  "top_cheap":     [ { "food_id": "...", "dish_name": "凉拌黄瓜", "cost": 4 }, ... ],
  "by_category":   [ { "category": "家常菜", "cost": 60.5, "ratio": 0.39 }, ... ],
  "by_day":        [ { "date": "2026-06-24", "cost": 22.0 }, ... ]
}
```

---

## 7. 埋点

### POST /events
批量上报客户端埋点。客户端每 30s 或 50 条触发一次。

```json
Request:
{
  "events": [
    {
      "name": "recognize_done",
      "ts": "2026-06-30T12:34:56Z",
      "props": { "latency_ms": 4321, "cache_hit": false }
    },
    {
      "name": "food_save",
      "ts": "2026-06-30T12:35:10Z",
      "props": { "from": "recognize" }
    }
  ]
}

Response 202: { "accepted": 2 }
```

事件名清单见 PRD §9。后端只做接收 + 写入 `events` 表，不参与业务逻辑。

---

## 8. 健康检查

### GET /health
```json
Response 200: { "status": "ok", "app": "Delicious API", "version": "v1.0.0" }
```

---

## 9. 数据结构参考

### FoodRecord
```json
{
  "id": "uuid",
  "user_id": "uuid",
  "image_url": "...", "thumbnail_url": "...",
  "dish_name": "番茄炒蛋",
  "category": "家常菜",
  "ingredients": [
    { "name": "...", "amount": 2, "unit": "个", "estimated_price": 3.0, "price_source": "ai" }
  ],
  "steps": [ { "step_num": 1, "description": "...", "duration_minutes": 2 } ],
  "tips": ["..."],
  "total_cost": 8.5,
  "serving_size": 2,
  "difficulty": "简单",
  "notes": "妈妈的味道",
  "cooked_at": "2026-06-30",
  "from": "recognize",
  "created_at": "...", "updated_at": "..."
}
```

### ShoppingItem
见 §4。

### IngredientPrice
见 §5。
