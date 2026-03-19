from sqlalchemy.orm import Session, joinedload
from sqlalchemy import func, and_, or_
from typing import List, Optional
from datetime import datetime
import random
import string

from app.models.models import (
    Order, OrderItem, OrderStatus, MenuItem, Table, TableStatus,
    ItemStatus, Payment, PaymentMethod, PaymentStatus, StockMovement,
    StockMovementType, RecipeItem, Ingredient, OrderType
)
from app.schemas.schemas import OrderCreate, OrderUpdate, OrderItemCreate
from app.core.config import settings
from fastapi import HTTPException


def generate_order_number(db: Session) -> str:
    """Generate a unique order number like WNB-2024-0001."""
    today = datetime.utcnow()
    prefix = f"WNB-{today.strftime('%Y%m%d')}-"
    
    last_order = (
        db.query(Order)
        .filter(Order.order_number.like(f"{prefix}%"))
        .order_by(Order.id.desc())
        .first()
    )
    
    if last_order:
        last_num = int(last_order.order_number.split("-")[-1])
        return f"{prefix}{str(last_num + 1).zfill(4)}"
    return f"{prefix}0001"


def calculate_order_totals(order: Order, db: Session) -> Order:
    """Recalculate all financial totals for an order."""
    subtotal = sum(item.total_price + item.modifier_total for item in order.items 
                   if item.status not in [ItemStatus.CANCELLED, ItemStatus.VOID])
    
    order.subtotal = round(subtotal, 2)
    
    # Apply percentage discount first
    if order.discount_percentage > 0:
        order.discount_amount = round(subtotal * (order.discount_percentage / 100), 2)
    
    discounted = subtotal - order.discount_amount
    
    # Tax calculation
    tax_rate = settings.RESTAURANT_TAX_RATE
    order.tax_amount = round(discounted * tax_rate, 2)
    
    # Service charge
    service_rate = settings.RESTAURANT_SERVICE_CHARGE
    order.service_charge_amount = round(discounted * service_rate, 2)
    
    order.total_amount = round(
        discounted + order.tax_amount + order.service_charge_amount, 2
    )
    
    return order


def create_order(db: Session, order_data: OrderCreate, waiter_id: int) -> Order:
    """Create a new order with items."""
    order_number = generate_order_number(db)
    
    order = Order(
        order_number=order_number,
        table_id=order_data.table_id,
        order_type=order_data.order_type,
        guest_count=order_data.guest_count,
        waiter_id=waiter_id,
        notes=order_data.notes,
        customer_name=order_data.customer_name,
        customer_phone=order_data.customer_phone,
        customer_address=order_data.customer_address,
        status=OrderStatus.DRAFT,
    )
    db.add(order)
    db.flush()
    
    # Update table status if dine-in
    if order_data.table_id and order_data.order_type == OrderType.DINE_IN:
        table = db.query(Table).filter(Table.id == order_data.table_id).first()
        if table:
            table.status = TableStatus.OCCUPIED
    
    # Add items
    for item_data in order_data.items:
        add_item_to_order(db, order, item_data, waiter_id)
    
    calculate_order_totals(order, db)
    db.commit()
    db.refresh(order)
    return order


def add_item_to_order(
    db: Session, order: Order, item_data: OrderItemCreate, added_by: int
) -> OrderItem:
    """Add an item to an existing order."""
    menu_item = db.query(MenuItem).filter(
        MenuItem.id == item_data.menu_item_id,
        MenuItem.is_active == True
    ).first()
    
    if not menu_item:
        raise HTTPException(status_code=404, detail=f"Menu item {item_data.menu_item_id} not found")
    
    if not menu_item.is_available:
        raise HTTPException(status_code=400, detail=f"{menu_item.name} is currently unavailable")
    
    modifier_total = sum(m.price_adjustment for m in item_data.modifiers)
    
    order_item = OrderItem(
        order_id=order.id,
        menu_item_id=menu_item.id,
        quantity=item_data.quantity,
        unit_price=menu_item.price,
        total_price=round(menu_item.price * item_data.quantity, 2),
        modifier_total=round(modifier_total * item_data.quantity, 2),
        notes=item_data.notes,
        modifiers=[m.dict() for m in item_data.modifiers],
        seat_number=item_data.seat_number,
        course=item_data.course,
        added_by=added_by,
    )
    db.add(order_item)
    return order_item


def send_order_to_kitchen(db: Session, order_id: int) -> Order:
    """Mark order as sent to kitchen."""
    order = db.query(Order).options(
        joinedload(Order.items).joinedload(OrderItem.menu_item)
    ).filter(Order.id == order_id).first()
    
    if not order:
        raise HTTPException(status_code=404, detail="Order not found")
    
    order.status = OrderStatus.SENT
    order.sent_at = datetime.utcnow()
    
    # Mark all draft items as pending
    for item in order.items:
        if item.status == ItemStatus.PENDING:
            item.sent_at = datetime.utcnow()
    
    db.commit()
    db.refresh(order)
    return order


