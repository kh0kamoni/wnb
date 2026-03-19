# 🍃 Wood Natural Bar — Restaurant Management System

A complete, production-ready, **offline-first** restaurant POS and management system built with **FastAPI (Python)** backend and **Flutter** frontend.

---

## 📋 Feature Overview

### 🏪 Core POS
- Visual floor plan with drag-and-drop table management
- Real-time table status (Free / Occupied / Reserved / Cleaning)
- Full menu with categories, images, modifiers, and allergens
- Order management: create, modify, send to kitchen, pay
- Split billing & split payment (cash, card, mobile, complimentary)
- Discounts: percentage, fixed amount, coupon codes
- Void items with manager approval
- Course-by-course ordering (Course 1, 2, 3...)
- Seat-based ordering for large tables

### 👨‍🍳 Kitchen Display System (KDS)
- Real-time order stream via WebSocket
- Audio alerts for new orders
- Item-level progress tracking (Pending → In Progress → Ready)
- Timer showing elapsed time per order
- Urgent highlighting after 15 minutes
- BUMP to complete entire order
- Sold-out toggle per item

### 💰 Cashier
- Quick over-the-counter sales
- Takeaway & delivery orders
- Cash drawer integration
- Change calculation
- Receipt printing (ESC/POS)

### 👑 Admin Panel
- User & role management (Admin, Manager, Waiter, Cashier, Kitchen, Bar)
- PIN-based quick login for POS terminals
- Menu builder with image upload
- Category management with icons & colors
- Modifier groups (required/optional)
- Floor plan visual editor
- Inventory & ingredient tracking with recipe costing
- Low stock alerts
- Reservation management with calendar
- End-of-day reports (X/Z reports)
- Sales analytics: revenue, top items, hourly breakdown, staff performance
- Activity log for audit trail
- Shift management with cash counts

### 🎨 Customization
- Upload custom restaurant logo
- Set restaurant name, tagline, address, phone
- Choose primary & accent brand colors (live preview)
- Configure currency symbol
- Set tax rate & service charge
- All branding pulled from server — update once, reflects everywhere

### 🖨️ Hardware Integration
- ESC/POS printing over TCP/IP
- Multiple printer support (receipt, kitchen, bar)
- Cash drawer trigger via receipt printer
- Kitchen label printing

### 🌐 Offline-First Architecture
- mDNS (Bonjour/Avahi) for automatic server discovery
- Local Flutter caching with Hive
- WebSocket reconnect with exponential backoff
- Graceful degradation when server unreachable

---

## 🚀 Quick Start

### Backend Setup

**Option A: Docker (Recommended)**
```bash
cd backend
cp .env.example .env
# Edit .env with your settings
docker-compose up -d
```

**Option B: Manual**
```bash
cd backend
python -m venv venv
source venv/bin/activate        # Windows: venv\Scripts\activate
pip install -r requirements.txt
cp .env.example .env
# Edit .env: set DATABASE_URL to your PostgreSQL connection

# Run migrations
alembic upgrade head

# Start server
uvicorn main:app --host 0.0.0.0 --port 8000 --reload
```

**Default Admin Credentials:**
- Username: `admin`
- Password: `Admin@1234`

- PIN: `0000`

> ⚠️ **Change these immediately after first login!**

**API Documentation:** `http://server-ip:8000/api/docs`

---

### Flutter App Setup

```bash
cd frontend/wood_bar_app
flutter pub get
flutter run
```

**First launch:** Enter your server IP (e.g., `http://192.168.1.100:8000`)

**Build for Android tablet:**
```bash
flutter build apk --release
# or for specific ABI:
flutter build apk --target-platform android-arm64 --release
```

---

## 🏗️ Architecture

