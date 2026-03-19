from sqlalchemy import (
    Column, Integer, String, Float, Boolean, DateTime, Text,
    ForeignKey, Enum, JSON, BigInteger, Date, Time
)
from sqlalchemy.orm import relationship
from sqlalchemy.sql import func
from app.db.database import Base
import enum


# ─────────────────── ENUMS ───────────────────

class UserRole(str, enum.Enum):
    ADMIN = "admin"
    MANAGER = "manager"
    WAITER = "waiter"
    CASHIER = "cashier"
    KITCHEN = "kitchen"
    BAR = "bar"


class TableStatus(str, enum.Enum):
    FREE = "free"
    OCCUPIED = "occupied"
    RESERVED = "reserved"
    CLEANING = "cleaning"
    INACTIVE = "inactive"


class OrderStatus(str, enum.Enum):
    DRAFT = "draft"
    SENT = "sent"
    IN_PROGRESS = "in_progress"
    READY = "ready"
    SERVED = "served"
    BILLED = "billed"
    PAID = "paid"
    CANCELLED = "cancelled"
    VOID = "void"


class OrderType(str, enum.Enum):
    DINE_IN = "dine_in"
    TAKEAWAY = "takeaway"
    DELIVERY = "delivery"


class ItemStatus(str, enum.Enum):
    PENDING = "pending"
    IN_PROGRESS = "in_progress"
    READY = "ready"
    SERVED = "served"
    CANCELLED = "cancelled"
    VOID = "void"


class PaymentMethod(str, enum.Enum):
    CASH = "cash"
    CARD = "card"
    MOBILE = "mobile"
    SPLIT = "split"
    COMPLIMENTARY = "complimentary"


class PaymentStatus(str, enum.Enum):
    PENDING = "pending"
    COMPLETED = "completed"
    REFUNDED = "refunded"
    FAILED = "failed"


class PrinterType(str, enum.Enum):
    RECEIPT = "receipt"
    KITCHEN = "kitchen"
    BAR = "bar"
    LABEL = "label"


class StockMovementType(str, enum.Enum):
    PURCHASE = "purchase"
    USAGE = "usage"
    ADJUSTMENT = "adjustment"
    WASTE = "waste"
    RETURN = "return"


class ReservationStatus(str, enum.Enum):
    CONFIRMED = "confirmed"
    CANCELLED = "cancelled"
    SEATED = "seated"
    NO_SHOW = "no_show"


# ─────────────────── MODELS ───────────────────

class User(Base):
    __tablename__ = "users"

    id = Column(Integer, primary_key=True, index=True)
    username = Column(String(50), unique=True, index=True, nullable=False)
    email = Column(String(100), unique=True, index=True, nullable=True)
    full_name = Column(String(100), nullable=False)
    hashed_password = Column(String(255), nullable=False)
    role = Column(Enum(UserRole), nullable=False, default=UserRole.WAITER)
    pin_code = Column(String(10), nullable=True)  # For quick login on POS
    is_active = Column(Boolean, default=True)
    avatar_url = Column(String(500), nullable=True)
    phone = Column(String(20), nullable=True)
    notes = Column(Text, nullable=True)
    permissions = Column(JSON, default={})  # Extra granular permissions
    last_login = Column(DateTime(timezone=True), nullable=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), onupdate=func.now())

    # Relationships
    orders = relationship("Order", back_populates="waiter", foreign_keys="Order.waiter_id")
    shift_logs = relationship("ShiftLog", back_populates="user")
    activity_logs = relationship("ActivityLog", back_populates="user")


class RestaurantSettings(Base):
    __tablename__ = "restaurant_settings"

    id = Column(Integer, primary_key=True)
    key = Column(String(100), unique=True, nullable=False, index=True)
    value = Column(Text, nullable=True)
    value_type = Column(String(20), default="string")  # string, int, float, bool, json
    category = Column(String(50), default="general")
    description = Column(String(255), nullable=True)
    is_public = Column(Boolean, default=False)  # Visible to flutter without auth
    updated_at = Column(DateTime(timezone=True), onupdate=func.now())
    updated_by = Column(Integer, ForeignKey("users.id"), nullable=True)


