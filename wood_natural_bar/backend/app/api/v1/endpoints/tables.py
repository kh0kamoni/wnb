from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session, joinedload
from typing import List, Optional
import qrcode
from pathlib import Path
import io

from app.db.database import get_db
from app.models.models import Table, Section, Order, OrderStatus, User
from app.schemas.schemas import (
    TableCreate, TableUpdate, TableOut, SectionCreate, SectionOut, FloorPlanUpdate
)
from app.core.deps import get_current_user, require_admin_or_manager
from app.core.config import settings

router = APIRouter(prefix="/tables", tags=["Tables"])


# ─── SECTIONS ───

@router.get("/sections", response_model=List[SectionOut])
def get_sections(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    return db.query(Section).filter(Section.is_active == True).order_by(Section.sort_order).all()


@router.post("/sections", response_model=SectionOut)
def create_section(
    data: SectionCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_admin_or_manager())
):
    section = Section(**data.dict())
    db.add(section)
    db.commit()
    db.refresh(section)
    return section


@router.patch("/sections/{section_id}", response_model=SectionOut)
def update_section(
    section_id: int,
    data: SectionCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_admin_or_manager())
):
    section = db.query(Section).filter(Section.id == section_id).first()
    if not section:
        raise HTTPException(status_code=404, detail="Section not found")
    
    for field, value in data.dict(exclude_unset=True).items():
        setattr(section, field, value)
    db.commit()
    db.refresh(section)
    return section


@router.delete("/sections/{section_id}")
def delete_section(
    section_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_admin_or_manager())
):
    section = db.query(Section).filter(Section.id == section_id).first()
    if not section:
        raise HTTPException(status_code=404, detail="Section not found")
    section.is_active = False
    db.commit()
    return {"message": "Section deactivated"}


# ─── TABLES ───

@router.get("/", response_model=List[TableOut])
def get_tables(
    section_id: Optional[int] = None,
    include_inactive: bool = False,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    query = db.query(Table).options(joinedload(Table.section))
    if not include_inactive:
        query = query.filter(Table.is_active == True)
    if section_id:
        query = query.filter(Table.section_id == section_id)
    
    tables = query.order_by(Table.number).all()
    
    # Enrich with active order IDs
    result = []
    for table in tables:
        table_out = TableOut.from_orm(table)
        active_order = db.query(Order).filter(
            Order.table_id == table.id,
            Order.status.notin_([OrderStatus.PAID, OrderStatus.CANCELLED, OrderStatus.VOID])
        ).first()
        table_out.active_order_id = active_order.id if active_order else None
        result.append(table_out)
    
    return result


@router.post("/", response_model=TableOut)
def create_table(
    data: TableCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_admin_or_manager())
):
    # Check if table number is unique
    if db.query(Table).filter(Table.number == data.number).first():
        raise HTTPException(status_code=400, detail=f"Table {data.number} already exists")
    
    table = Table(**data.dict())
    db.add(table)
    db.flush()
    
    # Generate QR code
    qr_dir = Path(settings.UPLOAD_DIR) / "qrcodes"
    qr_dir.mkdir(parents=True, exist_ok=True)
    
    qr_data = f"table:{table.id}:{table.number}"
    qr = qrcode.QRCode(version=1, box_size=10, border=4)
    qr.add_data(qr_data)
    qr.make(fit=True)
    img = qr.make_image(fill_color="black", back_color="white")
    
    qr_filename = f"table_{table.id}.png"
    img.save(str(qr_dir / qr_filename))
    table.qr_code_url = f"/uploads/qrcodes/{qr_filename}"
    
    db.commit()
    db.refresh(table)
    return TableOut.from_orm(table)


@router.get("/{table_id}", response_model=TableOut)
def get_table(
    table_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    table = db.query(Table).options(joinedload(Table.section)).filter(Table.id == table_id).first()
    if not table:
        raise HTTPException(status_code=404, detail="Table not found")
    
    table_out = TableOut.from_orm(table)
    active_order = db.query(Order).filter(
        Order.table_id == table.id,
        Order.status.notin_([OrderStatus.PAID, OrderStatus.CANCELLED, OrderStatus.VOID])
    ).first()
    table_out.active_order_id = active_order.id if active_order else None
    return table_out


@router.patch("/{table_id}", response_model=TableOut)
def update_table(
    table_id: int,
    data: TableUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_admin_or_manager())
):
    table = db.query(Table).filter(Table.id == table_id).first()
    if not table:
        raise HTTPException(status_code=404, detail="Table not found")
    
    for field, value in data.dict(exclude_unset=True).items():
        setattr(table, field, value)
    
    db.commit()
    db.refresh(table)
    return TableOut.from_orm(table)


@router.delete("/{table_id}")
def delete_table(
    table_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_admin_or_manager())
):
    table = db.query(Table).filter(Table.id == table_id).first()
    if not table:
        raise HTTPException(status_code=404, detail="Table not found")
    table.is_active = False
    db.commit()
    return {"message": "Table deactivated"}


@router.put("/floor-plan")
def update_floor_plan(
    data: FloorPlanUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_admin_or_manager())
):
    """Bulk update table positions from floor plan editor."""
    updated = 0
    for table_data in data.tables:
        table = db.query(Table).filter(Table.id == table_data.get("id")).first()
        if table:
            table.pos_x = table_data.get("pos_x", table.pos_x)
            table.pos_y = table_data.get("pos_y", table.pos_y)
            table.width = table_data.get("width", table.width)
            table.height = table_data.get("height", table.height)
            table.shape = table_data.get("shape", table.shape)
            updated += 1
    
    db.commit()
    return {"updated": updated}
