# Delicious 架构设计文档

> 版本: v2.1 (2026-06-30 修订，配合 PRD v2 + V1.1 购物建议)

## 1. 架构概览

```
┌──────────────────────┐
│   Flutter Client     │  Dart, Riverpod, GoRouter
│  (iOS + Android)     │  本地草稿 (Hive) + 埋点批量上报 + 定位
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
   │           alias:{name}                (30d, 食材语义归类)
   │           poi:{geohash5}:{r}:{cat}    (6h, 高德 POI)
   │           coverage:{ings}:{pois}      (24h, 覆盖度)
   │           suggest:{user}:{ings}:{loc} (4h, AI 推荐文案)
   │           shopping:lock:{user_id}
   │           ratelimit:{user_id}:{api}
   │
   │ (AI 调用)                    (POI 调用，V1.1)
   ▼                              ▼
┌──────────┐                ┌──────────┐
│ OpenAI   │  Vision        │ 高德     │  Web API: POI/导航
└──────────┘                └──────────┘
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

**ingredient_aliases** *(V1.1)*
食材语义归类的"知识库"，所有用户共用。冷启动靠 AI 填，命中即固化。
| 列 | 类型 | 备注 |
|---|---|---|
| id | uuid PK | |
| alias | text | "西红柿" "圣女果" |
| alias_normalized | text | UNIQUE，规范化后用于查找 |
| canonical | text | "番茄"（标准品类） |
| canonical_category | text | "蔬菜/茄科"（用于 POI 覆盖度判断） |
| store_type_coverage | jsonb | `{"convenience": false, "supermarket": true, "market": true, "fresh": true}` |
| confidence | numeric(3,2) | AI 输出的置信度，<0.7 时不固化、每次重查 |
| created_at, updated_at | timestamptz | |

**pois_cache** *(V1.1)*
高德 POI 结果按 geohash 缓存。
| 列 | 类型 | 备注 |
|---|---|---|
| id | text PK | 高德 poi_id |
| name | text | |
| category | text | supermarket / convenience / market / fresh |
| lat, lng | numeric(9,6) | 完整精度（仅服务端用） |
| city_code | text | |
| address | text | |
| business_hours | jsonb | |
| geohash5 | char(5) | INDEX，按位置批量查 |
| cached_at | timestamptz | |

`geohash5` 精度约 5km，能批量缓存一片区域；查询时取用户当前 geohash5 + 周围 8 个邻居。

**purchase_clicks** *(V1.1)*
跳转点击埋点，跟 events 分开存——它是分佣对账的雏形，需要独立可分析。
| 列 | 类型 | 备注 |
|---|---|---|
| id | bigserial PK | |
| user_id | uuid | INDEX |
| channel | text | offline / online / delivery |
| target | text | poi_id 或 platform 名 |
| missing_count | int | 该店覆盖不到的食材数（用于评估"用户因为缺货而被迫多平台采购"的比例） |
| ts | timestamptz | INDEX |

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

## 5. 购物建议系统 *(V1.1)*

让用户从"列清单"走到"真的买到"。AI 的核心价值是**判断这一整张清单去哪儿买最高效**，不是查单品门店——后者地图 API 就能做。

### 5.1 端到端数据流

```
[shopping_screen] 用户点 "看看去哪买"
       │
       ▼
[POST /shopping/buy-suggestions]
       │
       ├─ 1. 食材规范化
       │     ├─ 命中 ingredient_aliases  → 直接取 canonical
       │     └─ 未命中 → AI 调用 → 写表（confidence ≥ 0.7 才固化）
       │
       ├─ 2. POI 查询（仅 offline 渠道）
       │     ├─ 命中 Redis poi:{geohash5}:{r}:{cat} → 取 (6h TTL)
       │     └─ 未命中 → 高德 Web API → 写 pois_cache + Redis
       │
       ├─ 3. 覆盖度判断
       │     ├─ key = sha1(canonical_ings + sorted poi_ids)
       │     ├─ 命中 Redis coverage:{key} → 取 (24h TTL)
       │     └─ 未命中 → 规则（按 store_type_coverage 比对）+ 必要时 AI 兜底
       │
       ├─ 4. AI 一句话推荐
       │     ├─ key = sha1(user_id + canonical_ings + geohash5)
       │     ├─ 命中 Redis suggest:{key} → 取 (4h TTL)
       │     └─ 未命中 → OpenAI 调用 → 写 Redis
       │
       └─ 5. 组装 deeplink → 返回
