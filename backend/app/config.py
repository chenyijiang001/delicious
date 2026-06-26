from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    app_name: str = "Delicious API"
    debug: bool = False

    database_url: str = "postgresql+asyncpg://delicious:password@localhost:5432/delicious"
    redis_url: str = "redis://localhost:6379/0"

    s3_endpoint: str = "http://localhost:9000"
    s3_access_key: str = "minioadmin"
    s3_secret_key: str = "minioadmin"
    s3_bucket: str = "delicious-images"

    openai_api_key: str = "sk-placeholder"
    openai_api_base: str = "https://api.openai.com/v1"
    openai_model: str = "gpt-4o"

    jwt_secret: str = "change-me-in-production"
    jwt_algorithm: str = "HS256"
    jwt_expire_minutes: int = 1440

    model_config = {"env_file": ".env"}


settings = Settings()
