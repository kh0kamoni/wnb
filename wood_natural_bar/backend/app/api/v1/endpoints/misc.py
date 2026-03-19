from fastapi import APIRouter, Depends, HTTPException, BackgroundTasks, WebSocket, WebSocketDisconnect
from sqlalchemy.orm import Session
from typing import List, Optional
from datetime import date, datetime

from app.db.database import get_db
from app.models.models import (
    Ingredient, StockMovement, Printer, RestaurantSettings,
    User, UserRole, Reservation, ShiftLog, CashMovement, Discount,
    DailyReport, ActivityLog, Order, OrderStatus
)
from app.schemas.schemas import (
    IngredientCreate, IngredientUpdate, IngredientOut, StockAdjustment,
    PrinterCreate, PrinterUpdate, PrinterOut, PrintRequest,
    ReservationCreate, ReservationUpdate, ReservationOut,
    ShiftStart, ShiftEnd, CashMovementCreate, DiscountCreate, DiscountOut,
    SettingOut, BrandingUpdate, DashboardStats
)
from app.core.deps import get_current_user, require_admin_or_manager, require_admin, get_ws_user
from app.core.websocket import manager
from app.services.print_service import print_service
from app.services.report_service import (
    get_sales_summary, get_top_items, get_revenue_by_day,
    get_revenue_by_category, get_payment_breakdown, get_staff_performance,
    get_hourly_breakdown, generate_end_of_day_report, get_dashboard_stats
)
import json

# ══════════════════════════════════════════════════════════════
#  INVENTORY
# ══════════════════════════════════════════════════════════════
inventory_router = APIRouter(prefix="/inventory", tags=["Inventory"])


@inventory_router.get("/ingredients", response_model=List[IngredientOut])
def get_ingredients(
    low_stock_only: bool = False,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    query = db.query(Ingredient).filter(Ingredient.is_active == True)
    if low_stock_only:
        query = query.filter(Ingredient.current_stock <= Ingredient.minimum_stock)
    return query.order_by(Ingredient.name).all()


@inventory_router.post("/ingredients", response_model=IngredientOut)
def create_ingredient(
    data: IngredientCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_admin_or_manager())
):
    ingredient = Ingredient(**data.dict())
    db.add(ingredient)
    db.commit()
    db.refresh(ingredient)
    return ingredient


@inventory_router.patch("/ingredients/{ingredient_id}", response_model=IngredientOut)
def update_ingredient(
    ingredient_id: int,
    data: IngredientUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_admin_or_manager())
):
    ingredient = db.query(Ingredient).filter(Ingredient.id == ingredient_id).first()
    if not ingredient:
        raise HTTPException(status_code=404, detail="Ingredient not found")
    for field, value in data.dict(exclude_unset=True).items():
        setattr(ingredient, field, value)
    db.commit()
    db.refresh(ingredient)
    return ingredient


@inventory_router.post("/adjust", response_model=IngredientOut)
async def adjust_stock(
    data: StockAdjustment,
    background_tasks: BackgroundTasks,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_admin_or_manager())
):
    ingredient = db.query(Ingredient).filter(Ingredient.id == data.ingredient_id).first()
    if not ingredient:
        raise HTTPException(status_code=404, detail="Ingredient not found")

    ingredient.current_stock = max(0, ingredient.current_stock + data.quantity)

    movement = StockMovement(
        ingredient_id=data.ingredient_id,
        movement_type=data.movement_type,
        quantity=data.quantity,
        unit_cost=data.unit_cost,
        total_cost=(data.unit_cost or 0) * abs(data.quantity),
        reference=data.reference,
        notes=data.notes,
        created_by=current_user.id,
    )
    db.add(movement)
    db.commit()
    db.refresh(ingredient)

    # Alert if low stock
    if ingredient.current_stock <= ingredient.minimum_stock:
        background_tasks.add_task(manager.notify_stock_alert, {
            "id": ingredient.id,
            "name": ingredient.name,
            "current_stock": ingredient.current_stock,
            "minimum_stock": ingredient.minimum_stock,
            "unit": ingredient.unit,
        })

    return ingredient


@inventory_router.get("/movements")
def get_stock_movements(
    ingredient_id: Optional[int] = None,
    limit: int = 100,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_admin_or_manager())
):
    query = db.query(StockMovement)
    if ingredient_id:
        query = query.filter(StockMovement.ingredient_id == ingredient_id)
    return query.order_by(StockMovement.created_at.desc()).limit(limit).all()


