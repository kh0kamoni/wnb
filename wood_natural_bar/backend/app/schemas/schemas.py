from pydantic import BaseModel, EmailStr, validator, Field
from typing import Optional, List, Any, Dict
from datetime import datetime, date, time
from app.models.models import (
    UserRole, TableStatus, OrderStatus, OrderType,
    ItemStatus, PaymentMethod, PaymentStatus, PrinterType,
    StockMovementType, ReservationStatus
)


# ─────────────── AUTH ───────────────

class Token(BaseModel):
    access_token: str
    refresh_token: str
    token_type: str = "bearer"
    user: "UserOut"


class TokenRefresh(BaseModel):
    refresh_token: str


class LoginRequest(BaseModel):
    username: str
    password: str


class PinLoginRequest(BaseModel):
    pin_code: str


# ─────────────── USER ───────────────

class UserBase(BaseModel):
    username: str
    full_name: str
    email: Optional[str] = None
    role: UserRole
    phone: Optional[str] = None
    notes: Optional[str] = None
    permissions: Optional[Dict] = {}


class UserCreate(UserBase):
    password: str
    pin_code: Optional[str] = None


class UserUpdate(BaseModel):
    full_name: Optional[str] = None
    email: Optional[str] = None
    role: Optional[UserRole] = None
    phone: Optional[str] = None
    notes: Optional[str] = None
    permissions: Optional[Dict] = None
    is_active: Optional[bool] = None
    pin_code: Optional[str] = None


class UserPasswordChange(BaseModel):
    current_password: str
    new_password: str


class UserOut(BaseModel):
    id: int
    username: str
    full_name: str
    email: Optional[str] = None
    role: UserRole
    phone: Optional[str] = None
    is_active: bool
    avatar_url: Optional[str] = None
    permissions: Optional[Dict] = {}
    last_login: Optional[datetime] = None
    created_at: datetime

    class Config:
        from_attributes = True


# ─────────────── RESTAURANT SETTINGS ───────────────

class SettingUpdate(BaseModel):
    value: Any
    description: Optional[str] = None


class SettingOut(BaseModel):
    key: str
    value: Any
    value_type: str
    category: str
    description: Optional[str] = None

    class Config:
        from_attributes = True


class BrandingUpdate(BaseModel):
    restaurant_name: Optional[str] = None
    tagline: Optional[str] = None
    address: Optional[str] = None
    phone: Optional[str] = None
    currency: Optional[str] = None
    currency_symbol: Optional[str] = None
    timezone: Optional[str] = None
    tax_rate: Optional[float] = None
    service_charge_rate: Optional[float] = None
    wifi_ssid: Optional[str] = None
    wifi_password: Optional[str] = None
    opening_hours: Optional[Dict] = None


# ─────────────── CATEGORY ───────────────

class CategoryBase(BaseModel):
    name: str
    description: Optional[str] = None
    color: Optional[str] = None
    icon: Optional[str] = None
    sort_order: int = 0
    is_active: bool = True
    parent_id: Optional[int] = None


class CategoryCreate(CategoryBase):
    pass


class CategoryUpdate(BaseModel):
    name: Optional[str] = None
    description: Optional[str] = None
    color: Optional[str] = None
    icon: Optional[str] = None
    sort_order: Optional[int] = None
    is_active: Optional[bool] = None


class CategoryOut(CategoryBase):
    id: int
    image_url: Optional[str] = None
    created_at: datetime

    class Config:
        from_attributes = True


# ─────────────── MODIFIER ───────────────

class ModifierOptionBase(BaseModel):
    name: str
    price_adjustment: float = 0.0
    is_active: bool = True
    sort_order: int = 0


class ModifierOptionCreate(ModifierOptionBase):
    pass


class ModifierOptionOut(ModifierOptionBase):
    id: int

    class Config:
        from_attributes = True


class ModifierGroupBase(BaseModel):
    name: str
    min_selections: int = 0
    max_selections: int = 1
    is_required: bool = False
    sort_order: int = 0


class ModifierGroupCreate(ModifierGroupBase):
    options: List[ModifierOptionCreate] = []


