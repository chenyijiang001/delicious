# Delicious 架构设计文档

> 版本: v2 (2026-06-30 修订，配合 PRD v2 / API v2)

## 1. 架构概览

```
┌──────────────────────┐
│   Flutter Client     │  Dart, Riverpod, GoRouter
│  (iOS + Android)     │  本地草稿 (Hive) + 埋点批量上报
└─────────┬────────────┘
          │ HTTPS / REST
          ▼
┌──────────────────────┐
│   FastAPI Gateway    │  Python 3.12
│   (REST API)         │  JWT, CORS, RateLimit
└──┬───────┬───────┬───┘
   │       │       │
   ▼       ▼       ▼
┌────┐ ┌─────┐ ┌──────┐
│ PG │ │Redis│ │S3/R2 │
└────┘ └─────┘ └──────┘
   ▲       ▲
   │       └── ai:recipe:{hash}            (24h)
   │           shopping:lock:{user_id}     (合并互斥)
   │           ratelimit:{user_id}:{api}
   │
   │ (AI 调用)
   ▼
┌──────────┐
│ OpenAI   │  Vision (gpt-4o), response_format=json_object
└──────────┘
```

## 2. 技术栈

### Flutter（客户端）
- **状态管理**：Riverpod
- **路由**：GoRouter（底部 Tab + 子页面 push）
- **HTTP**：Dio + 拦截器（token 注入、统一错误码、埋点）
- **本地存储**：Hive（识别后未保存的草稿、待上报埋点）
- **图片**：image_picker + flutter_image_compress（1024px, JPEG 85%）
- **分享**：share_plus

### FastAPI（后端）
- **异步**：asyncpg + SQLAlchemy 2.0 async
- **认证**：JWT (python-jose) + bcrypt (passlib)
- **AI**：OpenAI Python SDK
- **存储**：boto3 → MinIO (dev) / R2 (prod)
- **缓存与限流**：Redis（aiocache + slowapi）
- **任务队列**：本期不引入；周报推送 V1.1 再加 APScheduler 或 Celery

## 3. 数据模型

### 3.1 ER 简图
```
users ──┬─< food_records >── (jsonb: ingredients, steps, tips)
        ├─< shopping_list_items
        ├─< user_ingredient_prices
        ├─< ai_feedback
        └─< events
```

### 3.2 表结构

**users**
| 列 | 类型 | 备注 |
|---|---|---|
| id | uuid PK | |
| email | text UNIQUE | |
| nickname | text | |
| password_hash | text | bcrypt |
| created_at, updated_at | timestamptz | |

**food_records**
| 列 | 类型 | 备注 |
|---|---|---|
| id | uuid PK | |
| user_id | uuid FK | INDEX |
| dish_name | text | |
| category | text | |
| ingredients | jsonb | [{name, amount, unit, estimated_price, price_source}] |
| steps | jsonb | [{step_num, description, duration_minutes}] |
| tips | jsonb | string[] |
| total_cost | numeric(8,2) | |
| serving_size | int | |
| difficulty | text | enum: 简单/中等/困难 |
| notes | text | |
| image_url, thumbnail_url | text | |
| cooked_at | date | INDEX，"再做一次"会创建新行 |
| from | text | recognize / manual / duplicate |
| created_at, updated_at | timestamptz | |

索引：
- `(user_id, cooked_at desc)` — 时间线主查询
- GIN on `ingredients` jsonb_path_ops — `?ingredient=番茄` 食材搜索
- `(user_id, dish_name)` — 复购检测

**shopping_list_items** *(新增)*
| 列 | 类型 | 备注 |
|---|---|---|
| id | uuid PK | |
| user_id | uuid FK | INDEX + UNIQUE (user_id, name_normalized, unit) |
| name | text | 用户可见原文 |
| name_normalized | text | §4.2 规范化算法的输出 |
| amount | numeric(10,2) | |
| unit | text | |
| estimated_price | numeric(8,2) | |
| checked | bool default false | |
| source | text | auto / manual |
| from_food_ids | uuid[] | 记录由哪些菜累加而来 |
| created_at, updated_at | timestamptz | |

