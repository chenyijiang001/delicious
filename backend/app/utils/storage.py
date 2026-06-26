import uuid
from io import BytesIO

import boto3
from PIL import Image

from app.config import settings


def _s3_client():
    return boto3.client(
        "s3",
        endpoint_url=settings.s3_endpoint,
        aws_access_key_id=settings.s3_access_key,
        aws_secret_access_key=settings.s3_secret_key,
    )


def ensure_bucket():
    s3 = _s3_client()
    try:
        s3.head_bucket(Bucket=settings.s3_bucket)
    except Exception:
        s3.create_bucket(Bucket=settings.s3_bucket)


def upload_image(image_bytes: bytes, filename: str = None) -> str:
    ext = "jpg"
    key = f"foods/{uuid.uuid4().hex}.{ext}"
    s3 = _s3_client()
    s3.upload_fileobj(
        BytesIO(image_bytes),
        settings.s3_bucket,
        key,
        ExtraArgs={"ContentType": "image/jpeg"},
    )
    return f"{settings.s3_endpoint}/{settings.s3_bucket}/{key}"


def make_thumbnail(image_bytes: bytes, max_width: int = 400) -> bytes:
    img = Image.open(BytesIO(image_bytes))
    if img.mode in ("RGBA", "P"):
        img = img.convert("RGB")
    ratio = max_width / img.width
    if ratio < 1:
        new_height = int(img.height * ratio)
        img = img.resize((max_width, new_height), Image.LANCZOS)
    buf = BytesIO()
    img.save(buf, format="JPEG", quality=80)
    return buf.getvalue()