class Category(Base):
    __tablename__ = "categories"

    id = Column(Integer, primary_key=True, index=True)
    name = Column(String(100), nullable=False)
    description = Column(Text, nullable=True)
    image_url = Column(String(500), nullable=True)
    color = Column(String(10), nullable=True)  # Hex color for UI
    icon = Column(String(50), nullable=True)   # Icon name
    sort_order = Column(Integer, default=0)
    is_active = Column(Boolean, default=True)
    parent_id = Column(Integer, ForeignKey("categories.id"), nullable=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now())

    # Relationships
    items = relationship("MenuItem", back_populates="category")
    children = relationship("Category")


class MenuItem(Base):
    __tablename__ = "menu_items"

    id = Column(Integer, primary_key=True, index=True)
    name = Column(String(200), nullable=False)
    description = Column(Text, nullable=True)
    price = Column(Float, nullable=False)
    cost_price = Column(Float, nullable=True)  # For profit margin calculation
    category_id = Column(Integer, ForeignKey("categories.id"), nullable=True)
    image_url = Column(String(500), nullable=True)
    barcode = Column(String(100), nullable=True, index=True)
    sku = Column(String(100), nullable=True, index=True)
    is_active = Column(Boolean, default=True)
    is_available = Column(Boolean, default=True)  # Can be toggled by kitchen
    is_featured = Column(Boolean, default=False)
    preparation_time = Column(Integer, default=0)  # Minutes
    calories = Column(Integer, nullable=True)
    allergens = Column(JSON, default=[])  # List of allergen strings
    tags = Column(JSON, default=[])  # vegan, gluten-free, spicy, etc.
    printer_target = Column(String(20), default="kitchen")  # kitchen, bar, none
    tax_rate = Column(Float, nullable=True)  # Override restaurant default
    sort_order = Column(Integer, default=0)
    stock_tracking = Column(Boolean, default=False)
    current_stock = Column(Float, nullable=True)
    low_stock_alert = Column(Float, nullable=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), onupdate=func.now())

    # Relationships
    category = relationship("Category", back_populates="items")
    modifier_groups = relationship("ModifierGroup", back_populates="menu_item")
    recipe_items = relationship("RecipeItem", back_populates="menu_item")
    order_items = relationship("OrderItem", back_populates="menu_item")


class ModifierGroup(Base):
    __tablename__ = "modifier_groups"

    id = Column(Integer, primary_key=True, index=True)
    menu_item_id = Column(Integer, ForeignKey("menu_items.id"), nullable=False)
    name = Column(String(100), nullable=False)
    min_selections = Column(Integer, default=0)
    max_selections = Column(Integer, default=1)
    is_required = Column(Boolean, default=False)
    sort_order = Column(Integer, default=0)

    # Relationships
    menu_item = relationship("MenuItem", back_populates="modifier_groups")
    options = relationship("ModifierOption", back_populates="group")


class ModifierOption(Base):
    __tablename__ = "modifier_options"

    id = Column(Integer, primary_key=True, index=True)
    group_id = Column(Integer, ForeignKey("modifier_groups.id"), nullable=False)
    name = Column(String(100), nullable=False)
    price_adjustment = Column(Float, default=0.0)
    is_active = Column(Boolean, default=True)
    sort_order = Column(Integer, default=0)

    # Relationships
    group = relationship("ModifierGroup", back_populates="options")


class Section(Base):
    __tablename__ = "sections"

    id = Column(Integer, primary_key=True, index=True)
    name = Column(String(100), nullable=False)
    description = Column(Text, nullable=True)
    color = Column(String(10), nullable=True)
    sort_order = Column(Integer, default=0)
    is_active = Column(Boolean, default=True)

    tables = relationship("Table", back_populates="section")


