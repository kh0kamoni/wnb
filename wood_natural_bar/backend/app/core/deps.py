from fastapi import Depends, HTTPException, status, WebSocket
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from sqlalchemy.orm import Session
from typing import Optional
from app.db.database import get_db
from app.models.models import User, UserRole
from app.core.security import decode_token
from datetime import datetime

security = HTTPBearer()


def get_current_user(
    credentials: HTTPAuthorizationCredentials = Depends(security),
    db: Session = Depends(get_db)
) -> User:
    payload = decode_token(credentials.credentials)
    user_id = payload.get("sub")
    if not user_id:
        raise HTTPException(status_code=401, detail="Invalid token")
    
    user = db.query(User).filter(User.id == int(user_id), User.is_active == True).first()
    if not user:
        raise HTTPException(status_code=401, detail="User not found or inactive")
    
    # Update last login
    user.last_login = datetime.utcnow()
    db.commit()
    return user


def get_current_user_optional(
    credentials: Optional[HTTPAuthorizationCredentials] = Depends(HTTPBearer(auto_error=False)),
    db: Session = Depends(get_db)
) -> Optional[User]:
    if not credentials:
        return None
    try:
        return get_current_user(credentials, db)
    except HTTPException:
        return None


def require_roles(*roles: UserRole):
    def checker(current_user: User = Depends(get_current_user)):
        if current_user.role not in roles:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail=f"Access denied. Required roles: {[r.value for r in roles]}"
            )
        return current_user
    return checker


def require_admin():
    return require_roles(UserRole.ADMIN)


def require_admin_or_manager():
    return require_roles(UserRole.ADMIN, UserRole.MANAGER)


def require_staff():
    return require_roles(
        UserRole.ADMIN, UserRole.MANAGER, UserRole.WAITER,
        UserRole.CASHIER, UserRole.KITCHEN, UserRole.BAR
    )


async def get_ws_user(websocket: WebSocket, db: Session) -> Optional[User]:
    """Authenticate WebSocket connections via token in query params."""
    token = websocket.query_params.get("token")
    if not token:
        return None
    try:
        payload = decode_token(token)
        user_id = payload.get("sub")
        if not user_id:
            return None
        return db.query(User).filter(User.id == int(user_id), User.is_active == True).first()
    except Exception:
        return None