```

### 5.2 4 层缓存策略

| 层 | key | TTL | 命中率目标 | 用途 |
|---|---|---|---|---|
| L1 食材别名 | DB `ingredient_aliases` + Redis `alias:{normalize(name)}` | 永久 + 30 天 | ≥ 95% | 跨用户共享，1 次 AI 后永久受益 |
| L2 POI 列表 | Redis `poi:{geohash5}:{radius}:{cat}` | 6h | ≥ 70% | 同片区不同用户共享 |
| L3 覆盖度 | Redis `coverage:{sha1(ings,pois)}` | 24h | ≥ 50% | 相同清单 + 相同店铺组合共享 |
| L4 AI 文案 | Redis `suggest:{user}:{sha1(ings,loc)}` | 4h | ≥ 30% | 用户级，4h 内重复打开免费 |

冷启动用户单次 ~3 次外部调用（1 次 AI 别名 + 1 次高德 + 1 次 AI 文案，且常 alias 已命中）；命中后趋近 0。整体目标 OpenAI / 高德调用量 < 1% 的请求数。

### 5.3 高德 POI 调用

- 单次请求最多取 25 条 POI，按 `distance` ASC
- 类型 typeCode 白名单：`060100`（超市）、`060101`（便利店）、`060102`（菜市场）、`060103`（生鲜专卖）
- 每条结果 normalize 成内部 category 后入 `pois_cache`
- 5000 次/日免费额度，配合 6h 缓存 + 5km geohash 批量取，估算可支撑 ~30000 DAU
- 上量后可走付费版（¥0.012/次）或迁腾讯/百度

### 5.4 AI 推荐 prompt（核心摘要）

```
你是购物路线规划助手。基于以下信息给出一句中文推荐（≤30 字）：
- 用户购物清单（已规范化）：["番茄","紫苏","鸡蛋",...]
- 附近店铺及其覆盖度：[{"name":"永辉","matched":7,"missing":["紫苏"],"cost":34}, ...]
- 候选线上平台：[{"name":"叮咚买菜","matched":8,"eta":30,"cost":42}, ...]

