from fastapi import APIRouter, Depends, HTTPException, BackgroundTasks
from sqlalchemy.orm import Session, joinedload
from typing import List, Optional
from datetime import datetime

from app.db.database import get_db
from app.models.models import (
    Order, OrderItem, OrderStatus, ItemStatus, Table, TableStatus,
    User, UserRole, Payment
)
from app.schemas.schemas import (
    OrderCreate, OrderUpdate, OrderOut, OrderItemCreate, OrderItemUpdate,
    PaymentCreate, SplitPaymentCreate, ApplyDiscount
)
from app.core.deps import get_current_user, require_admin_or_manager
from app.core.websocket import manager
from app.services.order_service import (
    create_order, add_item_to_order, calculate_order_totals,
    send_order_to_kitchen, process_payment, split_order, transfer_table,
    get_kitchen_queue, get_active_orders
)
from app.models.models import Discount

router = APIRouter(prefix="/orders", tags=["Orders"])


def _order_to_dict(order: Order) -> dict:
    """Serialize order to dict for WebSocket broadcast."""
    return {
        "id": order.id,
        "order_number": order.order_number,
        "status": order.status.value,
        "table_id": order.table_id,
        "table_number": order.table.number if order.table else None,
        "order_type": order.order_type.value,
        "total_amount": order.total_amount,
        "item_count": len([i for i in order.items if i.status not in [ItemStatus.VOID, ItemStatus.CANCELLED]]),
        "sent_at": order.sent_at.isoformat() if order.sent_at else None,
    }