**user_ingredient_prices** *(新增)*
| 列 | 类型 | 备注 |
|---|---|---|
| id | uuid PK | |
| user_id | uuid FK | UNIQUE (user_id, name_normalized, unit) |
| name | text | |
| name_normalized | text | |
| unit | text | |
| unit_price | numeric(8,2) | 每单位价格 |
| last_used_at | timestamptz | 每次匹配成功就刷新 |
| source | text | user_edit / user_confirm |
| created_at | timestamptz | |

**ai_feedback** *(新增)*
| 列 | 类型 | 备注 |
|---|---|---|
| id | uuid PK | |
| user_id | uuid FK | |
| food_id | uuid FK NULL | 已保存记录的情况 |
| image_url | text | 未保存场景必填，便于人工回看 |
| reasons | text[] | wrong_dish / wrong_ingredients / wrong_steps / wrong_cost / other |
| comment | text | |
| created_at | timestamptz | |

**events** *(新增，埋点)*
| 列 | 类型 | 备注 |
|---|---|---|
| id | bigserial PK | |
| user_id | uuid NULL | 未登录场景可空 |
| name | text | INDEX |
| ts | timestamptz | INDEX |
| props | jsonb | 任意属性 |

events 表 V1.0 仅供观察 + 离线分析；高峰期上量考虑迁移到 ClickHouse，本期不优化。

## 4. 关键流程

### 4.1 AI 识别（含个人价格覆盖）

```
1. 客户端压缩图片 → POST /ai/recognize
2. 后端校验大小/格式 → 计算 SHA256(image) → 查 Redis ai:recipe:{hash}
3a. 命中 → 拿到 AI 原始结果（缓存里只存 AI 输出，不存个人价格覆盖后的）
3b. 未命中 → 调用 OpenAI Vision → 写 Redis (24h)
4. ★ 个人价格覆盖：
   for ing in result.ingredients:
       key = (user_id, normalize(ing.name), ing.unit)
       price = SELECT unit_price FROM user_ingredient_prices WHERE key
       if price 存在 AND price 在合理区间 (0.2× ~ 5× of AI 估算):
           ing.estimated_price = price * ing.amount
           ing.price_source = "user"
   重算 total_cost
5. 上传原图 + 缩略图到 S3
6. 返回结果 + image_urls + cache_hit + latency_ms
```

**为什么覆盖在响应阶段而不是缓存阶段**：缓存按图片 hash 做，AI 结果可跨用户共享；个人价格是用户私有的，必须在缓存命中后再叠加，否则等价于禁用缓存。

**合理区间检查**：避免单条脏数据污染。如用户误把番茄录成 ¥200/个，下次识别就会得到离谱总价，加 5× 上限挡掉。

### 4.2 购物清单合并算法

输入：一条 food_record 的 ingredients 数组。
对每条 ingredient：

```python
name_norm = normalize(ingredient.name)   # 去空格、繁简归一、小写、去常见后缀
unit      = ingredient.unit
key       = (user_id, name_norm, unit)

# 用 PG 的 ON CONFLICT 做 upsert
INSERT INTO shopping_list_items (user_id, name, name_normalized, amount, unit, ...)
VALUES (...)
ON CONFLICT (user_id, name_normalized, unit) DO UPDATE SET
    amount = shopping_list_items.amount + EXCLUDED.amount,
    estimated_price = shopping_list_items.estimated_price + EXCLUDED.estimated_price,
    from_food_ids = array_append(shopping_list_items.from_food_ids, EXCLUDED.from_food_ids[1]),
    updated_at = now()
WHERE shopping_list_items.checked = false;  -- 已勾选的不再累加，避免买完了又被加进去
```

