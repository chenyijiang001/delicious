from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.schemas.user import UserRegister, UserLogin, TokenResponse
from app.services import auth_service as svc

router = APIRouter(prefix="/auth", tags=["auth"])


@router.post("/register", response_model=TokenResponse, status_code=status.HTTP_201_CREATED)
async def register(data: UserRegister, db: AsyncSession = Depends(get_db)):
    existing = await svc.get_user_by_email(db, data.email)
    if existing:
        raise HTTPException(status_code=409, detail="Email already registered")
    user = await svc.create_user(db, data.email, data.nickname, data.password)
    token = svc.create_access_token({"sub": str(user.id)})
    return TokenResponse(
        access_token=token,
        user={"id": str(user.id), "email": user.email, "nickname": user.nickname},
    )


@router.post("/login", response_model=TokenResponse)
async def login(data: UserLogin, db: AsyncSession = Depends(get_db)):
    user = await svc.get_user_by_email(db, data.email)
    if not user or not svc.verify_password(data.password, user.hashed_password):
        raise HTTPException(status_code=401, detail="Invalid email or password")
    token = svc.create_access_token({"sub": str(user.id)})
    return TokenResponse(
        access_token=token,
        user={
            "id": str(user.id),
            "email": user.email,
            "nickname": user.nickname,
            "avatar_url": user.avatar_url,
        },
    )
