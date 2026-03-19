from fastapi import APIRouter, Depends, HTTPException, UploadFile, File
from sqlalchemy.orm import Session, joinedload
from typing import List, Optional
import aiofiles
from pathlib import Path

from app.db.database import get_db
from app.models.models import (
    Category, MenuItem, ModifierGroup, ModifierOption,
    User, UserRole
)
from app.schemas.schemas import (
    CategoryCreate, CategoryUpdate, CategoryOut,
    MenuItemCreate, MenuItemUpdate, MenuItemOut,
    ModifierGroupCreate, ModifierGroupOut
)
from app.core.deps import get_current_user, require_admin_or_manager
from app.core.config import settings

router = APIRouter(prefix="/menu", tags=["Menu"])


# ─── CATEGORIES ───

@router.get("/categories", response_model=List[CategoryOut])
def get_categories(
    include_inactive: bool = False,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    query = db.query(Category)
    if not include_inactive:
        query = query.filter(Category.is_active == True)
    return query.order_by(Category.sort_order, Category.name).all()


@router.post("/categories", response_model=CategoryOut)
def create_category(
    data: CategoryCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_admin_or_manager())
):
    cat = Category(**data.dict())
    db.add(cat)
    db.commit()
    db.refresh(cat)
    return cat


@router.patch("/categories/{category_id}", response_model=CategoryOut)
def update_category(
    category_id: int,
    data: CategoryUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_admin_or_manager())
):
    cat = db.query(Category).filter(Category.id == category_id).first()
    if not cat:
        raise HTTPException(status_code=404, detail="Category not found")
    
    for field, value in data.dict(exclude_unset=True).items():
        setattr(cat, field, value)
    
    db.commit()
    db.refresh(cat)
    return cat


@router.post("/categories/{category_id}/image")
async def upload_category_image(
    category_id: int,
    file: UploadFile = File(...),
    db: Session = Depends(get_db),
    current_user: User = Depends(require_admin_or_manager())
):
    cat = db.query(Category).filter(Category.id == category_id).first()
    if not cat:
        raise HTTPException(status_code=404, detail="Category not found")
    
    upload_dir = Path(settings.UPLOAD_DIR) / "categories"
    upload_dir.mkdir(parents=True, exist_ok=True)
    
    ext = file.filename.split(".")[-1]
    filename = f"category_{category_id}.{ext}"
    filepath = upload_dir / filename
    
    async with aiofiles.open(filepath, 'wb') as f:
        await f.write(await file.read())
    
    cat.image_url = f"/uploads/categories/{filename}"
    db.commit()
    return {"image_url": cat.image_url}


@router.delete("/categories/{category_id}")
def delete_category(
    category_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_admin_or_manager())
):
    cat = db.query(Category).filter(Category.id == category_id).first()
    if not cat:
        raise HTTPException(status_code=404, detail="Category not found")
    
    cat.is_active = False
    db.commit()
    return {"message": "Category deactivated"}


# ─── MENU ITEMS ───