并发同一用户同时加多条菜时，用 `SET LOCAL lock_timeout = '2s'` + 行级锁规避撕裂。如果未来上量，再加 `shopping:lock:{user_id}` Redis 互斥。

### 4.3 复购检测（POST /foods）

保存时计算与同月同用户记录的相似度：

```
similarity = 0.6 * dish_name_match + 0.4 * ingredients_overlap
- dish_name_match: 完全相等 → 1.0；规范化后相等 → 0.9；编辑距离 ≤ 1 → 0.7；其他 0
- ingredients_overlap: |共有食材| / |并集|，按 name_normalized 计
```

阈值 ≥ 0.85 时返回 200 + duplicate_of/candidate，由客户端二次确认。`?force=true` 直接走 201 新建。

### 4.4 再做一次（POST /foods/:id/duplicate）

```
1. SELECT 原记录
2. 若指定 new_serving_size 且 != 原 serving_size:
       ratio = new / old
       ingredients[].amount *= ratio  (保留 1 位小数)
       ingredients[].estimated_price *= ratio
       total_cost *= ratio
3. INSERT 新记录: cooked_at = today, from = "duplicate"
4. 返回新记录
```

不做食材精确重新询价（如果用户的个人价格表更新过，按 4.1 在下次 /ai/recognize 才生效）。这是为了简单和可预期。

### 4.5 埋点上报

- 客户端写入 Hive 队列
- 触发条件：达到 50 条 OR 距上次上报 30s OR App 进入后台 OR 主动 flush
- POST /events 失败则保留在队列里下次重试
- 服务端只写 events 表，不阻塞业务

## 5. 安全

- 密码 bcrypt（cost 12）
- JWT 24h 过期，HS256，秘钥仅在 env
- 行级权限：所有 `/foods/*`、`/shopping/*`、`/user/*`、`/ai/feedback` 必查 `user_id == jwt.sub`
- 图片上传：白名单 image/jpeg、image/png、image/webp；大小 ≤ 10MB；存储路径含随机 nonce 防猜测
- 限流（Redis 滑动窗口）：
  - `/ai/recognize` 20 次 / 小时 / 用户
  - `/auth/login` 10 次 / 5 分钟 / IP
- CORS 生产环境白名单具体域名
- 用户主动删除账号时，级联删除所有 food_records / shopping / prices / feedback / events（V1.0 留 API stub，UI 不暴露）

## 6. 性能优化

- AI 结果按图片 SHA256 缓存 Redis 24h（不含个人价格覆盖）
- 缩略图 400px 宽，列表用 thumbnail_url
- 客户端压缩到 ~300KB 再上传
- 列表分页默认 20，最大 50
- jsonb 食材搜索靠 `jsonb_path_ops` GIN 索引；冷启动可考虑物化视图（V1.1 再评估）
- `/stats/cost` 单次查询全表聚合，预计 < 1k 条不算瓶颈；上量后改为每日定时预聚合到 cost_daily 物化视图
- 埋点 events 表按月分区（pg_partman），便于冷数据归档

## 7. 兼容性与迁移

V1.0 相对初版的迁移：
1. `food_records.ingredients` jsonb 新增 `price_source` 字段（默认 `"ai"`）
2. 新表：`shopping_list_items` / `user_ingredient_prices` / `ai_feedback` / `events`
3. 新字段：`food_records.from`、`food_records.cooked_at`（旧数据回填为 created_at 当天）

迁移用 alembic 单次脚本完成，无需停机。

## 8. 监控与告警（V1.1 落地）

- OpenAI 调用耗时 / 失败率 → Prometheus + Grafana
- API P95 延迟 / 5xx 比例
- 用户漏斗（基于 events 表）：拍照启动 → 识别成功 → 保存
- 关键告警：`/ai/recognize` 失败率 > 10% 持续 5min；DB 连接池 > 80%
