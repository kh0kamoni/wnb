import socket
import logging
from typing import Optional, List
from datetime import datetime
from sqlalchemy.orm import Session
from app.models.models import Order, Printer, PrinterType, OrderItem
from app.core.config import settings

logger = logging.getLogger(__name__)


class ESCPOSPrinter:
    """ESC/POS commands for network thermal printers."""
    
    INIT = b'\x1b\x40'
    CUT = b'\x1d\x56\x41\x00'
    FEED_LINE = b'\x0a'
    BOLD_ON = b'\x1b\x45\x01'
    BOLD_OFF = b'\x1b\x45\x00'
    ALIGN_LEFT = b'\x1b\x61\x00'
    ALIGN_CENTER = b'\x1b\x61\x01'
    ALIGN_RIGHT = b'\x1b\x61\x02'
    FONT_NORMAL = b'\x1b\x21\x00'
    FONT_DOUBLE = b'\x1b\x21\x30'
    FONT_LARGE = b'\x1b\x21\x38'
    BEEP = b'\x1b\x42\x05\x05'
    OPEN_DRAWER = b'\x1b\x70\x00\x19\xfa'
    
    @staticmethod
    def text(content: str, encoding='cp437') -> bytes:
        try:
            return content.encode(encoding, errors='replace')
        except Exception:
            return content.encode('utf-8', errors='replace')
    
    @staticmethod
    def line(char='-', width=42) -> bytes:
        return ESCPOSPrinter.text(char * width + '\n')


