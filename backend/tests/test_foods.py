import pytest
from app.services.food_service import list_foods, create_food, get_food, update_food, delete_food
from app.schemas.food import FoodRecordCreate, FoodRecordUpdate


@pytest.mark.asyncio
async def test_create_and_get_food(db):
    data = FoodRecordCreate(
        dish_name="番茄炒蛋",
        category="家常菜",
        ingredients=[{"name": "番茄", "amount": 2, "unit": "个", "estimated_price": 3.0}],
        steps=[{"step_num": 1, "description": "炒鸡蛋", "duration_minutes": 3}],
        total_cost=8.5,
        serving_size=2,
        difficulty="简单",
        tips=["先炒鸡蛋"],
    )
    record = await create_food(db, "00000000-0000-0000-0000-000000000001", data)
    assert record.dish_name == "番茄炒蛋"
    assert record.ingredients[0]["name"] == "番茄"

    fetched = await get_food(db, str(record.id), "00000000-0000-0000-0000-000000000001")
    assert fetched is not None
    assert fetched.dish_name == "番茄炒蛋"


@pytest.mark.asyncio
async def test_list_foods_with_pagination(db):
    data = FoodRecordCreate(dish_name="测试菜", category="家常菜", ingredients=[], steps=[])
    for _ in range(3):
        await create_food(db, "00000000-0000-0000-0000-000000000001", data)

    items, total = await list_foods(db, "00000000-0000-0000-0000-000000000001", page=1, size=2)
    assert len(items) == 2
    assert total == 3


@pytest.mark.asyncio
async def test_update_food(db):
    data = FoodRecordCreate(dish_name="原菜名", category="家常菜", ingredients=[], steps=[])
    record = await create_food(db, "00000000-0000-0000-0000-000000000001", data)

    update = FoodRecordUpdate(dish_name="新菜名")
    updated = await update_food(db, str(record.id), "00000000-0000-0000-0000-000000000001", update)
    assert updated is not None
    assert updated.dish_name == "新菜名"


@pytest.mark.asyncio
async def test_delete_food(db):
    data = FoodRecordCreate(dish_name="待删除", category="家常菜", ingredients=[], steps=[])
    record = await create_food(db, "00000000-0000-0000-0000-000000000001", data)

    result = await delete_food(db, str(record.id), "00000000-0000-0000-0000-000000000001")
    assert result is True

    fetched = await get_food(db, str(record.id), "00000000-0000-0000-0000-000000000001")
    assert fetched is None
