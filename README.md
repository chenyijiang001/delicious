# Delicious

拍照即所得的美食日记。AI 自动识别菜名、生成材料清单、估算成本、写出制作步骤；记录沉淀为个人菜单，可随时复用、生成购物清单、查看烹饪开销。

> **状态**：V1.0 开发完成进入测试 · V1.1 「看看去哪买」已编码完成 · [Roadmap →](docs/PRD.md#12-roadmap)

## 这个 App 解决什么

> 不是「另一个菜谱社区」，而是**家庭厨房的私人记账本 + 助手**。

| 用户 | 场景 | 我们给的 |
|---|---|---|
| 想发美食日记的设计师 | 拍完做菜的照片就忘 | 一键沉淀完整可复用食谱 + 美观分享卡片 |
| 刚搬出来住的程序员 | 想做饭省钱但不知道买什么 | 购物清单 + 「看看去哪买」+ 成本估算 |
| 全职太太 | 月伙食心里没数 | 成本面板 + 个人价格表 + 复用历史菜谱 |
| 健身教练 meal prep | 同一份菜单要按人数缩放 | 「再做一次」自动缩放材料 |

## 核心特性

### 🤖 AI 拍照识别
拍/选一张菜的图，自动输出：菜名、分类、材料清单（含估价）、制作步骤、总成本、难度、烹饪贴士。**选完图立即识别**，三段式进度文案，识别失败有三个出口（换图 / 手动填 / 反馈）。

### 📝 就地编辑
AI 结果默认就保存，但每个字段都能点击编辑。材料/Tips 增删改，步骤拖拽排序。改过的价格自动写入个人价格表，下次同食材识别更准。

### 🛒 购物清单 + 「看看去哪买」 *(V1.1)*
食谱详情页一键加入购物清单，自动合并同名食材数量。清单顶部「看看去哪买」基于定位 + AI 给出 3 个 Tab：附近超市 / 配送到家 / 外卖买菜，标注每家店覆盖度，AI 一句话推荐最优组合。

### 🔁 再做一次
食谱详情页 FAB「再做一次」，调整人数按比例缩放材料和成本，复制为今天的新记录。

### 💰 成本面板
本周/月烹饪开销、平均每餐、最贵 Top 3、按分类占比、按日柱状图。

### 🔍 按食材搜
首页搜索框可切换菜名/食材模式（"冰箱里有番茄，能做什么？"）。

### 🤖 个人价格记忆
你改过的食材价格会记到个人价格表，下次 AI 识别同食材时用你的价格替换估算（带 0.2x~5x 合理区间防脏数据）。

## 技术栈

| 层 | 技术 |
|---|------|
| 客户端 | Flutter 3.x · Riverpod · GoRouter · Dio · geolocator · url_launcher |
| 后端 | Python 3.12 · FastAPI · SQLAlchemy 2.0 async · asyncpg · alembic |
| AI | OpenAI GPT-4o Vision (`response_format: json_object`) |
| 地图 | 高德 Web API (V1.1) |
| 数据库 | PostgreSQL 15 (JSONB + GIN) |
| 缓存 | Redis 7 (4 层缓存策略) |
| 存储 | MinIO (dev) / Cloudflare R2 (prod) |

## 架构概览

```
┌──────────────────────┐
│   Flutter Client     │  Riverpod, GoRouter, 埋点批量上报
└─────────┬────────────┘
          │ HTTPS / REST
          ▼
┌──────────────────────┐
│   FastAPI Gateway    │  JWT, CORS, RateLimit
└──┬───────┬───────┬───┘
   │       │       │
   ▼       ▼       ▼
┌────┐ ┌─────┐ ┌──────┐
│ PG │ │Redis│ │S3/R2 │
└────┘ └─────┘ └──────┘
   ▲       ▲
   │       └── ai:recipe / alias / poi / coverage / suggest
   │
   ▼ (AI / POI 调用)
┌──────────┐  ┌──────────┐
│ OpenAI   │  │  高德    │
└──────────┘  └──────────┘
```

详见 [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md)。

## 快速开始

### 前置条件

- Docker & Docker Compose
- Python 3.12（如不用 Docker）
- Flutter 3.2+（前端开发）
- **OpenAI API Key**（必需）
- **高德 Web API Key**（V1.1 购物建议必需）— 申请：https://console.amap.com/dev/key

### 1. 启动后端

```bash
cd backend

# 准备 .env
cat > .env <<EOF
OPENAI_API_KEY=sk-xxx
AMAP_API_KEY=你的高德key
DATABASE_URL=postgresql+asyncpg://delicious:password@localhost:5432/delicious
REDIS_URL=redis://localhost:6379/0
S3_ENDPOINT=http://localhost:9000
S3_ACCESS_KEY=minioadmin
S3_SECRET_KEY=minioadmin
S3_BUCKET=delicious-images
JWT_SECRET=dev-secret-do-not-use-in-prod
EOF

# 启动基础设施 + API
docker compose up -d

# 跑数据库迁移
docker compose exec api alembic upgrade head
# 应该迁到 b3d2a8e91f04（V1.1 购物建议）

# 验证
curl http://localhost:8000/api/v1/health
# {"status":"ok","app":"Delicious API","version":"v1.0.0"}
```

MinIO 控制台：http://localhost:9001 (`minioadmin / minioadmin`)
API 文档（Swagger）：http://localhost:8000/docs

### 2. 启动 Flutter

```bash
cd app

# 首次拉项目要生成平台目录（如果 android/ ios/ 不存在）
flutter create . --platforms=ios,android --org com.delicious

flutter pub get
flutter run
```

#### 平台权限配置（首次必做）

**Android** (`android/app/src/main/AndroidManifest.xml`)：

```xml
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"/>
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION"/>
<uses-permission android:name="android.permission.CAMERA"/>
<uses-permission android:name="android.permission.INTERNET"/>

<queries>
  <intent>
    <action android:name="android.intent.action.VIEW"/>
  </intent>
</queries>
```

**iOS** (`ios/Runner/Info.plist`)：

```xml
<key>NSLocationWhenInUseUsageDescription</key>
<string>用于推荐附近超市，仅在你点开「看看去哪买」时使用</string>
<key>NSCameraUsageDescription</key>
<string>用于拍摄食物照片以进行 AI 识别</string>
<key>NSPhotoLibraryUsageDescription</key>
<string>选择已有的食物照片进行 AI 识别</string>
<key>LSApplicationQueriesSchemes</key>
<array>
  <string>hema</string>
  <string>dingdongmaicai</string>
  <string>pupumarket</string>
  <string>meituanwaimai</string>
  <string>openapp.jddj</string>
  <string>iosamap</string>
</array>
```

### 3. 端到端验证

注册账号后跑一遍：
1. 注册 → 自动进引导 → 末屏 CTA → 拍照
2. 选图 → 立即识别 → 改一项材料价格 → 保存
3. 详情页 → 「加入购物清单」→ 切「我的」Tab → 进购物清单
4. 购物清单顶部「看看去哪买」→ 允许定位 → 看 3 个 Tab
5. 详情页 → FAB「再做一次」→ 调整人数 → 创建副本
6. 「我的」→ 我的价格表，能看到刚才改过的价格

## 项目结构

```
delicious/
├── app/                              # Flutter 客户端
│   ├── lib/
│   │   ├── app.dart                 # GoRouter + StatefulShellRoute
│   │   ├── main.dart
│   │   ├── models/                  # FoodRecord / Recipe / ShoppingItem / ...
│   │   ├── providers/               # Riverpod state notifiers
│   │   ├── screens/                 # 12 个页面
│   │   ├── services/                # ApiClient / LocationService / Analytics
│   │   └── widgets/                 # FoodCard / RecipeSteps / ShareCard
│   └── pubspec.yaml
│
├── backend/                          # Python FastAPI
│   ├── app/
│   │   ├── main.py                  # lifespan + 7 个 router
│   │   ├── config.py                # Pydantic settings
│   │   ├── api/                     # auth / foods / ai / shopping / prices / stats / events
│   │   ├── models/                  # SQLAlchemy 9 张表
│   │   ├── schemas/                 # Pydantic 输入输出
│   │   ├── services/                # 业务编排（含购物建议 5 步流程）
│   │   ├── configs/                 # store_deeplinks 平台模板
│   │   └── utils/                   # text / storage / geohash
│   ├── alembic/versions/            # 2 个迁移：V1.0 schema + V1.1 购物建议
│   ├── docker-compose.yml
│   └── requirements.txt
│
└── docs/
    ├── PRD.md                       # 产品需求 v3（17 个章节）
    ├── ARCHITECTURE.md              # 架构设计 v2.1
    ├── API.md                       # API 文档 v2.1
    └── DEPLOYMENT.md                # 部署指南
```

## API 速查

完整文档：[docs/API.md](docs/API.md)

```
POST   /api/v1/auth/register             注册
POST   /api/v1/auth/login                登录
POST   /api/v1/ai/recognize              图片 → 食谱
POST   /api/v1/ai/feedback               识别反馈
GET    /api/v1/foods                     美食记录列表（?q / ?ingredient / ?from / ?to）
POST   /api/v1/foods                     保存（带复购检测）
POST   /api/v1/foods/:id/duplicate       再做一次（按人数缩放）
GET/POST/PATCH/DELETE /shopping/items*   购物清单
POST   /api/v1/shopping/items/from-food  从菜谱批量加入
POST   /api/v1/shopping/buy-suggestions  「看看去哪买」(V1.1)
POST   /api/v1/shopping/buy-suggestions/click  跳转埋点 (V1.1)
GET/POST/DELETE /user/ingredient-prices  个人价格表
GET    /api/v1/stats/cost                成本统计
POST   /api/v1/events                    埋点批量上报
```

## 开发指南

### 加一张表 / 改 schema

1. 在 `backend/app/models/` 新建或修改 model
2. 在 `backend/app/models/__init__.py` 注册
3. 生成迁移：
   ```bash
   docker compose exec api alembic revision --autogenerate -m "your_change"
   docker compose exec api alembic upgrade head
   ```
4. 检查生成的迁移脚本，必要时手动调整（JSONB / 索引等 alembic 不会自动识别）

### 加一个 API 端点

1. `schemas/<module>.py` 写 Pydantic 输入输出
2. `services/<module>_service.py` 写业务编排
3. `api/<module>.py` 暴露路由
4. `main.py` 注册 router（注意带 `/api/v1` 前缀）
5. 在 [docs/API.md](docs/API.md) 同步文档

### 加一个 Flutter 页面

1. `models/` 加数据模型（含 `fromJson`）
2. `providers/` 加 Riverpod state notifier
3. `screens/` 写页面
4. `app.dart` 注册 GoRoute

### 跑测试

V1.0 未引入测试框架。V1.2 计划用 pytest 覆盖：购物建议 5 步流程、个人价格覆盖、复购检测、购物清单合并算法。

## 路线图

详见 [docs/PRD.md §12 Roadmap](docs/PRD.md#12-roadmap)。

| 阶段 | 时间 | 关键里程碑 |
|---|---|---|
| V1.0 测试 | T0+2w | 内测 30 人；漏斗完成率 ≥ 60% |
| V1.0 公测 | T+4w | 应用商店上线；日活 1000 |
| V1.1 购物建议 | T+7w | 「看看去哪买」全量开放 |
| V1.2 留存增强 | T+11w | 周报推送 / 离线草稿 / token 持久化 |
| V1.3 体验深化 | T+15w | 视频步骤 / 智能体改菜谱 |
| V2.0 规划 | T+15w+ | 营养分析 / 家庭共享 / 美食地图 |

T0 = V1.0 进入测试日。

## 合规与隐私

- 遵循《个人信息保护法》《数据安全法》《网络安全法》
- 位置数据精度脱敏到 100m 后入库，缓存 key 用 geohash5（约 5km）
- 第三方密钥（OpenAI / 高德）仅后端持有，不下发客户端
- 用户可主动删除账号，48 小时内清除一切数据
- 完整数据分级与保留期限：[docs/PRD.md §15](docs/PRD.md#15-隐私与合规)

## 文档

- [产品需求 PRD.md](docs/PRD.md) — Persona / 功能 / Roadmap / 商业化 / 决策记录
- [架构设计 ARCHITECTURE.md](docs/ARCHITECTURE.md) — 数据模型 / 关键流程 / 4 层缓存
- [API 文档 API.md](docs/API.md) — 全部端点的 Request / Response
- [部署指南 DEPLOYMENT.md](docs/DEPLOYMENT.md) — 本地 + 生产 + CI/CD

## 贡献

这是一个个人项目，欢迎 issue 和 PR。提 PR 前请：

1. 改动如涉及 schema：跑通 `alembic upgrade head` 不报错
2. 改动如涉及核心流程：手动跑一遍端到端验证（README §3）
3. 提交信息按 conventional commits 风格：`feat:` / `fix:` / `docs:` / `refactor:`

## License

私人项目，暂未确定开源协议。
