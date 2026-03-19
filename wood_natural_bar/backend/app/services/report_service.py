from sqlalchemy.orm import Session
from sqlalchemy import func, and_, extract, cast, Date
from typing import List, Dict, Optional
from datetime import datetime, date, timedelta
from app.models.models import (
    Order, OrderItem, OrderStatus, Payment, PaymentMethod,
    MenuItem, Category, User, DailyReport, ItemStatus
)


def get_sales_summary(db: Session, start_date: date, end_date: date) -> Dict:
    """Get sales summary for a date range."""
    start_dt = datetime.combine(start_date, datetime.min.time())
    end_dt = datetime.combine(end_date, datetime.max.time())
    
    orders = db.query(Order).filter(
        Order.status == OrderStatus.PAID,
        Order.paid_at.between(start_dt, end_dt)
    ).all()
    
    total_revenue = sum(o.total_amount for o in orders)
    total_tax = sum(o.tax_amount for o in orders)
    total_discounts = sum(o.discount_amount for o in orders)
    total_covers = sum(o.guest_count for o in orders)
    
    return {
        "total_orders": len(orders),
        "total_revenue": round(total_revenue, 2),
        "total_tax": round(total_tax, 2),
        "total_discounts": round(total_discounts, 2),
        "total_covers": total_covers,
        "avg_order_value": round(total_revenue / len(orders), 2) if orders else 0.0,
        "avg_covers": round(total_covers / len(orders), 2) if orders else 0.0,
    }


def get_top_items(db: Session, start_date: date, end_date: date, limit: int = 10) -> List[Dict]:
    """Get best-selling menu items."""
    start_dt = datetime.combine(start_date, datetime.min.time())
    end_dt = datetime.combine(end_date, datetime.max.time())
    
    results = (
        db.query(
            MenuItem.id,
            MenuItem.name,
            func.sum(OrderItem.quantity).label("total_qty"),
            func.sum(OrderItem.total_price).label("total_revenue"),
        )
        .join(OrderItem, MenuItem.id == OrderItem.menu_item_id)
        .join(Order, OrderItem.order_id == Order.id)
        .filter(
            Order.status == OrderStatus.PAID,
            Order.paid_at.between(start_dt, end_dt),
            OrderItem.status != ItemStatus.VOID
        )
        .group_by(MenuItem.id, MenuItem.name)
        .order_by(func.sum(OrderItem.quantity).desc())
        .limit(limit)
        .all()
    )
    
    return [
        {
            "id": r.id,
            "name": r.name,
            "total_qty": int(r.total_qty or 0),
            "total_revenue": round(float(r.total_revenue or 0), 2),
        }
        for r in results
    ]


def get_revenue_by_day(db: Session, start_date: date, end_date: date) -> List[Dict]:
    """Get daily revenue breakdown."""
    start_dt = datetime.combine(start_date, datetime.min.time())
    end_dt = datetime.combine(end_date, datetime.max.time())
    
    results = (
        db.query(
            cast(Order.paid_at, Date).label("day"),
            func.count(Order.id).label("order_count"),
            func.sum(Order.total_amount).label("revenue"),
        )
        .filter(
            Order.status == OrderStatus.PAID,
            Order.paid_at.between(start_dt, end_dt)
        )
        .group_by(cast(Order.paid_at, Date))
        .order_by(cast(Order.paid_at, Date).asc())
        .all()
    )
    
    # Fill in missing days with zeros
    day_map = {r.day: r for r in results}
    output = []
    current = start_date
    while current <= end_date:
        r = day_map.get(current)
        output.append({
            "date": current.isoformat(),
            "orders": int(r.order_count) if r else 0,
            "revenue": round(float(r.revenue), 2) if r else 0.0,
        })
        current += timedelta(days=1)
    return output


def get_revenue_by_category(db: Session, start_date: date, end_date: date) -> List[Dict]:
    """Revenue breakdown by menu category."""
    start_dt = datetime.combine(start_date, datetime.min.time())
    end_dt = datetime.combine(end_date, datetime.max.time())
    
    results = (
        db.query(
            Category.name,
            func.sum(OrderItem.quantity).label("total_qty"),
            func.sum(OrderItem.total_price).label("total_revenue"),
        )
        .join(MenuItem, Category.id == MenuItem.category_id)
        .join(OrderItem, MenuItem.id == OrderItem.menu_item_id)
        .join(Order, OrderItem.order_id == Order.id)
        .filter(
            Order.status == OrderStatus.PAID,
            Order.paid_at.between(start_dt, end_dt),
        )
        .group_by(Category.name)
        .order_by(func.sum(OrderItem.total_price).desc())
        .all()
    )
    
    return [
        {
            "category": r.name,
            "quantity": int(r.total_qty or 0),
            "revenue": round(float(r.total_revenue or 0), 2),
        }
        for r in results
    ]


def get_payment_breakdown(db: Session, start_date: date, end_date: date) -> Dict:
    """Revenue breakdown by payment method."""
    start_dt = datetime.combine(start_date, datetime.min.time())
    end_dt = datetime.combine(end_date, datetime.max.time())
    
    results = (
        db.query(
            Payment.method,
            func.sum(Payment.amount).label("total"),
            func.count(Payment.id).label("count"),
        )
        .join(Order, Payment.order_id == Order.id)
        .filter(
            Order.status == OrderStatus.PAID,
            Order.paid_at.between(start_dt, end_dt),
        )
        .group_by(Payment.method)
        .all()
    )
    
    return {
        r.method.value: {
            "total": round(float(r.total or 0), 2),
            "count": int(r.count),
        }
        for r in results
    }


