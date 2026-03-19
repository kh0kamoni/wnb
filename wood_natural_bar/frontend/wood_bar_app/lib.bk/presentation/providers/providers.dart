import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../data/models/models.dart';
import '../../data/datasources/api_service.dart';
import '../../data/datasources/websocket_service.dart';

// ─── SHARED PREFS ───
final sharedPrefsProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('Initialize in main()');
});

// ─── API SERVICE ───
final apiProvider = Provider<ApiService>((ref) => ApiService());

// ─── AUTH STATE ───

class AuthState {
  final UserModel? user;
  final bool isLoading;
  final String? error;
  final bool isAuthenticated;

  const AuthState({
    this.user,
    this.isLoading = false,
    this.error,
    this.isAuthenticated = false,
  });

  AuthState copyWith({
    UserModel? user,
    bool? isLoading,
    String? error,
    bool? isAuthenticated,
  }) =>
      AuthState(
        user: user ?? this.user,
        isLoading: isLoading ?? this.isLoading,
        error: error,
        isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      );
}

class AuthNotifier extends StateNotifier<AuthState> {
  final ApiService _api;

  AuthNotifier(this._api) : super(const AuthState());

  Future<bool> login(String username, String password) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final auth = await _api.login(username, password);
      state = state.copyWith(
        user: auth.user,
        isAuthenticated: true,
        isLoading: false,
      );
      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: _parseError(e),
      );
      return false;
    }
  }

  Future<bool> pinLogin(String pin) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final auth = await _api.pinLogin(pin);
      state = state.copyWith(
        user: auth.user,
        isAuthenticated: true,
        isLoading: false,
      );
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: _parseError(e));
      return false;
    }
  }

  Future<void> logout() async {
    await _api.logout();
    state = const AuthState();
  }

  Future<void> tryAutoLogin() async {
    state = state.copyWith(isLoading: true);
    try {
      final user = await _api.getMe();
      state = state.copyWith(user: user, isAuthenticated: true, isLoading: false);
    } catch (_) {
      state = state.copyWith(isLoading: false, isAuthenticated: false);
    }
  }

  String _parseError(dynamic e) {
    if (e is Exception) {
      final msg = e.toString();
      if (msg.contains('401')) return 'Invalid username or password';
      if (msg.contains('connection')) return 'Cannot connect to server';
    }
    return 'An error occurred. Please try again.';
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>(
  (ref) => AuthNotifier(ref.watch(apiProvider)),
);

// ─── SERVER URL ───

final serverUrlProvider = StateProvider<String>((ref) {
  return AppConstants.defaultBaseUrl;
});

// ─── BRANDING ───

final brandingProvider = FutureProvider<BrandingModel>((ref) async {
  final api = ref.watch(apiProvider);
  try {
    return await api.getPublicSettings();
  } catch (_) {
    return const BrandingModel();
  }
});

// ─── MENU PROVIDERS ───

final categoriesProvider = FutureProvider<List<CategoryModel>>((ref) async {
  return ref.watch(apiProvider).getCategories();
});

final menuItemsProvider = FutureProvider.family<List<MenuItemModel>, int?>(
  (ref, categoryId) async {
    return ref.watch(apiProvider).getMenuItems(categoryId: categoryId);
  },
);

// ─── TABLES PROVIDER ───

final tablesProvider = StateNotifierProvider<TablesNotifier, AsyncValue<List<TableModel>>>(
  (ref) => TablesNotifier(ref.watch(apiProvider)),
);

class TablesNotifier extends StateNotifier<AsyncValue<List<TableModel>>> {
  final ApiService _api;

  TablesNotifier(this._api) : super(const AsyncValue.loading()) {
    load();
  }

  Future<void> load() async {
    state = const AsyncValue.loading();
    try {
      final tables = await _api.getTables();
      state = AsyncValue.data(tables);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  void updateTableStatus(int tableId, String status) {
    state.whenData((tables) {
      state = AsyncValue.data([
        for (final t in tables)
          if (t.id == tableId)
            TableModel(
              id: t.id, number: t.number, name: t.name,
              sectionId: t.sectionId, section: t.section,
              capacity: t.capacity, status: status,
              posX: t.posX, posY: t.posY, width: t.width, height: t.height,
              shape: t.shape, isActive: t.isActive, qrCodeUrl: t.qrCodeUrl,
              activeOrderId: status == 'occupied' ? t.activeOrderId : null,
            )
          else
            t
      ]);
    });
  }
}

// ─── ORDERS PROVIDER ───

final activeOrdersProvider = StateNotifierProvider<OrdersNotifier, AsyncValue<List<OrderModel>>>(
  (ref) => OrdersNotifier(ref.watch(apiProvider)),
);

class OrdersNotifier extends StateNotifier<AsyncValue<List<OrderModel>>> {
  final ApiService _api;

  OrdersNotifier(this._api) : super(const AsyncValue.loading()) {
    loadActive();
  }

  Future<void> loadActive() async {
    state = const AsyncValue.loading();
    try {
      final orders = await _api.getOrders(activeOnly: true);
      state = AsyncValue.data(orders);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  void upsertOrder(OrderModel order) {
    state.whenData((orders) {
      final idx = orders.indexWhere((o) => o.id == order.id);
      if (idx >= 0) {
        final updated = [...orders];
        updated[idx] = order;
        state = AsyncValue.data(updated);
      } else {
        state = AsyncValue.data([order, ...orders]);
      }
    });
  }

  void removeOrder(int orderId) {
    state.whenData((orders) {
      state = AsyncValue.data(orders.where((o) => o.id != orderId).toList());
    });
  }
}

// ─── KITCHEN QUEUE ───

final kitchenQueueProvider = StateNotifierProvider<KitchenQueueNotifier, AsyncValue<List<OrderModel>>>(
  (ref) => KitchenQueueNotifier(ref.watch(apiProvider)),
);

class KitchenQueueNotifier extends StateNotifier<AsyncValue<List<OrderModel>>> {
  final ApiService _api;

  KitchenQueueNotifier(this._api) : super(const AsyncValue.loading()) {
    load();
  }

  Future<void> load() async {
    state = const AsyncValue.loading();
    try {
      final orders = await _api.getKitchenQueue();
      state = AsyncValue.data(orders);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> updateItemStatus(int orderId, int itemId, String status) async {
    try {
      await _api.updateOrderItem(orderId, itemId, {'status': status});
      await load(); // Reload
    } catch (_) {}
  }
}

// ─── DASHBOARD ───

final dashboardProvider = FutureProvider<DashboardStats>((ref) async {
  return ref.watch(apiProvider).getDashboardStats();
});

// ─── CURRENT ORDER (Cart) ───

class CartItem {
  final MenuItemModel menuItem;
  int quantity;
  String? notes;
  List<Map<String, dynamic>> selectedModifiers;
  int seatNumber;
  int course;

  CartItem({
    required this.menuItem,
    this.quantity = 1,
    this.notes,
    this.selectedModifiers = const [],
    this.seatNumber = 1,
    this.course = 1,
  });

  double get unitPrice => menuItem.price + modifierTotal;
  double get modifierTotal =>
      selectedModifiers.fold(0.0, (sum, m) => sum + (m['price_adjustment'] ?? 0.0));
  double get lineTotal => unitPrice * quantity;

  Map<String, dynamic> toOrderItem() => {
        'menu_item_id': menuItem.id,
        'quantity': quantity,
        'notes': notes,
        'modifiers': selectedModifiers,
        'seat_number': seatNumber,
        'course': course,
      };
}

class CartState {
  final List<CartItem> items;
  final int? tableId;
  final String orderType;
  final int guestCount;
  final String? notes;
  final String? customerName;
  final String? customerPhone;
  final int? existingOrderId;

  const CartState({
    this.items = const [],
    this.tableId,
    this.orderType = 'dine_in',
    this.guestCount = 1,
    this.notes,
    this.customerName,
    this.customerPhone,
    this.existingOrderId,
  });

  double get subtotal => items.fold(0.0, (sum, i) => sum + i.lineTotal);

  CartState copyWith({
    List<CartItem>? items,
    int? tableId,
    String? orderType,
    int? guestCount,
    String? notes,
    String? customerName,
    String? customerPhone,
    int? existingOrderId,
  }) =>
      CartState(
        items: items ?? this.items,
        tableId: tableId ?? this.tableId,
        orderType: orderType ?? this.orderType,
        guestCount: guestCount ?? this.guestCount,
        notes: notes ?? this.notes,
        customerName: customerName ?? this.customerName,
        customerPhone: customerPhone ?? this.customerPhone,
        existingOrderId: existingOrderId ?? this.existingOrderId,
      );
}

class CartNotifier extends StateNotifier<CartState> {
  CartNotifier() : super(const CartState());

  void initForTable(int tableId, int guestCount) {
    state = CartState(
      tableId: tableId,
      guestCount: guestCount,
      orderType: 'dine_in',
    );
  }

  void initForTakeaway(String? customerName, String? phone) {
    state = CartState(
      orderType: 'takeaway',
      customerName: customerName,
      customerPhone: phone,
    );
  }

  void addItem(MenuItemModel item, {
    int quantity = 1,
    String? notes,
    List<Map<String, dynamic>> modifiers = const [],
    int seat = 1,
    int course = 1,
  }) {
    final existing = state.items.indexWhere(
      (i) => i.menuItem.id == item.id && i.notes == notes,
    );
    if (existing >= 0 && modifiers.isEmpty) {
      final updated = [...state.items];
      updated[existing].quantity += quantity;
      state = state.copyWith(items: updated);
    } else {
      state = state.copyWith(items: [
        ...state.items,
        CartItem(
          menuItem: item,
          quantity: quantity,
          notes: notes,
          selectedModifiers: modifiers,
          seatNumber: seat,
          course: course,
        ),
      ]);
    }
  }

  void removeItem(int index) {
    final updated = [...state.items];
    updated.removeAt(index);
    state = state.copyWith(items: updated);
  }

  void updateQuantity(int index, int quantity) {
    if (quantity <= 0) {
      removeItem(index);
      return;
    }
    final updated = [...state.items];
    updated[index].quantity = quantity;
    state = state.copyWith(items: updated);
  }

  void setGuestCount(int count) => state = state.copyWith(guestCount: count);
  void setNotes(String notes) => state = state.copyWith(notes: notes);
  void setExistingOrderId(int id) => state = state.copyWith(existingOrderId: id);

  void clear() => state = const CartState();

  Map<String, dynamic> toCreateOrderPayload() => {
        'table_id': state.tableId,
        'order_type': state.orderType,
        'guest_count': state.guestCount,
        'notes': state.notes,
        'customer_name': state.customerName,
        'customer_phone': state.customerPhone,
        'items': state.items.map((i) => i.toOrderItem()).toList(),
      };

  List<Map<String, dynamic>> toAddItemsPayload() =>
      state.items.map((i) => i.toOrderItem()).toList();
}

final cartProvider = StateNotifierProvider<CartNotifier, CartState>(
  (ref) => CartNotifier(),
);

// ─── WEBSOCKET STATE ───

final wsConnectionStateProvider = StateProvider<WsConnectionState>((ref) {
  return WsConnectionState.disconnected;
});