def process_payment(
    db: Session,
    order_id: int,
    payments: list,
    processed_by: int
) -> Order:
    """Process payment for an order."""
    order = db.query(Order).filter(Order.id == order_id).first()
    if not order:
        raise HTTPException(status_code=404, detail="Order not found")
    
    total_paid = 0.0
    for payment_data in payments:
        payment = Payment(
            order_id=order_id,
            method=payment_data.method,
            amount=payment_data.amount,
            reference=payment_data.reference,
            notes=payment_data.notes,
            status=PaymentStatus.COMPLETED,
            processed_by=processed_by,
        )
        db.add(payment)
        total_paid += payment_data.amount
    
    order.paid_amount = round(total_paid, 2)
    order.change_amount = round(max(0, total_paid - order.total_amount), 2)
    order.status = OrderStatus.PAID
    order.paid_at = datetime.utcnow()
    order.closed_at = datetime.utcnow()
    order.cashier_id = processed_by
    
    # Free up the table
    if order.table_id:
        table = db.query(Table).filter(Table.id == order.table_id).first()
        if table:
            table.status = TableStatus.FREE
    
    # Deduct inventory if recipe tracking enabled
    _deduct_inventory(db, order)
    
    db.commit()
    db.refresh(order)
    return order


def _deduct_inventory(db: Session, order: Order):
    """Deduct ingredients from stock based on recipes."""
    for item in order.items:
        if item.status == ItemStatus.VOID:
            continue
        
        recipe_items = db.query(RecipeItem).filter(
            RecipeItem.menu_item_id == item.menu_item_id
        ).all()
        
        for recipe_item in recipe_items:
            ingredient = db.query(Ingredient).filter(
                Ingredient.id == recipe_item.ingredient_id
            ).first()
            
            if ingredient:
                deduction = recipe_item.quantity * item.quantity
                ingredient.current_stock = max(0, ingredient.current_stock - deduction)
                
                movement = StockMovement(
                    ingredient_id=ingredient.id,
                    movement_type=StockMovementType.USAGE,
                    quantity=-deduction,
                    reference=order.order_number,
                )
                db.add(movement)


def get_kitchen_queue(db: Session) -> List[Order]:
    """Get all orders pending kitchen action."""
    return (
        db.query(Order)
        .options(
            joinedload(Order.items).joinedload(OrderItem.menu_item),
            joinedload(Order.table)
        )
        .filter(
            Order.status.in_([OrderStatus.SENT, OrderStatus.IN_PROGRESS]),
            Order.items.any(
                OrderItem.status.in_([ItemStatus.PENDING, ItemStatus.IN_PROGRESS])
            )
        )
        .order_by(Order.sent_at.asc())
        .all()
    )


def get_active_orders(db: Session) -> List[Order]:
    """Get all active (non-closed) orders."""
    return (
        db.query(Order)
        .options(
            joinedload(Order.items).joinedload(OrderItem.menu_item),
            joinedload(Order.table),
            joinedload(Order.waiter)
        )
        .filter(
            Order.status.notin_([OrderStatus.PAID, OrderStatus.CANCELLED, OrderStatus.VOID])
        )
        .order_by(Order.opened_at.desc())
        .all()
    )


def split_order(db: Session, order_id: int, item_ids: List[int]) -> Order:
    """Split selected items into a new order."""
    original_order = db.query(Order).filter(Order.id == order_id).first()
    if not original_order:
        raise HTTPException(status_code=404, detail="Order not found")
    
    # Create new order
    new_order = Order(
        order_number=generate_order_number(db),
        table_id=original_order.table_id,
        order_type=original_order.order_type,
        guest_count=1,
        waiter_id=original_order.waiter_id,
        status=original_order.status,
    )
    db.add(new_order)
    db.flush()
    
    # Move items
    for item_id in item_ids:
        item = db.query(OrderItem).filter(
            OrderItem.id == item_id,
            OrderItem.order_id == order_id
        ).first()
        if item:
            item.order_id = new_order.id
    
    calculate_order_totals(original_order, db)
    calculate_order_totals(new_order, db)
    
    db.commit()
    db.refresh(new_order)
    return new_order


def transfer_table(db: Session, order_id: int, new_table_id: int) -> Order:
    """Transfer an order to a different table."""
    order = db.query(Order).filter(Order.id == order_id).first()
    if not order:
        raise HTTPException(status_code=404, detail="Order not found")
    
    new_table = db.query(Table).filter(Table.id == new_table_id).first()
    if not new_table:
        raise HTTPException(status_code=404, detail="Table not found")
    if new_table.status == TableStatus.OCCUPIED:
        raise HTTPException(status_code=400, detail="Target table is already occupied")
    
    # Free old table
    if order.table_id:
        old_table = db.query(Table).filter(Table.id == order.table_id).first()
        if old_table:
            old_table.status = TableStatus.FREE
    
    # Occupy new table
    order.table_id = new_table_id
    new_table.status = TableStatus.OCCUPIED
    
    db.commit()
    db.refresh(order)
    return order