class PrintService:
    def __init__(self):
        self.timeout = 5  # seconds

    def _send_to_printer(self, ip: str, port: int, data: bytes) -> bool:
        """Send raw bytes to a network printer."""
        try:
            with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as sock:
                sock.settimeout(self.timeout)
                sock.connect((ip, port))
                sock.sendall(data)
            return True
        except Exception as e:
            logger.error(f"Print error to {ip}:{port} - {e}")
            return False

    def print_receipt(self, order: Order, printer: Optional[Printer] = None) -> bool:
        """Print a customer receipt."""
        p = ESCPOSPrinter
        buf = bytearray()
        
        buf += p.INIT
        buf += p.ALIGN_CENTER
        buf += p.FONT_LARGE
        buf += p.BOLD_ON
        buf += p.text(f"{settings.RESTAURANT_NAME}\n")
        buf += p.BOLD_OFF
        buf += p.FONT_NORMAL
        buf += p.text(f"{settings.RESTAURANT_TAGLINE}\n")
        buf += p.text(f"{settings.RESTAURANT_ADDRESS}\n")
        buf += p.text(f"Tel: {settings.RESTAURANT_PHONE}\n")
        buf += p.line()
        
        buf += p.ALIGN_LEFT
        buf += p.text(f"Order: {order.order_number}\n")
        
        table_info = f"Table: {order.table.number}" if order.table else f"Type: {order.order_type.value}"
        buf += p.text(f"{table_info}\n")
        
        if order.customer_name:
            buf += p.text(f"Customer: {order.customer_name}\n")
        
        waiter_name = order.waiter.full_name if order.waiter else "Staff"
        buf += p.text(f"Served by: {waiter_name}\n")
        buf += p.text(f"Date: {order.opened_at.strftime('%d/%m/%Y %H:%M')}\n")
        buf += p.line()
        
        buf += p.BOLD_ON
        buf += p.text(f"{'ITEM':<22}{'QTY':>4}{'PRICE':>8}{'TOTAL':>8}\n")
        buf += p.BOLD_OFF
        buf += p.line()
        
        for item in order.items:
            if item.status not in ['cancelled', 'void']:
                name = item.menu_item.name[:22] if item.menu_item else "Unknown"
                buf += p.text(f"{name:<22}{item.quantity:>4}{item.unit_price:>8.2f}{item.total_price:>8.2f}\n")
                
                if item.modifiers:
                    for mod in item.modifiers:
                        mod_name = f"  + {mod.get('option_name', '')}"[:24]
                        price_adj = mod.get('price_adjustment', 0)
                        if price_adj:
                            buf += p.text(f"{mod_name:<30}{price_adj:>12.2f}\n")
                
                if item.notes:
                    buf += p.text(f"  * {item.notes[:38]}\n")
        
        buf += p.line()
        
        symbol = settings.RESTAURANT_CURRENCY_SYMBOL
        buf += p.text(f"{'Subtotal:':<30}{symbol}{order.subtotal:>9.2f}\n")
        
        if order.discount_amount > 0:
            buf += p.text(f"{'Discount:':<30}-{symbol}{order.discount_amount:>8.2f}\n")
        
        if order.tax_amount > 0:
            tax_pct = settings.RESTAURANT_TAX_RATE * 100
            buf += p.text(f"{'Tax (' + str(int(tax_pct)) + '%):':<30}{symbol}{order.tax_amount:>9.2f}\n")
        
        if order.service_charge_amount > 0:
            svc_pct = settings.RESTAURANT_SERVICE_CHARGE * 100
            buf += p.text(f"{'Service (' + str(int(svc_pct)) + '%):':<30}{symbol}{order.service_charge_amount:>9.2f}\n")
        
        buf += p.BOLD_ON
        buf += p.FONT_DOUBLE
        buf += p.text(f"{'TOTAL:':<20}{symbol}{order.total_amount:>8.2f}\n")
        buf += p.FONT_NORMAL
        buf += p.BOLD_OFF
        
        if order.payments:
            buf += p.line()
            for payment in order.payments:
                buf += p.text(f"{payment.method.value.capitalize():<30}{symbol}{payment.amount:>9.2f}\n")
            if order.change_amount > 0:
                buf += p.text(f"{'Change:':<30}{symbol}{order.change_amount:>9.2f}\n")
        
        buf += p.FEED_LINE
        buf += p.ALIGN_CENTER
        buf += p.text("Thank you for visiting!\n")
        buf += p.text(f"{settings.RESTAURANT_NAME}\n")
        buf += p.FEED_LINE * 3
        buf += p.CUT
        
        ip = printer.ip_address if printer else settings.DEFAULT_RECEIPT_PRINTER_IP
        port = printer.port if printer else settings.DEFAULT_RECEIPT_PRINTER_PORT
        
        return self._send_to_printer(ip, port, bytes(buf))

    def print_kitchen_ticket(self, order: Order, printer: Optional[Printer] = None) -> bool:
        """Print a kitchen order ticket."""
        p = ESCPOSPrinter
        buf = bytearray()
        
        buf += p.INIT
        buf += p.BEEP
        buf += p.ALIGN_CENTER
        buf += p.FONT_LARGE
        buf += p.BOLD_ON
        buf += p.text("*** KITCHEN ORDER ***\n")
        buf += p.BOLD_OFF
        buf += p.FONT_NORMAL
        buf += p.ALIGN_LEFT
        buf += p.line('=')
        
        table_info = f"TABLE: {order.table.number}" if order.table else f"TYPE: {order.order_type.value.upper()}"
        buf += p.BOLD_ON
        buf += p.FONT_DOUBLE
        buf += p.text(f"{table_info}\n")
        buf += p.FONT_NORMAL
        buf += p.BOLD_OFF
        
        buf += p.text(f"Order#: {order.order_number}\n")
        buf += p.text(f"Time: {datetime.utcnow().strftime('%H:%M')}\n")
        buf += p.text(f"Covers: {order.guest_count}\n")
        
        waiter_name = order.waiter.full_name if order.waiter else "Staff"
        buf += p.text(f"Waiter: {waiter_name}\n")
        buf += p.line('=')
        
        # Group items by course
        courses = {}
        for item in order.items:
            if item.status not in ['cancelled', 'void']:
                course = item.course or 1
                if course not in courses:
                    courses[course] = []
                courses[course].append(item)
        
        for course_num in sorted(courses.keys()):
            if len(courses) > 1:
                buf += p.BOLD_ON
                buf += p.text(f"--- COURSE {course_num} ---\n")
                buf += p.BOLD_OFF
            
            for item in courses[course_num]:
                buf += p.BOLD_ON
                buf += p.FONT_DOUBLE
                name = item.menu_item.name if item.menu_item else "Unknown"
                buf += p.text(f"{item.quantity}x {name}\n")
                buf += p.FONT_NORMAL
                buf += p.BOLD_OFF
                
                if item.modifiers:
                    for mod in item.modifiers:
                        buf += p.text(f"   > {mod.get('option_name', '')}\n")
                
                if item.notes:
                    buf += p.BOLD_ON
                    buf += p.text(f"   !! {item.notes}\n")
                    buf += p.BOLD_OFF
        
        if order.kitchen_notes:
            buf += p.line()
            buf += p.BOLD_ON
            buf += p.text(f"NOTE: {order.kitchen_notes}\n")
            buf += p.BOLD_OFF
        
        buf += p.FEED_LINE * 3
        buf += p.CUT
        
        ip = printer.ip_address if printer else settings.DEFAULT_KITCHEN_PRINTER_IP
        port = printer.port if printer else settings.DEFAULT_KITCHEN_PRINTER_PORT
        
        return self._send_to_printer(ip, port, bytes(buf))

    def test_printer(self, ip: str, port: int) -> bool:
        """Send a test print to verify printer connection."""
        p = ESCPOSPrinter
        buf = bytearray()
        buf += p.INIT
        buf += p.ALIGN_CENTER
        buf += p.text(f"{settings.RESTAURANT_NAME}\n")
        buf += p.text("Printer Test OK\n")
        buf += p.text(f"{datetime.utcnow().strftime('%Y-%m-%d %H:%M:%S')}\n")
        buf += p.FEED_LINE * 3
        buf += p.CUT
        return self._send_to_printer(ip, port, bytes(buf))

    def open_cash_drawer(self, printer: Optional[Printer] = None) -> bool:
        """Send command to open cash drawer via receipt printer."""
        ip = printer.ip_address if printer else settings.DEFAULT_RECEIPT_PRINTER_IP
        port = printer.port if printer else settings.DEFAULT_RECEIPT_PRINTER_PORT
        return self._send_to_printer(ip, port, ESCPOSPrinter.OPEN_DRAWER)


print_service = PrintService()