@router.get("/items", response_model=List[MenuItemOut])
def get_menu_items(
    category_id: Optional[int] = None,
    include_inactive: bool = False,
    featured_only: bool = False,
    search: Optional[str] = None,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    query = db.query(MenuItem).options(
        joinedload(MenuItem.category),
        joinedload(MenuItem.modifier_groups).joinedload(ModifierGroup.options)
    )
    
    if not include_inactive:
        query = query.filter(MenuItem.is_active == True)
    if category_id:
        query = query.filter(MenuItem.category_id == category_id)
    if featured_only:
        query = query.filter(MenuItem.is_featured == True)
    if search:
        query = query.filter(MenuItem.name.ilike(f"%{search}%"))
    
    return query.order_by(MenuItem.sort_order, MenuItem.name).all()


@router.get("/items/{item_id}", response_model=MenuItemOut)
def get_menu_item(
    item_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    item = db.query(MenuItem).options(
        joinedload(MenuItem.category),
        joinedload(MenuItem.modifier_groups).joinedload(ModifierGroup.options)
    ).filter(MenuItem.id == item_id).first()
    
    if not item:
        raise HTTPException(status_code=404, detail="Menu item not found")
    return item


@router.post("/items", response_model=MenuItemOut)
def create_menu_item(
    data: MenuItemCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_admin_or_manager())
):
    item_data = data.dict(exclude={"modifier_groups"})
    item = MenuItem(**item_data)
    db.add(item)
    db.flush()
    
    # Create modifier groups
    for group_data in data.modifier_groups:
        options = group_data.pop("options", []) if isinstance(group_data, dict) else group_data.options
        group = ModifierGroup(
            menu_item_id=item.id,
            **({k: v for k, v in group_data.items()} if isinstance(group_data, dict) else group_data.dict(exclude={"options"}))
        )
        db.add(group)
        db.flush()
        
        for opt_data in options:
            opt = ModifierOption(
                group_id=group.id,
                **(opt_data if isinstance(opt_data, dict) else opt_data.dict())
            )
            db.add(opt)
    
    db.commit()
    db.refresh(item)
    return item


@router.patch("/items/{item_id}", response_model=MenuItemOut)
def update_menu_item(
    item_id: int,
    data: MenuItemUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_admin_or_manager())
):
    item = db.query(MenuItem).filter(MenuItem.id == item_id).first()
    if not item:
        raise HTTPException(status_code=404, detail="Menu item not found")
    
    for field, value in data.dict(exclude_unset=True).items():
        setattr(item, field, value)
    
    db.commit()
    db.refresh(item)
    return item


@router.post("/items/{item_id}/image")
async def upload_item_image(
    item_id: int,
    file: UploadFile = File(...),
    db: Session = Depends(get_db),
    current_user: User = Depends(require_admin_or_manager())
):
    item = db.query(MenuItem).filter(MenuItem.id == item_id).first()
    if not item:
        raise HTTPException(status_code=404, detail="Item not found")
    
    allowed = ["image/jpeg", "image/png", "image/webp"]
    if file.content_type not in allowed:
        raise HTTPException(status_code=400, detail="Invalid file type. Use JPEG, PNG or WebP")
    
    upload_dir = Path(settings.UPLOAD_DIR) / "menu"
    upload_dir.mkdir(parents=True, exist_ok=True)
    
    ext = file.filename.split(".")[-1].lower()
    filename = f"item_{item_id}.{ext}"
    filepath = upload_dir / filename
    
    async with aiofiles.open(filepath, 'wb') as f:
        await f.write(await file.read())
    
    item.image_url = f"/uploads/menu/{filename}"
    db.commit()
    return {"image_url": item.image_url}


@router.patch("/items/{item_id}/availability")
def toggle_availability(
    item_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Kitchen staff can toggle item availability (sold out)."""
    item = db.query(MenuItem).filter(MenuItem.id == item_id).first()
    if not item:
        raise HTTPException(status_code=404, detail="Item not found")
    
    item.is_available = not item.is_available
    db.commit()
    return {"is_available": item.is_available, "item_id": item_id}


@router.delete("/items/{item_id}")
def delete_menu_item(
    item_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_admin_or_manager())
):
    item = db.query(MenuItem).filter(MenuItem.id == item_id).first()
    if not item:
        raise HTTPException(status_code=404, detail="Item not found")
    
    item.is_active = False
    db.commit()
    return {"message": "Item deactivated"}


# ─── MODIFIER GROUPS ───

@router.post("/items/{item_id}/modifier-groups", response_model=ModifierGroupOut)
def create_modifier_group(
    item_id: int,
    data: ModifierGroupCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_admin_or_manager())
):
    item = db.query(MenuItem).filter(MenuItem.id == item_id).first()
    if not item:
        raise HTTPException(status_code=404, detail="Item not found")
    
    options = data.options
    group = ModifierGroup(
        menu_item_id=item_id,
        **data.dict(exclude={"options"})
    )
    db.add(group)
    db.flush()
    
    for opt in options:
        db.add(ModifierOption(group_id=group.id, **opt.dict()))
    
    db.commit()
    db.refresh(group)
    return group


@router.delete("/modifier-groups/{group_id}")
def delete_modifier_group(
    group_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_admin_or_manager())
):
    group = db.query(ModifierGroup).filter(ModifierGroup.id == group_id).first()
    if not group:
        raise HTTPException(status_code=404, detail="Group not found")
    db.delete(group)
    db.commit()
    return {"message": "Modifier group deleted"}