class Table(Base):
    __tablename__ = "tables"

    id = Column(Integer, primary_key=True, index=True)
    number = Column(String(20), nullable=False)
    name = Column(String(100), nullable=True)
    section_id = Column(Integer, ForeignKey("sections.id"), nullable=True)
    capacity = Column(Integer, default=4)
    status = Column(Enum(TableStatus), default=TableStatus.FREE)
    pos_x = Column(Float, default=0.0)  # Floor plan position X
    pos_y = Column(Float, default=0.0)  # Floor plan position Y
    width = Column(Float, default=80.0)
    height = Column(Float, default=80.0)
    shape = Column(String(20), default="rectangle")  # rectangle, circle
    is_active = Column(Boolean, default=True)
    notes = Column(Text, nullable=True)
    qr_code_url = Column(String(500), nullable=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now())

    # Relationships
    section = relationship("Section", back_populates="tables")
    orders = relationship("Order", back_populates="table")
    reservations = relationship("Reservation", back_populates="table")


class Order(Base):
    __tablename__ = "orders"

    id = Column(Integer, primary_key=True, index=True)
    order_number = Column(String(20), unique=True, nullable=False, index=True)
    table_id = Column(Integer, ForeignKey("tables.id"), nullable=True)
    order_type = Column(Enum(OrderType), default=OrderType.DINE_IN)
    status = Column(Enum(OrderStatus), default=OrderStatus.DRAFT)
    guest_count = Column(Integer, default=1)
    waiter_id = Column(Integer, ForeignKey("users.id"), nullable=True)
    cashier_id = Column(Integer, ForeignKey("users.id"), nullable=True)

    # Financials
    subtotal = Column(Float, default=0.0)
    discount_amount = Column(Float, default=0.0)
    discount_percentage = Column(Float, default=0.0)
    discount_reason = Column(String(200), nullable=True)
    tax_amount = Column(Float, default=0.0)
    service_charge_amount = Column(Float, default=0.0)
    total_amount = Column(Float, default=0.0)
    paid_amount = Column(Float, default=0.0)
    change_amount = Column(Float, default=0.0)

    # Customer info (for takeaway/delivery)
    customer_name = Column(String(100), nullable=True)
    customer_phone = Column(String(20), nullable=True)
    customer_address = Column(Text, nullable=True)
    delivery_notes = Column(Text, nullable=True)

    # Order notes
    notes = Column(Text, nullable=True)
    kitchen_notes = Column(Text, nullable=True)

    # Timestamps
    opened_at = Column(DateTime(timezone=True), server_default=func.now())
    sent_at = Column(DateTime(timezone=True), nullable=True)
    first_item_ready_at = Column(DateTime(timezone=True), nullable=True)
    served_at = Column(DateTime(timezone=True), nullable=True)
    paid_at = Column(DateTime(timezone=True), nullable=True)
    closed_at = Column(DateTime(timezone=True), nullable=True)
    updated_at = Column(DateTime(timezone=True), onupdate=func.now())

    # Relationships
    table = relationship("Table", back_populates="orders")
    waiter = relationship("User", back_populates="orders", foreign_keys=[waiter_id])
    items = relationship("OrderItem", back_populates="order", cascade="all, delete-orphan")
    payments = relationship("Payment", back_populates="order")


class OrderItem(Base):
    __tablename__ = "order_items"

    id = Column(Integer, primary_key=True, index=True)
    order_id = Column(Integer, ForeignKey("orders.id"), nullable=False)
    menu_item_id = Column(Integer, ForeignKey("menu_items.id"), nullable=False)
    quantity = Column(Integer, default=1)
    unit_price = Column(Float, nullable=False)
    total_price = Column(Float, nullable=False)
    status = Column(Enum(ItemStatus), default=ItemStatus.PENDING)
    notes = Column(Text, nullable=True)
    modifiers = Column(JSON, default=[])  # [{group: ..., option: ..., price: ...}]
    modifier_total = Column(Float, default=0.0)
    seat_number = Column(Integer, nullable=True)
    sent_at = Column(DateTime(timezone=True), nullable=True)
    started_at = Column(DateTime(timezone=True), nullable=True)
    completed_at = Column(DateTime(timezone=True), nullable=True)
    course = Column(Integer, default=1)  # For course-by-course serving
    is_comp = Column(Boolean, default=False)  # Complimentary
    void_reason = Column(Text, nullable=True)
    added_by = Column(Integer, ForeignKey("users.id"), nullable=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now())

    # Relationships
    order = relationship("Order", back_populates="items")
    menu_item = relationship("MenuItem", back_populates="order_items")


