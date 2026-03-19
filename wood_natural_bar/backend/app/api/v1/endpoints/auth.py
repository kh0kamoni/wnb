from fastapi import APIRouter, Depends, HTTPException, status, UploadFile, File
from sqlalchemy.orm import Session
from datetime import timedelta
from app.db.database import get_db
from app.models.models import User, UserRole
from app.schemas.schemas import Token, LoginRequest, PinLoginRequest, UserOut, TokenRefresh
from app.core.security import (
    verify_password, create_access_token, create_refresh_token,
    decode_token, get_password_hash
)
from app.core.deps import get_current_user
from app.core.config import settings

router = APIRouter(prefix="/auth", tags=["Authentication"])


@router.post("/login", response_model=Token)
def login(request: LoginRequest, db: Session = Depends(get_db)):
    user = db.query(User).filter(
        User.username == request.username,
        User.is_active == True
    ).first()
    
    if not user or not verify_password(request.password, user.hashed_password):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Incorrect username or password"
        )
    
    access_token = create_access_token(user.id, user.role.value)
    refresh_token = create_refresh_token(user.id)
    
    return Token(
        access_token=access_token,
        refresh_token=refresh_token,
        user=UserOut.from_orm(user)
    )


@router.post("/pin-login", response_model=Token)
def pin_login(request: PinLoginRequest, db: Session = Depends(get_db)):
    """Quick PIN login for POS terminals."""
    user = db.query(User).filter(
        User.pin_code == request.pin_code,
        User.is_active == True
    ).first()
    
    if not user:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid PIN"
        )
    
    access_token = create_access_token(user.id, user.role.value)
    refresh_token = create_refresh_token(user.id)
    
    return Token(
        access_token=access_token,
        refresh_token=refresh_token,
        user=UserOut.from_orm(user)
    )


@router.post("/refresh", response_model=Token)
def refresh_token(request: TokenRefresh, db: Session = Depends(get_db)):
    payload = decode_token(request.refresh_token)
    if payload.get("type") != "refresh":
        raise HTTPException(status_code=401, detail="Invalid refresh token")
    
    user = db.query(User).filter(
        User.id == int(payload["sub"]),
        User.is_active == True
    ).first()
    
    if not user:
        raise HTTPException(status_code=401, detail="User not found")
    
    access_token = create_access_token(user.id, user.role.value)
    new_refresh_token = create_refresh_token(user.id)
    
    return Token(
        access_token=access_token,
        refresh_token=new_refresh_token,
        user=UserOut.from_orm(user)
    )


@router.get("/me", response_model=UserOut)
def get_me(current_user: User = Depends(get_current_user)):
    return current_user


@router.post("/logout")
def logout(current_user: User = Depends(get_current_user)):
    # JWT is stateless; client just deletes the token
    return {"message": "Logged out successfully"}