class ModifierGroupOut(ModifierGroupBase):
    id: int
    menu_item_id: int
    options: List[ModifierOptionOut] = []

    class Config:
        from_attributes = True


# ─────────────── MENU ITEM ───────────────

class MenuItemBase(BaseModel):
    name: str
    description: Optional[str] = None
    price: float
    cost_price: Optional[float] = None
    category_id: Optional[int] = None
    barcode: Optional[str] = None
    sku: Optional[str] = None
    is_active: bool = True
    is_featured: bool = False
    preparation_time: int = 0
    calories: Optional[int] = None
    allergens: List[str] = []
    tags: List[str] = []
    printer_target: str = "kitchen"
    tax_rate: Optional[float] = None
    sort_order: int = 0
    stock_tracking: bool = False


class MenuItemCreate(MenuItemBase):
    modifier_groups: List[ModifierGroupCreate] = []


class MenuItemUpdate(BaseModel):
    name: Optional[str] = None
    description: Optional[str] = None
    price: Optional[float] = None
    cost_price: Optional[float] = None
    category_id: Optional[int] = None
    is_active: Optional[bool] = None
    is_available: Optional[bool] = None
    is_featured: Optional[bool] = None
    preparation_time: Optional[int] = None
    calories: Optional[int] = None
    allergens: Optional[List[str]] = None
    tags: Optional[List[str]] = None
    printer_target: Optional[str] = None
    tax_rate: Optional[float] = None
    sort_order: Optional[int] = None
    stock_tracking: Optional[bool] = None
    current_stock: Optional[float] = None
    low_stock_alert: Optional[float] = None


class MenuItemOut(MenuItemBase):
    id: int
    is_available: bool
    image_url: Optional[str] = None
    current_stock: Optional[float] = None
    low_stock_alert: Optional[float] = None
    modifier_groups: List[ModifierGroupOut] = []
    category: Optional[CategoryOut] = None

    class Config:
        from_attributes = True


# ─────────────── SECTION & TABLE ───────────────

class SectionBase(BaseModel):
    name: str
    description: Optional[str] = None
    color: Optional[str] = None
    sort_order: int = 0
    is_active: bool = True


class SectionCreate(SectionBase):
    pass


class SectionOut(SectionBase):
    id: int

    class Config:
        from_attributes = True


class TableBase(BaseModel):
    number: str
    name: Optional[str] = None
    section_id: Optional[int] = None
    capacity: int = 4
    pos_x: float = 0.0
    pos_y: float = 0.0
    width: float = 80.0
    height: float = 80.0
    shape: str = "rectangle"
    is_active: bool = True
    notes: Optional[str] = None


class TableCreate(TableBase):
    pass


class TableUpdate(BaseModel):
    number: Optional[str] = None
    name: Optional[str] = None
    section_id: Optional[int] = None
    capacity: Optional[int] = None
    status: Optional[TableStatus] = None
    pos_x: Optional[float] = None
    pos_y: Optional[float] = None
    width: Optional[float] = None
    height: Optional[float] = None
    shape: Optional[str] = None
    is_active: Optional[bool] = None
    notes: Optional[str] = None


class TableOut(TableBase):
    id: int
    status: TableStatus
    qr_code_url: Optional[str] = None
    section: Optional[SectionOut] = None
    active_order_id: Optional[int] = None  # Populated by service

    class Config:
        from_attributes = True


class FloorPlanUpdate(BaseModel):
    tables: List[Dict]  # [{id, pos_x, pos_y, width, height}]


# ─────────────── ORDER ───────────────

class OrderItemModifier(BaseModel):
    group_id: int
    group_name: str
    option_id: int
    option_name: str
    price_adjustment: float


class OrderItemCreate(BaseModel):
    menu_item_id: int
    quantity: int = 1
    notes: Optional[str] = None
    modifiers: List[OrderItemModifier] = []
    seat_number: Optional[int] = None
    course: int = 1


class OrderItemUpdate(BaseModel):
    quantity: Optional[int] = None
    notes: Optional[str] = None
    status: Optional[ItemStatus] = None
    void_reason: Optional[str] = None


