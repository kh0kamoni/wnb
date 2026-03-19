from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from fastapi.responses import JSONResponse
from contextlib import asynccontextmanager
from pathlib import Path
import logging

from app.core.config import settings
from app.db.database import engine, Base
from app.api.v1.endpoints.auth import router as auth_router
from app.api.v1.endpoints.users import router as users_router
from app.api.v1.endpoints.menu import router as menu_router
from app.api.v1.endpoints.tables import router as tables_router
from app.api.v1.endpoints.orders import router as orders_router
from app.api.v1.endpoints.misc import (
    inventory_router, printers_router, reservations_router,
    reports_router, settings_router, discounts_router,
    shift_router, ws_router
)

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Startup and shutdown events."""
    logger.info(f"🍃 Starting {settings.RESTAURANT_NAME} POS System...")

    # Create DB tables
    Base.metadata.create_all(bind=engine)
    logger.info("✅ Database tables created/verified")

    # Seed default data
    await seed_defaults()
    logger.info("✅ Default data seeded")

    # Start mDNS service discovery
    try:
        from app.utils.mdns import start_mdns
        start_mdns()
        logger.info(f"✅ mDNS started: {settings.MDNS_HOSTNAME}.local")
    except Exception as e:
        logger.warning(f"⚠️  mDNS not available: {e}")

    yield

    logger.info("👋 Shutting down POS System...")


async def seed_defaults():
    """Seed the database with default admin user and settings if empty."""
    from app.db.database import SessionLocal
    from app.models.models import User, UserRole, RestaurantSettings
    from app.core.security import get_password_hash

    db = SessionLocal()
    try:
        # Create default admin if no users exist
        if not db.query(User).first():
            admin = User(
                username="admin",
                full_name="System Admin",
                email="admin@woodnaturalbar.com",
                hashed_password=get_password_hash("Admin@1234"),
                role=UserRole.ADMIN,
                pin_code="0000",
                is_active=True,
            )
            db.add(admin)
            logger.info("✅ Default admin created: username=admin, password=Admin@1234")

        # Seed public settings
        default_settings = [
            ("restaurant_name", settings.RESTAURANT_NAME, "string", "branding", True),
            ("tagline", settings.RESTAURANT_TAGLINE, "string", "branding", True),
            ("address", settings.RESTAURANT_ADDRESS, "string", "branding", True),
            ("phone", settings.RESTAURANT_PHONE, "string", "branding", True),
            ("currency", settings.RESTAURANT_CURRENCY, "string", "branding", True),
            ("currency_symbol", settings.RESTAURANT_CURRENCY_SYMBOL, "string", "branding", True),
            ("timezone", settings.RESTAURANT_TIMEZONE, "string", "branding", True),
            ("tax_rate", str(settings.RESTAURANT_TAX_RATE), "float", "financial", False),
            ("service_charge_rate", str(settings.RESTAURANT_SERVICE_CHARGE), "float", "financial", False),
            ("logo_url", "/static/branding/logo.png", "string", "branding", True),
            ("primary_color", "#2E7D32", "string", "branding", True),
            ("accent_color", "#FF6F00", "string", "branding", True),
            ("receipt_footer", "Thank you for dining with us!", "string", "printing", False),
            ("allow_takeaway", "true", "bool", "ordering", False),
            ("allow_delivery", "true", "bool", "ordering", False),
            ("require_table_guest_count", "true", "bool", "ordering", False),
        ]

        for key, value, vtype, category, is_public in default_settings:
            if not db.query(RestaurantSettings).filter(RestaurantSettings.key == key).first():
                db.add(RestaurantSettings(
                    key=key, value=value, value_type=vtype,
                    category=category, is_public=is_public
                ))

        db.commit()
    finally:
        db.close()


app = FastAPI(
    title=f"{settings.RESTAURANT_NAME} POS API",
    description="Restaurant Management System API - Wood Natural Bar",
    version=settings.APP_VERSION,
    lifespan=lifespan,
    docs_url="/api/docs",
    redoc_url="/api/redoc",
)

# CORS — allow all origins on local network
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Static files
Path(settings.UPLOAD_DIR).mkdir(parents=True, exist_ok=True)
Path(settings.STATIC_DIR).mkdir(parents=True, exist_ok=True)
app.mount("/uploads", StaticFiles(directory=settings.UPLOAD_DIR), name="uploads")
app.mount("/static", StaticFiles(directory=settings.STATIC_DIR), name="static")

# API Routes
PREFIX = "/api/v1"
app.include_router(auth_router, prefix=PREFIX)
app.include_router(users_router, prefix=PREFIX)
app.include_router(menu_router, prefix=PREFIX)
app.include_router(tables_router, prefix=PREFIX)
app.include_router(orders_router, prefix=PREFIX)
app.include_router(inventory_router, prefix=PREFIX)
app.include_router(printers_router, prefix=PREFIX)
app.include_router(reservations_router, prefix=PREFIX)
app.include_router(reports_router, prefix=PREFIX)
app.include_router(settings_router, prefix=PREFIX)
app.include_router(discounts_router, prefix=PREFIX)
app.include_router(shift_router, prefix=PREFIX)
app.include_router(ws_router)


@app.get("/")
def root():
    return {
        "restaurant": settings.RESTAURANT_NAME,
        "system": "POS Management System",
        "version": settings.APP_VERSION,
        "status": "running",
        "docs": "/api/docs",
    }


@app.get("/health")
def health_check():
    return {"status": "healthy", "restaurant": settings.RESTAURANT_NAME}


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(
        "main:app",
        host=settings.HOST,
        port=settings.PORT,
        reload=settings.DEBUG,
        log_level="info",
    )
