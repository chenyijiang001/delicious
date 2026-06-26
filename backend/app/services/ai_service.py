import hashlib
import json

from openai import AsyncOpenAI

from app.config import settings

SYSTEM_PROMPT = """你是一个专业的美食分析师。根据图片识别食物，输出严格 JSON（不要 markdown 代码块包裹）：

{
  "dish_name": "菜品名称",
  "category": "家常菜|烘焙|饮品|汤品|小吃|面食|其他",
  "ingredients": [
    {"name": "材料名", "amount": 数值, "unit": "克|毫升|个|勺", "estimated_price": 数值}
  ],
  "steps": [
    {"step_num": 1, "description": "步骤描述", "duration_minutes": 数值}
  ],
  "total_cost": 估算总成本(人民币元),
  "serving_size": 几人份,
  "difficulty": "简单|中等|困难",
  "tips": ["烹饪小贴士"]
}

注意：
- total_cost 是所有材料 estimated_price 的合理加总
- steps 按实际操作顺序排列
- 如果是成品菜无法看到全部材料，请合理推测"""


def image_hash(image_bytes: bytes) -> str:
    return hashlib.sha256(image_bytes).hexdigest()


class AIService:
    def __init__(self, redis_client=None):
        self.client = AsyncOpenAI(
            api_key=settings.openai_api_key,
            base_url=settings.openai_api_base,
        )
        self.redis = redis_client

    async def recognize_food(self, image_bytes: bytes) -> dict:
        cache_key = f"ai:recipe:{image_hash(image_bytes)}"

        # Check Redis cache
        if self.redis:
            cached = await self.redis.get(cache_key)
            if cached:
                return json.loads(cached)

        import base64

        b64_image = base64.b64encode(image_bytes).decode("utf-8")

        response = await self.client.chat.completions.create(
            model=settings.openai_model,
            messages=[
                {"role": "system", "content": SYSTEM_PROMPT},
                {
                    "role": "user",
                    "content": [
                        {"type": "text", "text": "请识别这张食物图片，并生成食谱。"},
                        {
                            "type": "image_url",
                            "image_url": {"url": f"data:image/jpeg;base64,{b64_image}"},
                        },
                    ],
                },
            ],
            response_format={"type": "json_object"},
            max_tokens=2000,
        )

        content = response.choices[0].message.content
        result = json.loads(content)

        # Cache for 24h
        if self.redis:
            await self.redis.setex(cache_key, 86400, json.dumps(result, ensure_ascii=False))

        return result


ai_service = AIService()