输出严格 JSON：{"suggestion":"...", "primary_store":"<name>", "supplement":[...]}
```

### 5.5 跳转与 deeplink

- 平台模板存 `backend/configs/store_deeplinks.yml`：
  ```yaml
  hema:
    scheme: hema://search?keyword={query}
    web_fallback: https://www.hemaos.com/search?q={query}
    cities: [021, 010, 0755, ...]
  meituan_maicai:
    scheme: meituanwaimai://search?q={query}
    web_fallback: https://i.meituan.com/maicai?q={query}
    cities: all
  ```
- 按用户 `city_code` 过滤可用平台（叮咚仅一线 + 杭州，朴朴仅福建 + 几个新一线）
- 客户端先尝试 scheme，失败由 `url_launcher` 走 `web_fallback`
- 跳转前必发 `/shopping/buy-suggestions/click`，独立写 `purchase_clicks` 表

### 5.6 隐私与位置脱敏

- **存储脱敏**：`pois_cache.lat/lng` 完整精度（数据本身就是商业 POI）；`purchase_clicks` 不存坐标
- **API 输入**：客户端传完整 lat/lng，但服务端落 events 表前精度降到 100m（lat/lng 保留 3 位）
- **缓存 key 脱敏**：suggest key 用 geohash5（约 5km）而非完整坐标，避免反向定位
- **用户控制**：「我的」→「隐私」→「清空我的位置数据」按钮（V1.1 stub，仅删 events 里的位置字段）

### 5.7 失败降级链

| 故障 | 行为 | 用户感知 |
|---|---|---|
| 高德 POI 失败 | 返回最新的 stale 缓存（即使过期） + 响应里加 `stale: true` | 数据可能旧但仍可用 |
| 高德 + 缓存都没数据 | offline 列表返回空，仅展示 online/delivery Tab | "附近没找到，试试配送" |
| OpenAI 失败 | 不生成 `ai_suggestion`，offline/online/delivery 数据照常 | 看不到一句话推荐，但 Tab 完整 |
| Redis 不可用 | 直接调源 + 失败兜底；功能可用，性能下降 | 慢 1~2s |
| 用户拒绝位置授权 | 走 `city_code`，POI 按城市级别返回（精度差） | 仍能用，但不如带定位准 |

## 6. 安全

- 密码 bcrypt（cost 12）
- JWT 24h 过期，HS256，秘钥仅在 env
- 行级权限：所有 `/foods/*`、`/shopping/*`、`/user/*`、`/ai/feedback` 必查 `user_id == jwt.sub`
- 图片上传：白名单 image/jpeg、image/png、image/webp；大小 ≤ 10MB；存储路径含随机 nonce 防猜测
- 限流（Redis 滑动窗口）：
  - `/ai/recognize` 20 次 / 小时 / 用户
  - `/auth/login` 10 次 / 5 分钟 / IP
  - `/shopping/buy-suggestions` 60 次 / 小时 / 用户 (V1.1)
  - `/shopping/buy-suggestions/click` 60 次 / 小时 / 用户 (V1.1，防刷分佣对账)
- CORS 生产环境白名单具体域名
- **第三方密钥仅后端持有**：OpenAI Key、高德 Web API Key 永不下发客户端
- 用户主动删除账号时，级联删除所有 food_records / shopping / prices / feedback / events / purchase_clicks（V1.0 留 API stub，UI 不暴露）

## 7. 性能优化

- AI 结果按图片 SHA256 缓存 Redis 24h（不含个人价格覆盖）
- 缩略图 400px 宽，列表用 thumbnail_url
- 客户端压缩到 ~300KB 再上传
- 列表分页默认 20，最大 50
- jsonb 食材搜索靠 `jsonb_path_ops` GIN 索引；冷启动可考虑物化视图（V1.1 再评估）
- `/stats/cost` 单次查询全表聚合，预计 < 1k 条不算瓶颈；上量后改为每日定时预聚合到 cost_daily 物化视图
- 埋点 events 表按月分区（pg_partman），便于冷数据归档
- **购物建议** *(V1.1)*：4 层缓存，POI 用 5km geohash 批量取，相同片区内不同用户共享，目标外部调用率 < 1% of QPS

## 8. 兼容性与迁移

V1.0 相对初版的迁移：
1. `food_records.ingredients` jsonb 新增 `price_source` 字段（默认 `"ai"`）
2. 新表：`shopping_list_items` / `user_ingredient_prices` / `ai_feedback` / `events`
3. 新字段：`food_records.from`、`food_records.cooked_at`（旧数据回填为 created_at 当天）

V1.1 相对 V1.0 的迁移：
1. 新表：`ingredient_aliases` / `pois_cache` / `purchase_clicks`
2. 后端新增配置文件 `backend/configs/store_deeplinks.yml`
3. 后端新增环境变量 `AMAP_API_KEY`

迁移均用 alembic 单次脚本完成，无需停机。

## 9. 监控与告警（V1.1 落地）

- OpenAI / 高德 调用耗时 / 失败率 / 缓存命中率 → Prometheus + Grafana
- API P95 延迟 / 5xx 比例
- 用户漏斗（基于 events 表）：拍照启动 → 识别成功 → 保存
- 购物建议漏斗（V1.1）：buy_suggest_open → buy_suggest_click → 7 日内回访
- 关键告警：
  - `/ai/recognize` 失败率 > 10% 持续 5min
  - DB 连接池 > 80%
  - 高德调用 > 4000 次/日（接近免费额度上限）
  - AI 文案缓存命中率 < 70%（异常成本）
