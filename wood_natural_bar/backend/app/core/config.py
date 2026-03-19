from pydantic_settings import BaseSettings
from typing import Optional
from pathlib import Path
import os


class Settings(BaseSettings):
    # App
    APP_NAME: str = "Wood Natural Bar"
    APP_VERSION: str = "1.0.0"
    DEBUG: bool = True
    HOST: str = "0.0.0.0"
    PORT: int = 8000

    # Security
    SECRET_KEY: str = "change-me-in-production-must-be-at-least-32-characters"
    ALGORITHM: str = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 480
    REFRESH_TOKEN_EXPIRE_DAYS: int = 7

    # Database
    DATABASE_URL: str = "postgresql://woodbar:woodbar_pass@localhost:5432/woodbar_db"

    # File Storage
    UPLOAD_DIR: str = "./uploads"
    STATIC_DIR: str = "./static"
    MAX_UPLOAD_SIZE: int = 10485760  # 10MB

    # Printers
    DEFAULT_RECEIPT_PRINTER_IP: str = "192.168.1.100"
    DEFAULT_RECEIPT_PRINTER_PORT: int = 9100
    DEFAULT_KITCHEN_PRINTER_IP: str = "192.168.1.101"
    DEFAULT_KITCHEN_PRINTER_PORT: int = 9100
    DEFAULT_BAR_PRINTER_IP: str = "192.168.1.102"
    DEFAULT_BAR_PRINTER_PORT: int = 9100

    # Restaurant Branding
    RESTAURANT_NAME: str = "Wood Natural Bar"
    RESTAURANT_TAGLINE: str = "Fresh & Natural"
    RESTAURANT_ADDRESS: str = "123 Main Street, City"
    RESTAURANT_PHONE: str = "+1 234 567 890"
    RESTAURANT_CURRENCY: str = "USD"
    RESTAURANT_CURRENCY_SYMBOL: str = "$"
    RESTAURANT_TIMEZONE: str = "America/New_York"
    RESTAURANT_TAX_RATE: float = 0.10
    RESTAURANT_SERVICE_CHARGE: float = 0.05

    # mDNS
    MDNS_HOSTNAME: str = "woodbar-server"

    class Config:
        env_file = ".env"
        case_sensitive = True

    def get_upload_path(self, subdir: str = "") -> Path:
        path = Path(self.UPLOAD_DIR) / subdir
        path.mkdir(parents=True, exist_ok=True)
        return path


settings = Settings()

# Ensure directories exist
Path(settings.UPLOAD_DIR).mkdir(parents=True, exist_ok=True)
Path(settings.STATIC_DIR).mkdir(parents=True, exist_ok=True)
