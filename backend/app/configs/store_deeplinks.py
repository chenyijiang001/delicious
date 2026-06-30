"""线上配送 / 外卖买菜平台 deeplink 模板。
说明：
- {query} 会被替换为食材名（多个食材取代表性 1~2 项）
- cities = ["all"] 表示全国可用；否则用城市 adcode 白名单
- eta_minutes_default 仅作展示，真实 ETA 需用户跳出后才知道
"""

PLATFORMS = [
    {
        "platform": "hema",
        "name": "盒马鲜生",
        "channel": "online",
        "scheme": "hema://search?keyword={query}",
        "web_fallback": "https://www.hemaos.com/search?q={query}",
        "cities": ["all"],
        "eta_minutes_default": 30,
    },
    {
        "platform": "dingdong",
        "name": "叮咚买菜",
        "channel": "online",
        "scheme": "dingdongmaicai://search?keyword={query}",
        "web_fallback": "https://maicai.dingdong.com/?q={query}",
        # 叮咚仅覆盖一线 + 部分新一线
        "cities": ["010", "021", "0571", "0755", "0512", "0512", "025"],
        "eta_minutes_default": 35,
    },
    {
        "platform": "pupu",
        "name": "朴朴超市",
        "channel": "online",
        "scheme": "pupumarket://search?q={query}",
        "web_fallback": "https://www.pupuapi.com/?q={query}",
        # 朴朴主要在福建 + 几个新一线
        "cities": ["0591", "0592", "020", "0755", "0571", "0512"],
        "eta_minutes_default": 30,
    },
    {
        "platform": "meituan_maicai",
        "name": "美团买菜",
        "channel": "delivery",
        "scheme": "meituanwaimai://search?q={query}",
        "web_fallback": "https://i.meituan.com/maicai?q={query}",
        "cities": ["all"],
        "eta_minutes_default": 40,
    },
    {
        "platform": "jd_daojia",
        "name": "京东到家",
        "channel": "delivery",
        "scheme": "openapp.jddj://search?keyword={query}",
        "web_fallback": "https://daojia.jd.com/search?keyword={query}",
        "cities": ["all"],
        "eta_minutes_default": 60,
    },
]


def available_in_city(city_code: str | None) -> list[dict]:
    """筛选给定城市可用的平台。无 city_code 时仅返回全国可用平台。"""
    out = []
    for p in PLATFORMS:
        cities = p["cities"]
        if "all" in cities:
            out.append(p)
            continue
        if city_code and city_code in cities:
            out.append(p)
    return out
