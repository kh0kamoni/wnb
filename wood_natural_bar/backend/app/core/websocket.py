from fastapi import WebSocket
from typing import Dict, List, Set, Optional
import json
import asyncio
import logging

logger = logging.getLogger(__name__)


class ConnectionManager:
    def __init__(self):
        # role -> list of websockets
        self.active_connections: Dict[str, List[WebSocket]] = {
            "kitchen": [],
            "bar": [],
            "waiter": [],
            "cashier": [],
            "admin": [],
            "all": [],
        }
        # table_id -> list of websockets (for table-specific updates)
        self.table_connections: Dict[int, List[WebSocket]] = {}

    async def connect(self, websocket: WebSocket, role: str = "all", table_id: Optional[int] = None):
        await websocket.accept()
        
        if role in self.active_connections:
            self.active_connections[role].append(websocket)
        self.active_connections["all"].append(websocket)
        
        if table_id:
            if table_id not in self.table_connections:
                self.table_connections[table_id] = []
            self.table_connections[table_id].append(websocket)
        
        logger.info(f"WebSocket connected: role={role}, table_id={table_id}")

    def disconnect(self, websocket: WebSocket, role: str = "all", table_id: Optional[int] = None):
        for role_key, connections in self.active_connections.items():
            if websocket in connections:
                connections.remove(websocket)
        
        if table_id and table_id in self.table_connections:
            if websocket in self.table_connections[table_id]:
                self.table_connections[table_id].remove(websocket)
        
        logger.info(f"WebSocket disconnected: role={role}")

    async def send_personal_message(self, message: dict, websocket: WebSocket):
        try:
            await websocket.send_text(json.dumps(message))
        except Exception as e:
            logger.error(f"Error sending personal message: {e}")

    async def broadcast_to_role(self, role: str, message: dict):
        """Send message to all clients with a specific role."""
        connections = self.active_connections.get(role, [])
        disconnected = []
        for connection in connections:
            try:
                await connection.send_text(json.dumps(message))
            except Exception as e:
                logger.error(f"Error broadcasting to {role}: {e}")
                disconnected.append(connection)
        
        # Clean up disconnected
        for conn in disconnected:
            if conn in connections:
                connections.remove(conn)

    async def broadcast_to_all(self, message: dict):
        """Send message to all connected clients."""
        await self.broadcast_to_role("all", message)

    async def broadcast_to_table(self, table_id: int, message: dict):
        """Send message to clients watching a specific table."""
        connections = self.table_connections.get(table_id, [])
        for connection in connections:
            try:
                await connection.send_text(json.dumps(message))
            except Exception as e:
                logger.error(f"Error broadcasting to table {table_id}: {e}")

    async def notify_new_order(self, order_data: dict):
        """Notify kitchen and bar of new order."""
        message = {"type": "new_order", "data": order_data}
        await self.broadcast_to_role("kitchen", message)
        await self.broadcast_to_role("bar", message)
        await self.broadcast_to_role("admin", message)
        await self.broadcast_to_role("waiter", message)

    async def notify_order_update(self, order_data: dict):
        """Notify all relevant roles of order status change."""
        message = {"type": "order_update", "data": order_data}
        await self.broadcast_to_role("waiter", message)
        await self.broadcast_to_role("cashier", message)
        await self.broadcast_to_role("admin", message)

    async def notify_item_ready(self, order_id: int, item_data: dict):
        """Notify waiter when a kitchen item is ready."""
        message = {"type": "item_ready", "data": {"order_id": order_id, "item": item_data}}
        await self.broadcast_to_role("waiter", message)

    async def notify_order_complete(self, order_data: dict):
        """Notify waiter when entire order is ready."""
        message = {"type": "order_complete", "data": order_data}
        await self.broadcast_to_role("waiter", message)

    async def notify_table_status(self, table_data: dict):
        """Notify all when table status changes."""
        message = {"type": "table_status", "data": table_data}
        await self.broadcast_to_all(message)

    async def notify_payment_complete(self, order_data: dict):
        """Notify relevant parties when payment is processed."""
        message = {"type": "payment_complete", "data": order_data}
        await self.broadcast_to_role("waiter", message)
        await self.broadcast_to_role("admin", message)

    async def notify_stock_alert(self, ingredient_data: dict):
        """Notify kitchen and admin of low stock."""
        message = {"type": "stock_alert", "data": ingredient_data}
        await self.broadcast_to_role("kitchen", message)
        await self.broadcast_to_role("admin", message)

    async def notify_void_request(self, void_data: dict):
        """Notify manager/admin of void request."""
        message = {"type": "void_request", "data": void_data}
        await self.broadcast_to_role("admin", message)

    def get_stats(self) -> dict:
        return {
            "kitchen": len(self.active_connections.get("kitchen", [])),
            "bar": len(self.active_connections.get("bar", [])),
            "waiter": len(self.active_connections.get("waiter", [])),
            "cashier": len(self.active_connections.get("cashier", [])),
            "admin": len(self.active_connections.get("admin", [])),
            "total": len(self.active_connections.get("all", [])),
        }


# Global instance
manager = ConnectionManager()