```
wood_natural_bar/
├── backend/                    # FastAPI Python backend
│   ├── app/
│   │   ├── api/v1/endpoints/   # All REST API routes
│   │   │   ├── auth.py         # Login, PIN, token refresh
│   │   │   ├── users.py        # Staff management
│   │   │   ├── menu.py         # Categories, items, modifiers
│   │   │   ├── tables.py       # Tables, sections, floor plan
│   │   │   ├── orders.py       # Order CRUD, payments
│   │   │   └── misc.py         # Inventory, reports, printers,
│   │   │                       # settings, discounts, shifts, WS
│   │   ├── core/
│   │   │   ├── config.py       # Settings from .env
│   │   │   ├── security.py     # JWT, password hashing
│   │   │   ├── deps.py         # Auth dependencies
│   │   │   └── websocket.py    # WebSocket connection manager
│   │   ├── db/database.py      # SQLAlchemy engine + session
│   │   ├── models/models.py    # All database models (ORM)
│   │   ├── schemas/schemas.py  # Pydantic request/response schemas
│   │   ├── services/
│   │   │   ├── order_service.py   # Business logic: create, pay, split
│   │   │   ├── print_service.py   # ESC/POS printer driver
│   │   │   └── report_service.py  # Analytics & reporting
│   │   └── utils/mdns.py       # Local network discovery
│   ├── main.py                 # FastAPI app entry point
│   ├── requirements.txt
│   ├── Dockerfile
│   └── docker-compose.yml
│
└── frontend/wood_bar_app/      # Flutter multi-platform app
    └── lib/
        ├── main.dart           # App entry point
        ├── core/
        │   ├── constants/      # App-wide constants
        │   ├── theme/          # Material theme (light/dark/kitchen)
        │   └── network/        # GoRouter with role-based navigation
        ├── data/
        │   ├── models/         # Dart model classes
        │   ├── datasources/    # API service + WebSocket service
        │   └── repositories/   # (extend here for offline caching)
        └── presentation/
            ├── providers/      # Riverpod state management
            └── screens/
                ├── auth/       # Login, PIN login, server setup
                ├── home/       # Role-based home screen
                ├── tables/     # Floor plan, table detail, editor
                ├── orders/     # New order, order detail, payment
                ├── kitchen/    # KDS (Kitchen Display System)
                ├── cashier/    # Cashier station
                ├── menu/       # Menu management
                ├── admin/      # Dashboard, users, inventory,
                │               # branding, printers
                ├── reports/    # Sales analytics
                ├── reservations/ # Booking management
                └── settings/   # App settings
```

---

## 🔐 User Roles & Permissions

| Role | Access |
|------|--------|
| **Admin** | Full access to everything |
| **Manager** | All except system config |
| **Waiter** | Floor plan, orders, their own tables |
| **Cashier** | Payment processing, takeaway orders |
| **Kitchen** | Kitchen display, item status updates |
| **Bar** | Bar display (filtered orders) |

---

## 🌐 WebSocket Events

| Event | Direction | Description |
|-------|-----------|-------------|
| `new_order` | Server → Kitchen/Bar | New order sent to kitchen |
| `order_update` | Server → Waiter/Cashier | Order status changed |
| `item_ready` | Server → Waiter | Single item marked ready |
| `order_complete` | Server → Waiter | All items ready |
| `table_status` | Server → All | Table status changed |
| `payment_complete` | Server → All | Order paid |
| `stock_alert` | Server → Kitchen/Admin | Low stock warning |
| `void_request` | Server → Admin | Item void requested |

---

## 🖨️ Printer Setup

1. Connect thermal printer to your local network
2. Note the printer's IP address
3. Go to **Admin → Printers → Add Printer**
4. Enter IP, port (usually 9100), and type (Receipt/Kitchen/Bar)
5. Use "Test Print" to verify connection

**Supported printers:** Any ESC/POS compatible network printer (Epson TM series, Star, etc.)

---

## 🎨 Adding Your Branding

1. Log in as Admin
2. Go to **Admin → Branding & Settings**
3. Upload your logo (PNG, 512×512 recommended)
4. Set restaurant name, tagline, address, phone
5. Choose your brand colors with the color picker
6. Set your currency and tax rates
7. Click **Save** — all devices update automatically

---

## 📱 Recommended Hardware

| Device | Use |
|--------|-----|
| Windows/Linux PC or Raspberry Pi 5 | Backend server |
| Android 10" tablets | Waiter POS, Cashier |
| Large monitor (24"+ with Android box) | Kitchen Display |
| Epson TM-T88VI / Star TSP143 | Receipt/Kitchen printer |
| Standard cash drawer | Connected via receipt printer |

---

## 🔧 Extending the System

The codebase is designed for easy extension:

- **New API endpoint:** Add a router in `app/api/v1/endpoints/`, register in `main.py`
- **New model:** Add to `app/models/models.py`, create Alembic migration
- **New Flutter screen:** Create in `presentation/screens/`, add route in `core/network/app_router.dart`
- **New role:** Add to `UserRole` enum, update `require_roles()` in deps
- **New payment method:** Add to `PaymentMethod` enum, update payment screen
- **New report:** Add function to `report_service.py`, add endpoint in `misc.py`

---

## 📄 License

MIT License — Free to use and modify for your restaurant.

---

*Built for Wood Natural Bar — Fresh & Natural 🍃*