class OrderItemOut(BaseModel):
    id: int
    menu_item_id: int
    quantity: int
    unit_price: float
    total_price: float
    modifier_total: float
    status: ItemStatus
    notes: Optional[str] = None
    modifiers: List[Dict] = []
    seat_number: Optional[int] = None
    course: int
    is_comp: bool
    sent_at: Optional[datetime] = None
    started_at: Optional[datetime] = None
    completed_at: Optional[datetime] = None
    menu_item: Optional[MenuItemOut] = None

    class Config:
        from_attributes = True


class OrderCreate(BaseModel):
    table_id: Optional[int] = None
    order_type: OrderType = OrderType.DINE_IN
    guest_count: int = 1
    notes: Optional[str] = None
    customer_name: Optional[str] = None
    customer_phone: Optional[str] = None
    customer_address: Optional[str] = None
    items: List[OrderItemCreate] = []


class OrderUpdate(BaseModel):
    status: Optional[OrderStatus] = None
    guest_count: Optional[int] = None
    notes: Optional[str] = None
    kitchen_notes: Optional[str] = None
    customer_name: Optional[str] = None
    customer_phone: Optional[str] = None
    customer_address: Optional[str] = None
    discount_percentage: Optional[float] = None
    discount_amount: Optional[float] = None
    discount_reason: Optional[str] = None


class OrderOut(BaseModel):
    id: int
    order_number: str
    table_id: Optional[int] = None
    order_type: OrderType
    status: OrderStatus
    guest_count: int
    waiter_id: Optional[int] = None
    subtotal: float
    discount_amount: float
    tax_amount: float
    service_charge_amount: float
    total_amount: float
    paid_amount: float
    change_amount: float
    notes: Optional[str] = None
    kitchen_notes: Optional[str] = None
    customer_name: Optional[str] = None
    customer_phone: Optional[str] = None
    items: List[OrderItemOut] = []
    payments: List["PaymentOut"] = []
    table: Optional[TableOut] = None
    waiter: Optional[UserOut] = None
    opened_at: datetime
    sent_at: Optional[datetime] = None
    paid_at: Optional[datetime] = None

    class Config:
        from_attributes = True


# ─────────────── PAYMENT ───────────────

class PaymentCreate(BaseModel):
    order_id: int
    method: PaymentMethod
    amount: float
    reference: Optional[str] = None
    notes: Optional[str] = None


class SplitPaymentCreate(BaseModel):
    order_id: int
    payments: List[PaymentCreate]


class PaymentOut(BaseModel):
    id: int
    order_id: int
    method: PaymentMethod
    amount: float
    status: PaymentStatus
    reference: Optional[str] = None
    created_at: datetime

    class Config:
        from_attributes = True


# ─────────────── INGREDIENT / INVENTORY ───────────────

class IngredientBase(BaseModel):
    name: str
    unit: str
    minimum_stock: float = 0.0
    reorder_point: float = 0.0
    cost_per_unit: float = 0.0
    supplier: Optional[str] = None
    storage_location: Optional[str] = None
    notes: Optional[str] = None


class IngredientCreate(IngredientBase):
    current_stock: float = 0.0


class IngredientUpdate(BaseModel):
    name: Optional[str] = None
    unit: Optional[str] = None
    minimum_stock: Optional[float] = None
    reorder_point: Optional[float] = None
    cost_per_unit: Optional[float] = None
    supplier: Optional[str] = None
    storage_location: Optional[str] = None
    is_active: Optional[bool] = None
    notes: Optional[str] = None


class IngredientOut(IngredientBase):
    id: int
    current_stock: float
    is_active: bool
    created_at: datetime

    class Config:
        from_attributes = True


class StockAdjustment(BaseModel):
    ingredient_id: int
    quantity: float
    movement_type: StockMovementType
    unit_cost: Optional[float] = None
    reference: Optional[str] = None
    notes: Optional[str] = None


# ─────────────── PRINTER ───────────────

class PrinterBase(BaseModel):
    name: str
    type: PrinterType
    ip_address: str
    port: int = 9100
    is_active: bool = True
    is_default: bool = False
    paper_width: int = 80
    copies: int = 1
    notes: Optional[str] = None


