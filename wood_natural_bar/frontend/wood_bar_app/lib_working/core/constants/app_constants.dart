class AppConstants {
  // ─── API ───
  static const String defaultBaseUrl = 'http://woodbar-server.local:8000';
  static const String apiVersion = '/api/v1';
  static const int connectionTimeout = 10000;
  static const int receiveTimeout = 30000;

  // ─── STORAGE KEYS ───
  static const String accessTokenKey = 'access_token';
  static const String refreshTokenKey = 'refresh_token';
  static const String userDataKey = 'user_data';
  static const String serverUrlKey = 'server_url';
  static const String themeKey = 'theme_mode';
  static const String brandingKey = 'branding';
  static const String cachedMenuKey = 'cached_menu';
  static const String cachedTablesKey = 'cached_tables';
  static const String offlineOrdersKey = 'offline_orders';

  // ─── WS ROLES ───
  static const String wsRoleKitchen = 'kitchen';
  static const String wsRoleBar = 'bar';
  static const String wsRoleWaiter = 'waiter';
  static const String wsRoleCashier = 'cashier';
  static const String wsRoleAdmin = 'admin';

  // ─── ORDER STATUS ───
  static const String statusDraft = 'draft';
  static const String statusSent = 'sent';
  static const String statusInProgress = 'in_progress';
  static const String statusReady = 'ready';
  static const String statusServed = 'served';
  static const String statusBilled = 'billed';
  static const String statusPaid = 'paid';
  static const String statusCancelled = 'cancelled';
  static const String statusVoid = 'void';

  // ─── TABLE STATUS ───
  static const String tableFree = 'free';
  static const String tableOccupied = 'occupied';
  static const String tableReserved = 'reserved';
  static const String tableCleaning = 'cleaning';

  // ─── ROLES ───
  static const String roleAdmin = 'admin';
  static const String roleManager = 'manager';
  static const String roleWaiter = 'waiter';
  static const String roleCashier = 'cashier';
  static const String roleKitchen = 'kitchen';
  static const String roleBar = 'bar';

  // ─── ANIMATION DURATIONS ───
  static const Duration animShort = Duration(milliseconds: 200);
  static const Duration animMedium = Duration(milliseconds: 350);
  static const Duration animLong = Duration(milliseconds: 500);

  // ─── SOUND FILES ───
  static const String soundNewOrder = 'sounds/new_order.mp3';
  static const String soundItemReady = 'sounds/item_ready.mp3';
  static const String soundPayment = 'sounds/payment.mp3';
  static const String soundAlert = 'sounds/alert.mp3';
}