class Payment(Base):
    __tablename__ = "payments"

    id = Column(Integer, primary_key=True, index=True)
    order_id = Column(Integer, ForeignKey("orders.id"), nullable=False)
    method = Column(Enum(PaymentMethod), nullable=False)
    amount = Column(Float, nullable=False)
    status = Column(Enum(PaymentStatus), default=PaymentStatus.PENDING)
    reference = Column(String(100), nullable=True)  # Card transaction ref
    notes = Column(Text, nullable=True)
    processed_by = Column(Integer, ForeignKey("users.id"), nullable=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now())

    # Relationships
    order = relationship("Order", back_populates="payments")


class Ingredient(Base):
    __tablename__ = "ingredients"

    id = Column(Integer, primary_key=True, index=True)
    name = Column(String(200), nullable=False)
    unit = Column(String(50), nullable=False)  # kg, g, l, ml, pcs
    current_stock = Column(Float, default=0.0)
    minimum_stock = Column(Float, default=0.0)
    reorder_point = Column(Float, default=0.0)
    cost_per_unit = Column(Float, default=0.0)
    supplier = Column(String(200), nullable=True)
    storage_location = Column(String(100), nullable=True)
    is_active = Column(Boolean, default=True)
    notes = Column(Text, nullable=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), onupdate=func.now())

    # Relationships
    recipe_items = relationship("RecipeItem", back_populates="ingredient")
    stock_movements = relationship("StockMovement", back_populates="ingredient")


class RecipeItem(Base):
    __tablename__ = "recipe_items"

    id = Column(Integer, primary_key=True, index=True)
    menu_item_id = Column(Integer, ForeignKey("menu_items.id"), nullable=False)
    ingredient_id = Column(Integer, ForeignKey("ingredients.id"), nullable=False)
    quantity = Column(Float, nullable=False)
    unit = Column(String(50), nullable=False)
    notes = Column(String(200), nullable=True)

    # Relationships
    menu_item = relationship("MenuItem", back_populates="recipe_items")
    ingredient = relationship("Ingredient", back_populates="recipe_items")


class StockMovement(Base):
    __tablename__ = "stock_movements"

    id = Column(Integer, primary_key=True, index=True)
    ingredient_id = Column(Integer, ForeignKey("ingredients.id"), nullable=False)
    movement_type = Column(Enum(StockMovementType), nullable=False)
    quantity = Column(Float, nullable=False)  # Positive = in, negative = out
    unit_cost = Column(Float, nullable=True)
    total_cost = Column(Float, nullable=True)
    reference = Column(String(100), nullable=True)  # Order number, PO number, etc.
    notes = Column(Text, nullable=True)
    created_by = Column(Integer, ForeignKey("users.id"), nullable=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now())

    ingredient = relationship("Ingredient", back_populates="stock_movements")


class Printer(Base):
    __tablename__ = "printers"

    id = Column(Integer, primary_key=True, index=True)
    name = Column(String(100), nullable=False)
    type = Column(Enum(PrinterType), nullable=False)
    ip_address = Column(String(50), nullable=False)
    port = Column(Integer, default=9100)
    is_active = Column(Boolean, default=True)
    is_default = Column(Boolean, default=False)
    paper_width = Column(Integer, default=80)  # mm
    copies = Column(Integer, default=1)
    notes = Column(Text, nullable=True)
    last_test_at = Column(DateTime(timezone=True), nullable=True)
    last_test_success = Column(Boolean, nullable=True)


