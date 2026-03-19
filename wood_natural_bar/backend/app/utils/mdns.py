"""
mDNS (Multicast DNS) service registration.
Flutter apps discover the server as 'woodbar-server.local' automatically.
"""
import socket
import threading
import logging
from app.core.config import settings

logger = logging.getLogger(__name__)


def start_mdns():
    """Register the server on local network via mDNS/Zeroconf."""
    try:
        from zeroconf import Zeroconf, ServiceInfo
        import ipaddress

        zeroconf = Zeroconf()

        hostname = socket.gethostname()
        local_ip = socket.gethostbyname(hostname)

        info = ServiceInfo(
            "_http._tcp.local.",
            f"{settings.MDNS_HOSTNAME}._http._tcp.local.",
            addresses=[socket.inet_aton(local_ip)],
            port=settings.PORT,
            properties={
                "name": settings.RESTAURANT_NAME,
                "version": settings.APP_VERSION,
                "path": "/api/v1",
            },
            server=f"{settings.MDNS_HOSTNAME}.local.",
        )

        def _run():
            zeroconf.register_service(info)
            logger.info(f"mDNS: {settings.MDNS_HOSTNAME}.local -> {local_ip}:{settings.PORT}")

        t = threading.Thread(target=_run, daemon=True)
        t.start()

    except ImportError:
        logger.warning("zeroconf not installed — mDNS disabled")
    except Exception as e:
        logger.warning(f"mDNS registration failed: {e}")