def get_staff_performance(db: Session, start_date: date, end_date: date) -> List[Dict]:
    """Staff sales performance report."""
    start_dt = datetime.combine(start_date, datetime.min.time())
    end_dt = datetime.combine(end_date, datetime.max.time())
    
    results = (
        db.query(
            User.id,
            User.full_name,
            func.count(Order.id).label("order_count"),
            func.sum(Order.total_amount).label("revenue"),
            func.avg(Order.total_amount).label("avg_order"),
        )
        .join(Order, User.id == Order.waiter_id)
        .filter(
            Order.status == OrderStatus.PAID,
            Order.paid_at.between(start_dt, end_dt),
        )
        .group_by(User.id, User.full_name)
        .order_by(func.sum(Order.total_amount).desc())
        .all()
    )
    
    return [
        {
            "user_id": r.id,
            "name": r.full_name,
            "orders": int(r.order_count),
            "revenue": round(float(r.revenue or 0), 2),
            "avg_order": round(float(r.avg_order or 0), 2),
        }
        for r in results
    ]


def get_hourly_breakdown(db: Session, target_date: date) -> List[Dict]:
    """Hourly order volume for a specific date."""
    start_dt = datetime.combine(target_date, datetime.min.time())
    end_dt = datetime.combine(target_date, datetime.max.time())
    
    results = (
        db.query(
            extract('hour', Order.opened_at).label("hour"),
            func.count(Order.id).label("order_count"),
            func.sum(Order.total_amount).label("revenue"),
        )
        .filter(
            Order.status == OrderStatus.PAID,
            Order.paid_at.between(start_dt, end_dt),
        )
        .group_by(extract('hour', Order.opened_at))
        .order_by(extract('hour', Order.opened_at))
        .all()
    )
    
    hour_map = {int(r.hour): r for r in results}
    return [
        {
            "hour": h,
            "label": f"{h:02d}:00",
            "orders": int(hour_map[h].order_count) if h in hour_map else 0,
            "revenue": round(float(hour_map[h].revenue), 2) if h in hour_map else 0.0,
        }
        for h in range(24)
    ]


def generate_end_of_day_report(db: Session, target_date: date, generated_by: int) -> DailyReport:
    """Generate and save end-of-day report."""
    summary = get_sales_summary(db, target_date, target_date)
    payment_breakdown = get_payment_breakdown(db, target_date, target_date)
    
    report = db.query(DailyReport).filter(DailyReport.report_date == target_date).first()
    if not report:
        report = DailyReport(report_date=target_date)
        db.add(report)
    
    report.total_orders = summary["total_orders"]
    report.total_covers = summary["total_covers"]
    report.total_revenue = summary["total_revenue"]
    report.total_tax = summary["total_tax"]
    report.total_discounts = summary["total_discounts"]
    report.avg_order_value = summary["avg_order_value"]
    report.cash_revenue = payment_breakdown.get("cash", {}).get("total", 0)
    report.card_revenue = payment_breakdown.get("card", {}).get("total", 0)
    report.mobile_revenue = payment_breakdown.get("mobile", {}).get("total", 0)
    report.generated_by = generated_by
    
    # Snapshot
    report.data_snapshot = {
        "summary": summary,
        "payment_breakdown": payment_breakdown,
        "top_items": get_top_items(db, target_date, target_date, 20),
        "hourly": get_hourly_breakdown(db, target_date),
    }
    
    db.commit()
    db.refresh(report)
    return report


def get_dashboard_stats(db: Session) -> Dict:
    """Real-time dashboard statistics."""
    today = date.today()
    start_dt = datetime.combine(today, datetime.min.time())
    
    today_orders = db.query(func.count(Order.id)).filter(
        Order.status == OrderStatus.PAID,
        Order.paid_at >= start_dt
    ).scalar() or 0
    
    today_revenue = db.query(func.sum(Order.total_amount)).filter(
        Order.status == OrderStatus.PAID,
        Order.paid_at >= start_dt
    ).scalar() or 0.0
    
    today_covers = db.query(func.sum(Order.guest_count)).filter(
        Order.status == OrderStatus.PAID,
        Order.paid_at >= start_dt
    ).scalar() or 0
    
    from app.models.models import Table, TableStatus, Ingredient
    active_tables = db.query(func.count(Table.id)).filter(
        Table.status == TableStatus.OCCUPIED
    ).scalar() or 0
    
    free_tables = db.query(func.count(Table.id)).filter(
        Table.status == TableStatus.FREE,
        Table.is_active == True
    ).scalar() or 0
    
    pending_items = db.query(func.count(OrderItem.id)).filter(
        OrderItem.status.in_([ItemStatus.PENDING, ItemStatus.IN_PROGRESS])
    ).scalar() or 0
    
    low_stock = db.query(func.count(Ingredient.id)).filter(
        Ingredient.is_active == True,
        Ingredient.current_stock <= Ingredient.minimum_stock
    ).scalar() or 0
    
    return {
        "today_revenue": round(float(today_revenue), 2),
        "today_orders": int(today_orders),
        "today_covers": int(today_covers),
        "active_tables": int(active_tables),
        "free_tables": int(free_tables),
        "pending_kitchen_items": int(pending_items),
        "low_stock_alerts": int(low_stock),
    }