class Reservation(Base):
    __tablename__ = "reservations"

    id = Column(Integer, primary_key=True, index=True)
    table_id = Column(Integer, ForeignKey("tables.id"), nullable=True)
    customer_name = Column(String(100), nullable=False)
    customer_phone = Column(String(20), nullable=False)
    customer_email = Column(String(100), nullable=True)
    guest_count = Column(Integer, nullable=False)
    reservation_date = Column(Date, nullable=False)
    reservation_time = Column(Time, nullable=False)
    duration_minutes = Column(Integer, default=90)
    status = Column(Enum(ReservationStatus), default=ReservationStatus.CONFIRMED)
    notes = Column(Text, nullable=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    created_by = Column(Integer, ForeignKey("users.id"), nullable=True)

    table = relationship("Table", back_populates="reservations")


class ShiftLog(Base):
    __tablename__ = "shift_logs"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    clock_in = Column(DateTime(timezone=True), nullable=False)
    clock_out = Column(DateTime(timezone=True), nullable=True)
    opening_balance = Column(Float, nullable=True)
    closing_balance = Column(Float, nullable=True)
    expected_balance = Column(Float, nullable=True)
    notes = Column(Text, nullable=True)

    user = relationship("User", back_populates="shift_logs")


class CashMovement(Base):
    __tablename__ = "cash_movements"

    id = Column(Integer, primary_key=True, index=True)
    shift_log_id = Column(Integer, ForeignKey("shift_logs.id"), nullable=True)
    movement_type = Column(String(20), nullable=False)  # in, out
    amount = Column(Float, nullable=False)
    reason = Column(String(200), nullable=False)
    created_by = Column(Integer, ForeignKey("users.id"), nullable=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now())


class ActivityLog(Base):
    __tablename__ = "activity_logs"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=True)
    action = Column(String(100), nullable=False)
    entity_type = Column(String(50), nullable=True)
    entity_id = Column(Integer, nullable=True)
    details = Column(JSON, nullable=True)
    ip_address = Column(String(50), nullable=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now())

    user = relationship("User", back_populates="activity_logs")


class Discount(Base):
    __tablename__ = "discounts"

    id = Column(Integer, primary_key=True, index=True)
    name = Column(String(100), nullable=False)
    code = Column(String(50), nullable=True, unique=True)
    discount_type = Column(String(20), nullable=False)  # percentage, fixed
    value = Column(Float, nullable=False)
    min_order_amount = Column(Float, nullable=True)
    max_uses = Column(Integer, nullable=True)
    used_count = Column(Integer, default=0)
    is_active = Column(Boolean, default=True)
    requires_manager = Column(Boolean, default=False)
    valid_from = Column(DateTime(timezone=True), nullable=True)
    valid_until = Column(DateTime(timezone=True), nullable=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now())


class DailyReport(Base):
    __tablename__ = "daily_reports"

    id = Column(Integer, primary_key=True, index=True)
    report_date = Column(Date, nullable=False, unique=True)
    total_orders = Column(Integer, default=0)
    total_covers = Column(Integer, default=0)
    total_revenue = Column(Float, default=0.0)
    total_tax = Column(Float, default=0.0)
    total_service_charge = Column(Float, default=0.0)
    total_discounts = Column(Float, default=0.0)
    cash_revenue = Column(Float, default=0.0)
    card_revenue = Column(Float, default=0.0)
    mobile_revenue = Column(Float, default=0.0)
    void_amount = Column(Float, default=0.0)
    comp_amount = Column(Float, default=0.0)
    avg_order_value = Column(Float, default=0.0)
    peak_hour = Column(Integer, nullable=True)
    generated_at = Column(DateTime(timezone=True), server_default=func.now())
    generated_by = Column(Integer, ForeignKey("users.id"), nullable=True)
    data_snapshot = Column(JSON, nullable=True)  # Full data snapshot