class PrinterCreate(PrinterBase):
    pass


class PrinterUpdate(BaseModel):
    name: Optional[str] = None
    ip_address: Optional[str] = None
    port: Optional[int] = None
    is_active: Optional[bool] = None
    is_default: Optional[bool] = None
    paper_width: Optional[int] = None
    copies: Optional[int] = None


class PrinterOut(PrinterBase):
    id: int
    last_test_at: Optional[datetime] = None
    last_test_success: Optional[bool] = None

    class Config:
        from_attributes = True


class PrintRequest(BaseModel):
    order_id: int
    printer_id: Optional[int] = None
    print_type: str = "receipt"  # receipt, kitchen, bar, label


# ─────────────── RESERVATION ───────────────

class ReservationCreate(BaseModel):
    table_id: Optional[int] = None
    customer_name: str
    customer_phone: str
    customer_email: Optional[str] = None
    guest_count: int
    reservation_date: date
    reservation_time: time
    duration_minutes: int = 90
    notes: Optional[str] = None


class ReservationUpdate(BaseModel):
    table_id: Optional[int] = None
    customer_name: Optional[str] = None
    customer_phone: Optional[str] = None
    guest_count: Optional[int] = None
    reservation_date: Optional[date] = None
    reservation_time: Optional[time] = None
    status: Optional[ReservationStatus] = None
    notes: Optional[str] = None


class ReservationOut(BaseModel):
    id: int
    table_id: Optional[int] = None
    customer_name: str
    customer_phone: str
    customer_email: Optional[str] = None
    guest_count: int
    reservation_date: date
    reservation_time: time
    duration_minutes: int
    status: ReservationStatus
    notes: Optional[str] = None
    created_at: datetime

    class Config:
        from_attributes = True


# ─────────────── SHIFT / CASH ───────────────

class ShiftStart(BaseModel):
    opening_balance: float = 0.0


class ShiftEnd(BaseModel):
    closing_balance: float
    notes: Optional[str] = None


class CashMovementCreate(BaseModel):
    movement_type: str  # in, out
    amount: float
    reason: str


# ─────────────── REPORTS ───────────────

class ReportFilter(BaseModel):
    start_date: date
    end_date: date
    waiter_id: Optional[int] = None
    order_type: Optional[OrderType] = None


class SalesReportOut(BaseModel):
    start_date: date
    end_date: date
    total_orders: int
    total_revenue: float
    total_tax: float
    total_discounts: float
    avg_order_value: float
    top_items: List[Dict]
    revenue_by_day: List[Dict]
    revenue_by_category: List[Dict]
    payment_breakdown: Dict


class EndOfDayReport(BaseModel):
    report_date: date
    total_orders: int
    total_revenue: float
    total_tax: float
    total_service_charge: float
    total_discounts: float
    cash_revenue: float
    card_revenue: float
    mobile_revenue: float
    void_amount: float
    comp_amount: float
    avg_order_value: float


# ─────────────── DISCOUNT ───────────────

class DiscountCreate(BaseModel):
    name: str
    code: Optional[str] = None
    discount_type: str  # percentage, fixed
    value: float
    min_order_amount: Optional[float] = None
    max_uses: Optional[int] = None
    is_active: bool = True
    requires_manager: bool = False


class DiscountOut(DiscountCreate):
    id: int
    used_count: int
    created_at: datetime

    class Config:
        from_attributes = True


class ApplyDiscount(BaseModel):
    order_id: int
    discount_id: Optional[int] = None
    manual_discount_percentage: Optional[float] = None
    manual_discount_amount: Optional[float] = None
    reason: str


# ─────────────── WEBSOCKET ───────────────

class WSMessage(BaseModel):
    type: str
    data: Any


# ─────────────── DASHBOARD ───────────────

class DashboardStats(BaseModel):
    today_revenue: float
    today_orders: int
    today_covers: int
    active_tables: int
    free_tables: int
    pending_kitchen_items: int
    low_stock_alerts: int
    open_reservations: int


# Update forward references
OrderOut.model_rebuild()
Token.model_rebuild()