# ══════════════════════════════════════════════════════════════
#  PRINTERS
# ══════════════════════════════════════════════════════════════
printers_router = APIRouter(prefix="/printers", tags=["Printers"])


@printers_router.get("/", response_model=List[PrinterOut])
def get_printers(
    db: Session = Depends(get_db),
    current_user: User = Depends(require_admin_or_manager())
):
    return db.query(Printer).all()


@printers_router.post("/", response_model=PrinterOut)
def create_printer(
    data: PrinterCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_admin())
):
    printer = Printer(**data.dict())
    db.add(printer)
    db.commit()
    db.refresh(printer)
    return printer


@printers_router.patch("/{printer_id}", response_model=PrinterOut)
def update_printer(
    printer_id: int,
    data: PrinterUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_admin())
):
    printer = db.query(Printer).filter(Printer.id == printer_id).first()
    if not printer:
        raise HTTPException(status_code=404, detail="Printer not found")
    for field, value in data.dict(exclude_unset=True).items():
        setattr(printer, field, value)
    db.commit()
    db.refresh(printer)
    return printer


@printers_router.post("/{printer_id}/test")
def test_printer(
    printer_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_admin_or_manager())
):
    printer = db.query(Printer).filter(Printer.id == printer_id).first()
    if not printer:
        raise HTTPException(status_code=404, detail="Printer not found")

    success = print_service.test_printer(printer.ip_address, printer.port)
    printer.last_test_at = datetime.utcnow()
    printer.last_test_success = success
    db.commit()
    return {"success": success, "printer": printer.name}