@router.get("/", response_model=List[OrderOut])
def get_orders(
    status: Optional[OrderStatus] = None,
    table_id: Optional[int] = None,
    active_only: bool = False,
    skip: int = 0,
    limit: int = 50,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    query = db.query(Order).options(
        joinedload(Order.items).joinedload(OrderItem.menu_item),
        joinedload(Order.table),
        joinedload(Order.waiter),
        joinedload(Order.payments)
    )

    if status:
        query = query.filter(Order.status == status)
    if table_id:
        query = query.filter(Order.table_id == table_id)
    if active_only:
        query = query.filter(
            Order.status.notin_([OrderStatus.PAID, OrderStatus.CANCELLED, OrderStatus.VOID])
        )

    # Waiters only see their own orders (unless admin/manager)
    if current_user.role == UserRole.WAITER:
        query = query.filter(Order.waiter_id == current_user.id)

    return query.order_by(Order.opened_at.desc()).offset(skip).limit(limit).all()


@router.get("/active", response_model=List[OrderOut])
def get_active_orders_endpoint(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    return get_active_orders(db)


@router.get("/kitchen-queue", response_model=List[OrderOut])
def get_kitchen_queue_endpoint(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    return get_kitchen_queue(db)


@router.post("/", response_model=OrderOut)
async def create_new_order(
    data: OrderCreate,
    background_tasks: BackgroundTasks,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    order = create_order(db, data, current_user.id)

    # Broadcast to kitchen/bar if items included
    if order.items:
        order_dict = _order_to_dict(order)
        background_tasks.add_task(manager.notify_new_order, order_dict)
        background_tasks.add_task(manager.notify_table_status, {
            "table_id": order.table_id,
            "status": "occupied"
        })

    return order


@router.get("/{order_id}", response_model=OrderOut)
def get_order(
    order_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    order = db.query(Order).options(
        joinedload(Order.items).joinedload(OrderItem.menu_item),
        joinedload(Order.table),
        joinedload(Order.waiter),
        joinedload(Order.payments)
    ).filter(Order.id == order_id).first()

    if not order:
        raise HTTPException(status_code=404, detail="Order not found")
    return order


@router.patch("/{order_id}", response_model=OrderOut)
async def update_order(
    order_id: int,
    data: OrderUpdate,
    background_tasks: BackgroundTasks,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    order = db.query(Order).filter(Order.id == order_id).first()
    if not order:
        raise HTTPException(status_code=404, detail="Order not found")

    for field, value in data.dict(exclude_unset=True).items():
        setattr(order, field, value)

    db.commit()
    db.refresh(order)

    background_tasks.add_task(manager.notify_order_update, _order_to_dict(order))
    return order


@router.post("/{order_id}/items", response_model=OrderOut)
async def add_items(
    order_id: int,
    items: List[OrderItemCreate],
    background_tasks: BackgroundTasks,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    order = db.query(Order).filter(Order.id == order_id).first()
    if not order:
        raise HTTPException(status_code=404, detail="Order not found")
    if order.status in [OrderStatus.PAID, OrderStatus.CANCELLED, OrderStatus.VOID]:
        raise HTTPException(status_code=400, detail="Cannot modify a closed order")

    for item_data in items:
        add_item_to_order(db, order, item_data, current_user.id)

    calculate_order_totals(order, db)
    db.commit()
    db.refresh(order)

    # If order was already sent, notify kitchen of additions
    if order.status in [OrderStatus.SENT, OrderStatus.IN_PROGRESS]:
        background_tasks.add_task(manager.notify_new_order, _order_to_dict(order))

    return order


@router.patch("/{order_id}/items/{item_id}", response_model=OrderOut)
async def update_order_item(
    order_id: int,
    item_id: int,
    data: OrderItemUpdate,
    background_tasks: BackgroundTasks,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    order = db.query(Order).filter(Order.id == order_id).first()
    if not order:
        raise HTTPException(status_code=404, detail="Order not found")

    item = db.query(OrderItem).filter(
        OrderItem.id == item_id,
        OrderItem.order_id == order_id
    ).first()
    if not item:
        raise HTTPException(status_code=404, detail="Item not found")

    if data.status == ItemStatus.VOID and not data.void_reason:
        raise HTTPException(status_code=400, detail="Void reason is required")

    if data.status == ItemStatus.READY:
        item.completed_at = datetime.utcnow()
        background_tasks.add_task(manager.notify_item_ready, order_id, {
            "item_id": item.id,
            "name": item.menu_item.name if item.menu_item else "",
            "quantity": item.quantity,
        })

    if data.status == ItemStatus.IN_PROGRESS:
        item.started_at = datetime.utcnow()

    for field, value in data.dict(exclude_unset=True).items():
        setattr(item, field, value)

    if data.quantity is not None:
        item.total_price = round(item.unit_price * data.quantity, 2)
        item.modifier_total = round(
            sum(m.get("price_adjustment", 0) for m in (item.modifiers or [])) * data.quantity, 2
        )

    calculate_order_totals(order, db)
    db.commit()
    db.refresh(order)

    # Check if all items done
    active_items = [i for i in order.items if i.status not in [ItemStatus.VOID, ItemStatus.CANCELLED]]
    all_done = all(i.status == ItemStatus.READY for i in active_items) if active_items else False
    if all_done:
        order.status = OrderStatus.READY
        db.commit()
        background_tasks.add_task(manager.notify_order_complete, _order_to_dict(order))

    return order


@router.delete("/{order_id}/items/{item_id}")
async def remove_order_item(
    order_id: int,
    item_id: int,
    reason: str,
    background_tasks: BackgroundTasks,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    order = db.query(Order).filter(Order.id == order_id).first()
    if not order:
        raise HTTPException(status_code=404, detail="Order not found")

    item = db.query(OrderItem).filter(
        OrderItem.id == item_id,
        OrderItem.order_id == order_id
    ).first()
    if not item:
        raise HTTPException(status_code=404, detail="Item not found")

    # Only admin/manager can void sent items
    if item.sent_at and current_user.role not in [UserRole.ADMIN, UserRole.MANAGER]:
        raise HTTPException(status_code=403, detail="Manager approval required to void sent items")

    item.status = ItemStatus.VOID
    item.void_reason = reason

    calculate_order_totals(order, db)
    db.commit()

    background_tasks.add_task(manager.notify_void_request, {
        "order_id": order_id,
        "item_id": item_id,
        "reason": reason,
        "voided_by": current_user.full_name,
    })

    return {"message": "Item voided"}


@router.post("/{order_id}/send-to-kitchen", response_model=OrderOut)
async def send_to_kitchen(
    order_id: int,
    background_tasks: BackgroundTasks,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    order = send_order_to_kitchen(db, order_id)
    background_tasks.add_task(manager.notify_new_order, _order_to_dict(order))
    return order


@router.post("/{order_id}/pay", response_model=OrderOut)
async def pay_order(
    order_id: int,
    data: SplitPaymentCreate,
    background_tasks: BackgroundTasks,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    if current_user.role not in [UserRole.ADMIN, UserRole.MANAGER, UserRole.CASHIER, UserRole.WAITER]:
        raise HTTPException(status_code=403, detail="Not authorized to process payments")

    order = process_payment(db, order_id, data.payments, current_user.id)

    background_tasks.add_task(manager.notify_payment_complete, _order_to_dict(order))
    background_tasks.add_task(manager.notify_table_status, {
        "table_id": order.table_id,
        "status": "free"
    })

    return order


@router.post("/{order_id}/apply-discount", response_model=OrderOut)
def apply_discount(
    order_id: int,
    data: ApplyDiscount,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    order = db.query(Order).filter(Order.id == order_id).first()
    if not order:
        raise HTTPException(status_code=404, detail="Order not found")

    if data.discount_id:
        discount = db.query(Discount).filter(
            Discount.id == data.discount_id,
            Discount.is_active == True
        ).first()
        if not discount:
            raise HTTPException(status_code=404, detail="Discount not found")

        if discount.requires_manager and current_user.role not in [UserRole.ADMIN, UserRole.MANAGER]:
            raise HTTPException(status_code=403, detail="Manager approval required for this discount")

        if discount.discount_type == "percentage":
            order.discount_percentage = discount.value
            order.discount_amount = round(order.subtotal * discount.value / 100, 2)
        else:
            order.discount_amount = min(discount.value, order.subtotal)

        discount.used_count += 1

    elif data.manual_discount_percentage is not None:
        if current_user.role not in [UserRole.ADMIN, UserRole.MANAGER]:
            raise HTTPException(status_code=403, detail="Manager approval required for manual discounts")
        order.discount_percentage = data.manual_discount_percentage
        order.discount_amount = round(order.subtotal * data.manual_discount_percentage / 100, 2)

    elif data.manual_discount_amount is not None:
        if current_user.role not in [UserRole.ADMIN, UserRole.MANAGER]:
            raise HTTPException(status_code=403, detail="Manager approval required for manual discounts")
        order.discount_amount = min(data.manual_discount_amount, order.subtotal)

    order.discount_reason = data.reason
    calculate_order_totals(order, db)
    db.commit()
    db.refresh(order)
    return order


@router.post("/{order_id}/split", response_model=OrderOut)
def split_order_endpoint(
    order_id: int,
    item_ids: List[int],
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    return split_order(db, order_id, item_ids)


@router.post("/{order_id}/transfer-table", response_model=OrderOut)
async def transfer_table_endpoint(
    order_id: int,
    new_table_id: int,
    background_tasks: BackgroundTasks,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    order = transfer_table(db, order_id, new_table_id)
    background_tasks.add_task(manager.notify_table_status, {
        "table_id": new_table_id, "status": "occupied"
    })
    return order


@router.post("/{order_id}/cancel", response_model=OrderOut)
async def cancel_order(
    order_id: int,
    reason: str,
    background_tasks: BackgroundTasks,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_admin_or_manager())
):
    order = db.query(Order).filter(Order.id == order_id).first()
    if not order:
        raise HTTPException(status_code=404, detail="Order not found")
    if order.status in [OrderStatus.PAID]:
        raise HTTPException(status_code=400, detail="Cannot cancel a paid order")

    order.status = OrderStatus.CANCELLED
    order.notes = f"CANCELLED: {reason}"
    order.closed_at = datetime.utcnow()

    if order.table_id:
        table = db.query(Table).filter(Table.id == order.table_id).first()
        if table:
            table.status = TableStatus.FREE

    db.commit()
    db.refresh(order)

    background_tasks.add_task(manager.notify_order_update, _order_to_dict(order))
    background_tasks.add_task(manager.notify_table_status, {
        "table_id": order.table_id, "status": "free"
    })
    return order
