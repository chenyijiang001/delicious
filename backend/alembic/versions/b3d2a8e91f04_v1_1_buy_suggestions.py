"""v1.1 购物建议：ingredient_aliases / pois_cache / purchase_clicks

Revision ID: b3d2a8e91f04
Revises: a1f3c7b20d10
Create Date: 2026-06-30
"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql


revision: str = "b3d2a8e91f04"
down_revision: Union[str, None] = "a1f3c7b20d10"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # ---- ingredient_aliases ----
    op.create_table(
        "ingredient_aliases",
        sa.Column("id", sa.Uuid(), primary_key=True),
        sa.Column("alias", sa.String(length=120), nullable=False),
        sa.Column("alias_normalized", sa.String(length=120), nullable=False),
        sa.Column("canonical", sa.String(length=120), nullable=False),
        sa.Column(
            "canonical_category",
            sa.String(length=60),
            nullable=False,
            server_default="other",
        ),
        sa.Column(
            "store_type_coverage",
            postgresql.JSONB(),
            nullable=False,
            server_default="{}",
        ),
        sa.Column(
            "confidence", sa.Numeric(3, 2), nullable=False, server_default="0.0"
        ),
        sa.Column(
            "created_at", sa.DateTime(), nullable=False, server_default=sa.text("now()")
        ),
        sa.Column(
            "updated_at", sa.DateTime(), nullable=False, server_default=sa.text("now()")
        ),
        sa.UniqueConstraint("alias_normalized", name="uq_ingredient_aliases_norm"),
    )

    # ---- pois_cache ----
    op.create_table(
        "pois_cache",
        sa.Column("id", sa.String(length=64), primary_key=True),
        sa.Column("name", sa.String(length=200), nullable=False),
        sa.Column("category", sa.String(length=20), nullable=False),
        sa.Column("lat", sa.Numeric(9, 6), nullable=False),
        sa.Column("lng", sa.Numeric(9, 6), nullable=False),
        sa.Column("city_code", sa.String(length=10), nullable=True),
        sa.Column("address", sa.String(length=255), nullable=True),
        sa.Column("business_hours", postgresql.JSONB(), nullable=True),
        sa.Column("geohash5", sa.String(length=5), nullable=False),
        sa.Column(
            "cached_at", sa.DateTime(), nullable=False, server_default=sa.text("now()")
        ),
    )
    op.create_index("ix_pois_cache_geohash5", "pois_cache", ["geohash5"])
    op.create_index(
        "ix_pois_cache_geohash5_category", "pois_cache", ["geohash5", "category"]
    )

    # ---- purchase_clicks ----
    op.create_table(
        "purchase_clicks",
        sa.Column("id", sa.BigInteger(), primary_key=True, autoincrement=True),
        sa.Column("user_id", sa.Uuid(), nullable=False),
        sa.Column("channel", sa.String(length=20), nullable=False),
        sa.Column("target", sa.String(length=120), nullable=False),
        sa.Column(
            "missing_count", sa.Integer(), nullable=False, server_default="0"
        ),
        sa.Column("ts", sa.DateTime(), nullable=False, server_default=sa.text("now()")),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"], ondelete="CASCADE"),
    )
    op.create_index(
        "ix_purchase_clicks_user_ts", "purchase_clicks", ["user_id", "ts"]
    )
    op.create_index(
        "ix_purchase_clicks_channel_ts", "purchase_clicks", ["channel", "ts"]
    )


def downgrade() -> None:
    op.drop_index("ix_purchase_clicks_channel_ts", table_name="purchase_clicks")
    op.drop_index("ix_purchase_clicks_user_ts", table_name="purchase_clicks")
    op.drop_table("purchase_clicks")

    op.drop_index("ix_pois_cache_geohash5_category", table_name="pois_cache")
    op.drop_index("ix_pois_cache_geohash5", table_name="pois_cache")
    op.drop_table("pois_cache")

    op.drop_table("ingredient_aliases")