@printers_router.post("/print")
def print_document(
    data: PrintRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    from app.models.models import Order as OrderModel
    from sqlalchemy.orm import joinedload
    from app.models.models import OrderItem

    order = db.query(OrderModel).options(
        joinedload(OrderModel.items).joinedload(OrderItem.menu_item),
        joinedload(OrderModel.table),
        joinedload(OrderModel.waiter),
        joinedload(OrderModel.payments)
    ).filter(OrderModel.id == data.order_id).first()

    if not order:
        raise HTTPException(status_code=404, detail="Order not found")

    printer = None
    if data.printer_id:
        printer = db.query(Printer).filter(Printer.id == data.printer_id).first()

    if data.print_type == "receipt":
        success = print_service.print_receipt(order, printer)
    elif data.print_type in ["kitchen", "bar"]:
        success = print_service.print_kitchen_ticket(order, printer)
    else:
        raise HTTPException(status_code=400, detail="Invalid print type")

    return {"success": success}


@printers_router.post("/cash-drawer")
def open_cash_drawer(
    printer_id: Optional[int] = None,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    printer = None
    if printer_id:
        printer = db.query(Printer).filter(Printer.id == printer_id).first()
    success = print_service.open_cash_drawer(printer)
    return {"success": success}


# ══════════════════════════════════════════════════════════════
#  RESERVATIONS
# ══════════════════════════════════════════════════════════════
reservations_router = APIRouter(prefix="/reservations", tags=["Reservations"])


@reservations_router.get("/", response_model=List[ReservationOut])
def get_reservations(
    reservation_date: Optional[date] = None,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    query = db.query(Reservation)
    if reservation_date:
        query = query.filter(Reservation.reservation_date == reservation_date)
    return query.order_by(Reservation.reservation_date, Reservation.reservation_time).all()


@reservations_router.post("/", response_model=ReservationOut)
def create_reservation(
    data: ReservationCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    reservation = Reservation(**data.dict(), created_by=current_user.id)
    db.add(reservation)
    db.commit()
    db.refresh(reservation)
    return reservation


@reservations_router.patch("/{reservation_id}", response_model=ReservationOut)
def update_reservation(
    reservation_id: int,
    data: ReservationUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    reservation = db.query(Reservation).filter(Reservation.id == reservation_id).first()
    if not reservation:
        raise HTTPException(status_code=404, detail="Reservation not found")
    for field, value in data.dict(exclude_unset=True).items():
        setattr(reservation, field, value)
    db.commit()
    db.refresh(reservation)
    return reservation


@reservations_router.delete("/{reservation_id}")
def cancel_reservation(
    reservation_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    from app.models.models import ReservationStatus
    reservation = db.query(Reservation).filter(Reservation.id == reservation_id).first()
    if not reservation:
        raise HTTPException(status_code=404, detail="Reservation not found")
    reservation.status = ReservationStatus.CANCELLED
    db.commit()
    return {"message": "Reservation cancelled"}


# ══════════════════════════════════════════════════════════════
#  REPORTS
# ══════════════════════════════════════════════════════════════
reports_router = APIRouter(prefix="/reports", tags=["Reports"])


@reports_router.get("/dashboard")
def get_dashboard(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    return get_dashboard_stats(db)


@reports_router.get("/sales")
def get_sales_report(
    start_date: date,
    end_date: date,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_admin_or_manager())
):
    return {
        "summary": get_sales_summary(db, start_date, end_date),
        "top_items": get_top_items(db, start_date, end_date),
        "revenue_by_day": get_revenue_by_day(db, start_date, end_date),
        "revenue_by_category": get_revenue_by_category(db, start_date, end_date),
        "payment_breakdown": get_payment_breakdown(db, start_date, end_date),
        "staff_performance": get_staff_performance(db, start_date, end_date),
    }


@reports_router.get("/hourly")
def get_hourly_report(
    target_date: date,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_admin_or_manager())
):
    return get_hourly_breakdown(db, target_date)


@reports_router.post("/end-of-day")
def generate_eod_report(
    target_date: date,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_admin_or_manager())
):
    report = generate_end_of_day_report(db, target_date, current_user.id)
    return report


@reports_router.get("/end-of-day/history")
def get_eod_history(
    limit: int = 30,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_admin_or_manager())
):
    return db.query(DailyReport).order_by(DailyReport.report_date.desc()).limit(limit).all()


@reports_router.get("/activity-log")
def get_activity_log(
    limit: int = 100,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_admin())
):
    return db.query(ActivityLog).order_by(ActivityLog.created_at.desc()).limit(limit).all()


# ══════════════════════════════════════════════════════════════
#  SETTINGS
# ══════════════════════════════════════════════════════════════
settings_router = APIRouter(prefix="/settings", tags=["Settings"])


@settings_router.get("/")
def get_all_settings(
    category: Optional[str] = None,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_admin())
):
    query = db.query(RestaurantSettings)
    if category:
        query = query.filter(RestaurantSettings.category == category)
    settings_list = query.order_by(RestaurantSettings.category, RestaurantSettings.key).all()
    return {s.key: {"value": s.value, "type": s.value_type, "category": s.category, "description": s.description} for s in settings_list}


@settings_router.get("/public")
def get_public_settings(db: Session = Depends(get_db)):
    """Public settings accessible without auth (for Flutter app branding)."""
    settings_list = db.query(RestaurantSettings).filter(
        RestaurantSettings.is_public == True
    ).all()
    return {s.key: s.value for s in settings_list}


@settings_router.put("/branding")
async def update_branding(
    data: BrandingUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_admin())
):
    """Update restaurant branding settings."""
    updates = data.dict(exclude_unset=True, exclude_none=True)
    for key, value in updates.items():
        setting = db.query(RestaurantSettings).filter(RestaurantSettings.key == key).first()
        if setting:
            setting.value = str(value) if not isinstance(value, dict) else json.dumps(value)
            setting.updated_by = current_user.id
        else:
            db.add(RestaurantSettings(
                key=key,
                value=str(value) if not isinstance(value, dict) else json.dumps(value),
                category="branding",
                is_public=True,
                updated_by=current_user.id
            ))
    db.commit()
    return {"message": "Branding updated", "updated_keys": list(updates.keys())}


@settings_router.post("/logo")
async def upload_logo(
    file,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_admin())
):
    from fastapi import UploadFile, File
    import aiofiles
    from pathlib import Path
    from app.core.config import settings as app_settings
    import aiofiles

    upload_dir = Path(app_settings.STATIC_DIR) / "branding"
    upload_dir.mkdir(parents=True, exist_ok=True)

    filename = f"logo.{file.filename.split('.')[-1]}"
    async with aiofiles.open(upload_dir / filename, 'wb') as f:
        await f.write(await file.read())

    logo_url = f"/static/branding/{filename}"
    setting = db.query(RestaurantSettings).filter(RestaurantSettings.key == "logo_url").first()
    if setting:
        setting.value = logo_url
    else:
        db.add(RestaurantSettings(key="logo_url", value=logo_url, category="branding", is_public=True))
    db.commit()
    return {"logo_url": logo_url}


# ══════════════════════════════════════════════════════════════
#  DISCOUNTS
# ══════════════════════════════════════════════════════════════
discounts_router = APIRouter(prefix="/discounts", tags=["Discounts"])


