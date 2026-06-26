from app.services.ai_service import image_hash, SYSTEM_PROMPT


class TestAIService:
    def test_image_hash_deterministic(self):
        data = b"test image bytes"
        assert image_hash(data) == image_hash(data)

    def test_image_hash_different(self):
        assert image_hash(b"a") != image_hash(b"b")

    def test_system_prompt_contains_required_fields(self):
        assert "dish_name" in SYSTEM_PROMPT
        assert "ingredients" in SYSTEM_PROMPT
        assert "steps" in SYSTEM_PROMPT
        assert "total_cost" in SYSTEM_PROMPT
        assert "json" in SYSTEM_PROMPT.lower()
