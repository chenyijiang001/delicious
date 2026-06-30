"""v1.0 schema: jsonb 升级 + cooked_at/source + shopping/prices/feedback/events

Revision ID: a1f3c7b20d10
Revises: 2e0707ae125e
Create Date: 2026-06-30
"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql


revision: str = "a1f3c7b20d10"
down_revision: Union[str, None] = "2e0707ae125e"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # ---- food_records: JSON → JSONB + cooked_at + source + indexes ----
    op.execute("ALTER TABLE food_records ALTER COLUMN ingredients TYPE jsonb USING ingredients::jsonb")
    op.execute("ALTER TABLE food_records ALTER COLUMN steps TYPE jsonb USING steps::jsonb")
    op.execute("ALTER TABLE food_records ALTER COLUMN tips TYPE jsonb USING tips::jsonb")

    op.add_column(
        "food_records",
        sa.Column("cooked_at", sa.Date(), nullable=True),
    )
    # 回填 cooked_at = created_at::date
    op.execute("UPDATE food_records SET cooked_at = created_at::date WHERE cooked_at IS NULL")
    op.alter_column(
        "food_records",
        "cooked_at",
        nullable=False,
        server_default=sa.text("CURRENT_DATE"),
    )
    op.create_index("ix_food_records_cooked_at", "food_records", ["cooked_at"])
    op.create_index("ix_food_records_user_cooked", "food_records", ["user_id", "cooked_at"])
    op.create_index("ix_food_records_user_dish", "food_records", ["user_id", "dish_name"])
    op.execute(
        "CREATE INDEX ix_food_records_ingredients_gin "
        "ON food_records USING gin (ingredients jsonb_path_ops)"
    )

    op.add_column(
        "food_records",
        sa.Column(
            "source",
            sa.String(length=20),
            nullable=False,
            server_default="recognize",
        ),
    )

    # ---- shopping_list_items ----
    op.create_table(
        "shopping_list_items",
        sa.Column("id", sa.Uuid(), primary_key=True),
        sa.Column("user_id", sa.Uuid(), nullable=False),
        sa.Column("name", sa.String(length=120), nullable=False),
        sa.Column("name_normalized", sa.String(length=120), nullable=False),
        sa.Column("amount", sa.Numeric(10, 2), nullable=False, server_default="0"),
        sa.Column("unit", sa.String(length=20), nullable=False, server_default=""),
        sa.Column("estimated_price", sa.Numeric(8, 2), nullable=False, server_default="0"),
        sa.Column("checked", sa.Boolean(), nullable=False, server_default=sa.text("false")),
        sa.Column("source", sa.String(length=10), nullable=False, server_default="auto"),
        sa.Column(
            "from_food_ids",
            postgresql.ARRAY(sa.Uuid()),
            nullable=False,
            server_default="{}",
        ),
        sa.Column("created_at", sa.DateTime(), nullable=False, server_default=sa.text("now()")),
        sa.Column("updated_at", sa.DateTime(), nullable=False, server_default=sa.text("now()")),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"], ondelete="CASCADE"),
        sa.UniqueConstraint("user_id", "name_normalized", "unit", name="uq_shopping_user_name_unit"),
    )
    op.create_index("ix_shopping_list_items_user_id", "shopping_list_items", ["user_id"])

    # ---- user_ingredient_prices ----
    op.create_table(
        "user_ingredient_prices",
        sa.Column("id", sa.Uuid(), primary_key=True),
        sa.Column("user_id", sa.Uuid(), nullable=False),
        sa.Column("name", sa.String(length=120), nullable=False),
        sa.Column("name_normalized", sa.String(length=120), nullable=False),
        sa.Column("unit", sa.String(length=20), nullable=False, server_default=""),
        sa.Column("unit_price", sa.Numeric(8, 2), nullable=False),
        sa.Column("last_used_at", sa.DateTime(), nullable=False, server_default=sa.text("now()")),
        sa.Column("source", sa.String(length=20), nullable=False, server_default="user_edit"),
        sa.Column("created_at", sa.DateTime(), nullable=False, server_default=sa.text("now()")),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"], ondelete="CASCADE"),
        sa.UniqueConstraint("user_id", "name_normalized", "unit", name="uq_price_user_name_unit"),
    )
    op.create_index("ix_user_ingredient_prices_user_id", "user_ingredient_prices", ["user_id"])

    # ---- ai_feedback ----
    op.create_table(
        "ai_feedback",
        sa.Column("id", sa.Uuid(), primary_key=True),
        sa.Column("user_id", sa.Uuid(), nullable=False),
        sa.Column("food_id", sa.Uuid(), nullable=True),
        sa.Column("image_url", sa.Text(), nullable=True),
        sa.Column(
            "reasons",
            postgresql.ARRAY(sa.Text()),
            nullable=False,
            server_default="{}",
        ),
        sa.Column("comment", sa.Text(), nullable=True),
        sa.Column("created_at", sa.DateTime(), nullable=False, server_default=sa.text("now()")),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"], ondelete="CASCADE"),
        sa.ForeignKeyConstraint(["food_id"], ["food_records.id"], ondelete="SET NULL"),
    )
    op.create_index("ix_ai_feedback_user_id", "ai_feedback", ["user_id"])

    # ---- events ----
    op.create_table(
        "events",
        sa.Column("id", sa.BigInteger(), primary_key=True, autoincrement=True),
        sa.Column("user_id", sa.Uuid(), nullable=True),
        sa.Column("name", sa.String(length=64), nullable=False),
        sa.Column("ts", sa.DateTime(), nullable=False, server_default=sa.text("now()")),
        sa.Column("props", postgresql.JSONB(), nullable=False, server_default="{}"),
    )
    op.create_index("ix_events_name_ts", "events", ["name", "ts"])
    op.create_index("ix_events_user_ts", "events", ["user_id", "ts"])


def downgrade() -> None:
    op.drop_index("ix_events_user_ts", table_name="events")
    op.drop_index("ix_events_name_ts", table_name="events")
    op.drop_table("events")

    op.drop_index("ix_ai_feedback_user_id", table_name="ai_feedback")
    op.drop_table("ai_feedback")

    op.drop_index("ix_user_ingredient_prices_user_id", table_name="user_ingredient_prices")
    op.drop_table("user_ingredient_prices")

    op.drop_index("ix_shopping_list_items_user_id", table_name="shopping_list_items")
    op.drop_table("shopping_list_items")

    op.drop_column("food_records", "source")
    op.execute("DROP INDEX IF EXISTS ix_food_records_ingredients_gin")
    op.drop_index("ix_food_records_user_dish", table_name="food_records")
    op.drop_index("ix_food_records_user_cooked", table_name="food_records")
    op.drop_index("ix_food_records_cooked_at", table_name="food_records")
    op.drop_column("food_records", "cooked_at")

    op.execute("ALTER TABLE food_records ALTER COLUMN tips TYPE json USING tips::json")
    op.execute("ALTER TABLE food_records ALTER COLUMN steps TYPE json USING steps::json")
    op.execute("ALTER TABLE food_records ALTER COLUMN ingredients TYPE json USING ingredients::json")