@discounts_router.get("/", response_model=List[DiscountOut])
def get_discounts(
    db: Session = Depends(get_db),
    current_user: User = Depends(require_admin_or_manager())
):
    return db.query(Discount).order_by(Discount.name).all()


@discounts_router.post("/", response_model=DiscountOut)
def create_discount(
    data: DiscountCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_admin_or_manager())
):
    discount = Discount(**data.dict())
    db.add(discount)
    db.commit()
    db.refresh(discount)
    return discount


@discounts_router.patch("/{discount_id}", response_model=DiscountOut)
def update_discount(
    discount_id: int,
    data: DiscountCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_admin_or_manager())
):
    discount = db.query(Discount).filter(Discount.id == discount_id).first()
    if not discount:
        raise HTTPException(status_code=404, detail="Discount not found")
    for field, value in data.dict(exclude_unset=True).items():
        setattr(discount, field, value)
    db.commit()
    db.refresh(discount)
    return discount


@discounts_router.delete("/{discount_id}")
def delete_discount(
    discount_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_admin_or_manager())
):
    discount = db.query(Discount).filter(Discount.id == discount_id).first()
    if not discount:
        raise HTTPException(status_code=404, detail="Discount not found")
    discount.is_active = False
    db.commit()
    return {"message": "Discount deactivated"}


# ══════════════════════════════════════════════════════════════
#  SHIFT / CASH MANAGEMENT
# ══════════════════════════════════════════════════════════════
shift_router = APIRouter(prefix="/shifts", tags=["Shifts"])


@shift_router.post("/start")
def start_shift(
    data: ShiftStart,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    active = db.query(ShiftLog).filter(
        ShiftLog.user_id == current_user.id,
        ShiftLog.clock_out == None
    ).first()
    if active:
        raise HTTPException(status_code=400, detail="Shift already active")

    shift = ShiftLog(
        user_id=current_user.id,
        clock_in=datetime.utcnow(),
        opening_balance=data.opening_balance,
    )
    db.add(shift)
    db.commit()
    db.refresh(shift)
    return shift


@shift_router.post("/end")
def end_shift(
    data: ShiftEnd,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    shift = db.query(ShiftLog).filter(
        ShiftLog.user_id == current_user.id,
        ShiftLog.clock_out == None
    ).first()
    if not shift:
        raise HTTPException(status_code=400, detail="No active shift found")

    shift.clock_out = datetime.utcnow()
    shift.closing_balance = data.closing_balance
    shift.notes = data.notes
    db.commit()
    db.refresh(shift)
    return shift


@shift_router.get("/active")
def get_active_shift(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    shift = db.query(ShiftLog).filter(
        ShiftLog.user_id == current_user.id,
        ShiftLog.clock_out == None
    ).first()
    return shift


@shift_router.post("/cash-movement")
def record_cash_movement(
    data: CashMovementCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    shift = db.query(ShiftLog).filter(
        ShiftLog.user_id == current_user.id,
        ShiftLog.clock_out == None
    ).first()

    movement = CashMovement(
        shift_log_id=shift.id if shift else None,
        movement_type=data.movement_type,
        amount=data.amount,
        reason=data.reason,
        created_by=current_user.id,
    )
    db.add(movement)
    db.commit()
    return {"message": "Cash movement recorded"}


# ══════════════════════════════════════════════════════════════
#  WEBSOCKET
# ══════════════════════════════════════════════════════════════
ws_router = APIRouter(tags=["WebSocket"])


@ws_router.websocket("/ws/{role}")
async def websocket_endpoint(
    websocket: WebSocket,
    role: str,
    db: Session = Depends(get_db)
):
    user = await get_ws_user(websocket, db)
    if not user:
        await websocket.close(code=4001)
        return

    await manager.connect(websocket, role)
    try:
        # Send initial connection confirmation
        await manager.send_personal_message(
            {"type": "connected", "data": {"role": role, "user": user.full_name}},
            websocket
        )
        while True:
            data = await websocket.receive_text()
            msg = json.loads(data)
            # Handle ping/pong
            if msg.get("type") == "ping":
                await manager.send_personal_message({"type": "pong"}, websocket)

    except WebSocketDisconnect:
        manager.disconnect(websocket, role)
    except Exception as e:
        manager.disconnect(websocket, role)


@ws_router.get("/ws/stats")
def websocket_stats(current_user: User = Depends(require_admin_or_manager())):
    return manager.get_stats()
