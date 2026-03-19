from fastapi import APIRouter, Depends, HTTPException, UploadFile, File
from sqlalchemy.orm import Session
from typing import List
import aiofiles
import os
from pathlib import Path

from app.db.database import get_db
from app.models.models import User, UserRole
from app.schemas.schemas import UserCreate, UserUpdate, UserOut, UserPasswordChange
from app.core.security import get_password_hash, verify_password
from app.core.deps import get_current_user, require_admin_or_manager, require_admin
from app.core.config import settings

router = APIRouter(prefix="/users", tags=["Users"])


@router.get("/", response_model=List[UserOut])
def get_users(
    skip: int = 0, limit: int = 100,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_admin_or_manager())
):
    return db.query(User).offset(skip).limit(limit).all()


@router.post("/", response_model=UserOut)
def create_user(
    user_data: UserCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_admin())
):
    # Check duplicates
    if db.query(User).filter(User.username == user_data.username).first():
        raise HTTPException(status_code=400, detail="Username already exists")
    
    if user_data.email and db.query(User).filter(User.email == user_data.email).first():
        raise HTTPException(status_code=400, detail="Email already exists")
    
    user = User(
        username=user_data.username,
        full_name=user_data.full_name,
        email=user_data.email,
        hashed_password=get_password_hash(user_data.password),
        role=user_data.role,
        phone=user_data.phone,
        notes=user_data.notes,
        permissions=user_data.permissions or {},
        pin_code=user_data.pin_code,
    )
    db.add(user)
    db.commit()
    db.refresh(user)
    return user


@router.get("/{user_id}", response_model=UserOut)
def get_user(
    user_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    # Users can view their own profile; admin/manager can view all
    if current_user.id != user_id and current_user.role not in [UserRole.ADMIN, UserRole.MANAGER]:
        raise HTTPException(status_code=403, detail="Access denied")
    
    user = db.query(User).filter(User.id == user_id).first()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    return user


@router.patch("/{user_id}", response_model=UserOut)
def update_user(
    user_id: int,
    user_data: UserUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_admin_or_manager())
):
    user = db.query(User).filter(User.id == user_id).first()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    
    for field, value in user_data.dict(exclude_unset=True).items():
        setattr(user, field, value)
    
    db.commit()
    db.refresh(user)
    return user


@router.delete("/{user_id}")
def delete_user(
    user_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_admin())
):
    user = db.query(User).filter(User.id == user_id).first()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    if user.id == current_user.id:
        raise HTTPException(status_code=400, detail="Cannot delete your own account")
    
    user.is_active = False  # Soft delete
    db.commit()
    return {"message": "User deactivated"}


@router.post("/{user_id}/change-password")
def change_password(
    user_id: int,
    data: UserPasswordChange,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    if current_user.id != user_id and current_user.role != UserRole.ADMIN:
        raise HTTPException(status_code=403, detail="Access denied")
    
    user = db.query(User).filter(User.id == user_id).first()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    
    if current_user.role != UserRole.ADMIN:
        if not verify_password(data.current_password, user.hashed_password):
            raise HTTPException(status_code=400, detail="Incorrect current password")
    
    user.hashed_password = get_password_hash(data.new_password)
    db.commit()
    return {"message": "Password changed successfully"}


@router.post("/{user_id}/avatar")
async def upload_avatar(
    user_id: int,
    file: UploadFile = File(...),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    if current_user.id != user_id and current_user.role != UserRole.ADMIN:
        raise HTTPException(status_code=403, detail="Access denied")
    
    user = db.query(User).filter(User.id == user_id).first()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    
    # Validate file type
    allowed = ["image/jpeg", "image/png", "image/webp"]
    if file.content_type not in allowed:
        raise HTTPException(status_code=400, detail="Invalid file type")
    
    upload_dir = Path(settings.UPLOAD_DIR) / "avatars"
    upload_dir.mkdir(parents=True, exist_ok=True)
    
    ext = file.filename.split(".")[-1]
    filename = f"user_{user_id}.{ext}"
    filepath = upload_dir / filename
    
    async with aiofiles.open(filepath, 'wb') as f:
        content = await file.read()
        await f.write(content)
    
    user.avatar_url = f"/uploads/avatars/{filename}"
    db.commit()
    return {"avatar_url": user.avatar_url}
