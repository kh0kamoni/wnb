import 'package:flutter/material.dart';

// ─────────────────── USER ───────────────────

class UserModel {
  final int id;
  final String username;
  final String fullName;
  final String? email;
  final String role;
  final String? phone;
  final bool isActive;
  final String? avatarUrl;
  final Map<String, dynamic> permissions;
  final DateTime? lastLogin;
  final DateTime createdAt;

  const UserModel({
    required this.id,
    required this.username,
    required this.fullName,
    this.email,
    required this.role,
    this.phone,
    required this.isActive,
    this.avatarUrl,
    this.permissions = const {},
    this.lastLogin,
    required this.createdAt,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) => UserModel(
        id: json['id'],
        username: json['username'],
        fullName: json['full_name'],
        email: json['email'],
        role: json['role'],
        phone: json['phone'],
        isActive: json['is_active'] ?? true,
        avatarUrl: json['avatar_url'],
        permissions: json['permissions'] ?? {},
        lastLogin: json['last_login'] != null ? DateTime.parse(json['last_login']) : null,
        createdAt: DateTime.parse(json['created_at']),
      );

  bool get isAdmin => role == 'admin';
  bool get isManager => role == 'manager' || isAdmin;
  bool get isKitchen => role == 'kitchen';
  bool get isBar => role == 'bar';
  bool get isWaiter => role == 'waiter';
  bool get isCashier => role == 'cashier';
  bool get canManage => isAdmin || isManager;
}

// ─────────────────── AUTH ───────────────────

class AuthResponse {
  final String accessToken;
  final String refreshToken;
  final UserModel user;

  const AuthResponse({
    required this.accessToken,
    required this.refreshToken,
    required this.user,
  });

  factory AuthResponse.fromJson(Map<String, dynamic> json) => AuthResponse(
        accessToken: json['access_token'],
        refreshToken: json['refresh_token'],
        user: UserModel.fromJson(json['user']),
      );
}

// ─────────────────── CATEGORY ───────────────────

class CategoryModel {
  final int id;
  final String name;
  final String? description;
  final String? imageUrl;
  final String? color;
  final String? icon;
  final int sortOrder;
  final bool isActive;

  const CategoryModel({
    required this.id,
    required this.name,
    this.description,
    this.imageUrl,
    this.color,
    this.icon,
    this.sortOrder = 0,
    this.isActive = true,
  });

  factory CategoryModel.fromJson(Map<String, dynamic> json) => CategoryModel(
        id: json['id'],
        name: json['name'],
        description: json['description'],
        imageUrl: json['image_url'],
        color: json['color'],
        icon: json['icon'],
        sortOrder: json['sort_order'] ?? 0,
        isActive: json['is_active'] ?? true,
      );

  Color get displayColor {
    if (color != null && color!.isNotEmpty) {
      try {
        return Color(int.parse(color!.replaceFirst('#', '0xFF')));
      } catch (_) {}
    }
    return const Color(0xFF2E7D32);
  }
}

// ─────────────────── MODIFIER ───────────────────

class ModifierOptionModel {
  final int id;
  final String name;
  final double priceAdjustment;
  final bool isActive;
  bool isSelected;

  ModifierOptionModel({
    required this.id,
    required this.name,
    required this.priceAdjustment,
    this.isActive = true,
    this.isSelected = false,
  });

  factory ModifierOptionModel.fromJson(Map<String, dynamic> json) => ModifierOptionModel(
        id: json['id'],
        name: json['name'],
        priceAdjustment: (json['price_adjustment'] ?? 0).toDouble(),
        isActive: json['is_active'] ?? true,
      );
}

class ModifierGroupModel {
  final int id;
  final String name;
  final int minSelections;
  final int maxSelections;
  final bool isRequired;
  final List<ModifierOptionModel> options;

  const ModifierGroupModel({
    required this.id,
    required this.name,
    required this.minSelections,
    required this.maxSelections,
    required this.isRequired,
    required this.options,
  });

  factory ModifierGroupModel.fromJson(Map<String, dynamic> json) => ModifierGroupModel(
        id: json['id'],
        name: json['name'],
        minSelections: json['min_selections'] ?? 0,
        maxSelections: json['max_selections'] ?? 1,
        isRequired: json['is_required'] ?? false,
        options: (json['options'] as List? ?? [])
            .map((o) => ModifierOptionModel.fromJson(o))
            .toList(),
      );
}

// ─────────────────── MENU ITEM ───────────────────

class MenuItemModel {
  final int id;
  final String name;
  final String? description;
  final double price;
  final double? costPrice;
  final int? categoryId;
  final CategoryModel? category;
  final String? imageUrl;
  final bool isActive;
  final bool isAvailable;
  final bool isFeatured;
  final int preparationTime;
  final int? calories;
  final List<String> allergens;
  final List<String> tags;
  final String printerTarget;
  final List<ModifierGroupModel> modifierGroups;
  final bool stockTracking;
  final double? currentStock;

  const MenuItemModel({
    required this.id,
    required this.name,
    this.description,
    required this.price,
    this.costPrice,
    this.categoryId,
    this.category,
    this.imageUrl,
    this.isActive = true,
    this.isAvailable = true,
    this.isFeatured = false,
    this.preparationTime = 0,
    this.calories,
    this.allergens = const [],
    this.tags = const [],
    this.printerTarget = 'kitchen',
    this.modifierGroups = const [],
    this.stockTracking = false,
    this.currentStock,
  });

  factory MenuItemModel.fromJson(Map<String, dynamic> json) => MenuItemModel(
        id: json['id'],
        name: json['name'],
        description: json['description'],
        price: (json['price'] ?? 0).toDouble(),
        costPrice: json['cost_price']?.toDouble(),
        categoryId: json['category_id'],
        category: json['category'] != null ? CategoryModel.fromJson(json['category']) : null,
        imageUrl: json['image_url'],
        isActive: json['is_active'] ?? true,
        isAvailable: json['is_available'] ?? true,
        isFeatured: json['is_featured'] ?? false,
        preparationTime: json['preparation_time'] ?? 0,
        calories: json['calories'],
        allergens: List<String>.from(json['allergens'] ?? []),
        tags: List<String>.from(json['tags'] ?? []),
        printerTarget: json['printer_target'] ?? 'kitchen',
        modifierGroups: (json['modifier_groups'] as List? ?? [])
            .map((g) => ModifierGroupModel.fromJson(g))
            .toList(),
        stockTracking: json['stock_tracking'] ?? false,
        currentStock: json['current_stock']?.toDouble(),
      );

  bool get isVegan => tags.contains('vegan');
  bool get isGlutenFree => tags.contains('gluten-free');
  bool get isSpicy => tags.contains('spicy');
}

// ─────────────────── TABLE ───────────────────

class SectionModel {
  final int id;
  final String name;
  final String? color;

  const SectionModel({required this.id, required this.name, this.color});

  factory SectionModel.fromJson(Map<String, dynamic> json) => SectionModel(
        id: json['id'],
        name: json['name'],
        color: json['color'],
      );
}

class TableModel {
  final int id;
  final String number;
  final String? name;
  final int? sectionId;
  final SectionModel? section;
  final int capacity;
  final String status;
  final double posX;
  final double posY;
  final double width;
  final double height;
  final String shape;
  final bool isActive;
  final String? qrCodeUrl;
  final int? activeOrderId;

  const TableModel({
    required this.id,
    required this.number,
    this.name,
    this.sectionId,
    this.section,
    required this.capacity,
    required this.status,
    this.posX = 0,
    this.posY = 0,
    this.width = 80,
    this.height = 80,
    this.shape = 'rectangle',
    this.isActive = true,
    this.qrCodeUrl,
    this.activeOrderId,
  });

  factory TableModel.fromJson(Map<String, dynamic> json) => TableModel(
        id: json['id'],
        number: json['number'].toString(),
        name: json['name'],
        sectionId: json['section_id'],
        section: json['section'] != null ? SectionModel.fromJson(json['section']) : null,
        capacity: json['capacity'] ?? 4,
        status: json['status'] ?? 'free',
        posX: (json['pos_x'] ?? 0).toDouble(),
        posY: (json['pos_y'] ?? 0).toDouble(),
        width: (json['width'] ?? 80).toDouble(),
        height: (json['height'] ?? 80).toDouble(),
        shape: json['shape'] ?? 'rectangle',
        isActive: json['is_active'] ?? true,
        qrCodeUrl: json['qr_code_url'],
        activeOrderId: json['active_order_id'],
      );

  bool get isFree => status == 'free';
  bool get isOccupied => status == 'occupied';
  bool get isReserved => status == 'reserved';

  Color get statusColor {
    switch (status) {
      case 'free': return const Color(0xFF43A047);
      case 'occupied': return const Color(0xFFE53935);
      case 'reserved': return const Color(0xFF1E88E5);
      case 'cleaning': return const Color(0xFFFF9800);
      default: return const Color(0xFF9E9E9E);
    }
  }

  String get displayName => name ?? 'Table $number';
}

// ─────────────────── ORDER ITEM ───────────────────

class OrderItemModifier {
  final int groupId;
  final String groupName;
  final int optionId;
  final String optionName;
  final double priceAdjustment;

  const OrderItemModifier({
    required this.groupId,
    required this.groupName,
    required this.optionId,
    required this.optionName,
    required this.priceAdjustment,
  });

  factory OrderItemModifier.fromJson(Map<String, dynamic> json) => OrderItemModifier(
        groupId: json['group_id'],
        groupName: json['group_name'],
        optionId: json['option_id'],
        optionName: json['option_name'],
        priceAdjustment: (json['price_adjustment'] ?? 0).toDouble(),
      );

  Map<String, dynamic> toJson() => {
        'group_id': groupId,
        'group_name': groupName,
        'option_id': optionId,
        'option_name': optionName,
        'price_adjustment': priceAdjustment,
      };
}

class OrderItemModel {
  final int id;
  final int menuItemId;
  final int quantity;
  final double unitPrice;
  final double totalPrice;
  final double modifierTotal;
  final String status;
  final String? notes;
  final List<OrderItemModifier> modifiers;
  final int? seatNumber;
  final int course;
  final bool isComp;
  final MenuItemModel? menuItem;
  final DateTime? sentAt;
  final DateTime? startedAt;
  final DateTime? completedAt;

  const OrderItemModel({
    required this.id,
    required this.menuItemId,
    required this.quantity,
    required this.unitPrice,
    required this.totalPrice,
    required this.modifierTotal,
    required this.status,
    this.notes,
    this.modifiers = const [],
    this.seatNumber,
    this.course = 1,
    this.isComp = false,
    this.menuItem,
    this.sentAt,
    this.startedAt,
    this.completedAt,
  });

  factory OrderItemModel.fromJson(Map<String, dynamic> json) => OrderItemModel(
        id: json['id'],
        menuItemId: json['menu_item_id'],
        quantity: json['quantity'] ?? 1,
        unitPrice: (json['unit_price'] ?? 0).toDouble(),
        totalPrice: (json['total_price'] ?? 0).toDouble(),
        modifierTotal: (json['modifier_total'] ?? 0).toDouble(),
        status: json['status'] ?? 'pending',
        notes: json['notes'],
        modifiers: (json['modifiers'] as List? ?? [])
            .map((m) => OrderItemModifier.fromJson(m))
            .toList(),
        seatNumber: json['seat_number'],
        course: json['course'] ?? 1,
        isComp: json['is_comp'] ?? false,
        menuItem: json['menu_item'] != null ? MenuItemModel.fromJson(json['menu_item']) : null,
        sentAt: json['sent_at'] != null ? DateTime.parse(json['sent_at']) : null,
        startedAt: json['started_at'] != null ? DateTime.parse(json['started_at']) : null,
        completedAt: json['completed_at'] != null ? DateTime.parse(json['completed_at']) : null,
      );

  double get lineTotal => totalPrice + modifierTotal;

  Color get statusColor {
    switch (status) {
      case 'pending': return const Color(0xFFFFA000);
      case 'in_progress': return const Color(0xFF1E88E5);
      case 'ready': return const Color(0xFF43A047);
      case 'served': return const Color(0xFF9E9E9E);
      case 'void': return const Color(0xFFE53935);
      case 'cancelled': return const Color(0xFFE53935);
      default: return const Color(0xFF9E9E9E);
    }
  }
}

// ─────────────────── ORDER ───────────────────

class PaymentModel {
  final int id;
  final int orderId;
  final String method;
  final double amount;
  final String status;
  final DateTime createdAt;

  const PaymentModel({
    required this.id,
    required this.orderId,
    required this.method,
    required this.amount,
    required this.status,
    required this.createdAt,
  });

  factory PaymentModel.fromJson(Map<String, dynamic> json) => PaymentModel(
        id: json['id'],
        orderId: json['order_id'],
        method: json['method'],
        amount: (json['amount'] ?? 0).toDouble(),
        status: json['status'] ?? 'completed',
        createdAt: DateTime.parse(json['created_at']),
      );
}

class OrderModel {
  final int id;
  final String orderNumber;
  final int? tableId;
  final String orderType;
  final String status;
  final int guestCount;
  final int? waiterId;
  final double subtotal;
  final double discountAmount;
  final double taxAmount;
  final double serviceChargeAmount;
  final double totalAmount;
  final double paidAmount;
  final double changeAmount;
  final String? notes;
  final String? kitchenNotes;
  final String? customerName;
  final String? customerPhone;
  final List<OrderItemModel> items;
  final List<PaymentModel> payments;
  final TableModel? table;
  final UserModel? waiter;
  final DateTime openedAt;
  final DateTime? sentAt;
  final DateTime? paidAt;

  const OrderModel({
    required this.id,
    required this.orderNumber,
    this.tableId,
    required this.orderType,
    required this.status,
    required this.guestCount,
    this.waiterId,
    required this.subtotal,
    required this.discountAmount,
    required this.taxAmount,
    required this.serviceChargeAmount,
    required this.totalAmount,
    required this.paidAmount,
    required this.changeAmount,
    this.notes,
    this.kitchenNotes,
    this.customerName,
    this.customerPhone,
    this.items = const [],
    this.payments = const [],
    this.table,
    this.waiter,
    required this.openedAt,
    this.sentAt,
    this.paidAt,
  });

  factory OrderModel.fromJson(Map<String, dynamic> json) => OrderModel(
        id: json['id'],
        orderNumber: json['order_number'],
        tableId: json['table_id'],
        orderType: json['order_type'] ?? 'dine_in',
        status: json['status'] ?? 'draft',
        guestCount: json['guest_count'] ?? 1,
        waiterId: json['waiter_id'],
        subtotal: (json['subtotal'] ?? 0).toDouble(),
        discountAmount: (json['discount_amount'] ?? 0).toDouble(),
        taxAmount: (json['tax_amount'] ?? 0).toDouble(),
        serviceChargeAmount: (json['service_charge_amount'] ?? 0).toDouble(),
        totalAmount: (json['total_amount'] ?? 0).toDouble(),
        paidAmount: (json['paid_amount'] ?? 0).toDouble(),
        changeAmount: (json['change_amount'] ?? 0).toDouble(),
        notes: json['notes'],
        kitchenNotes: json['kitchen_notes'],
        customerName: json['customer_name'],
        customerPhone: json['customer_phone'],
        items: (json['items'] as List? ?? [])
            .map((i) => OrderItemModel.fromJson(i))
            .toList(),
        payments: (json['payments'] as List? ?? [])
            .map((p) => PaymentModel.fromJson(p))
            .toList(),
        table: json['table'] != null ? TableModel.fromJson(json['table']) : null,
        waiter: json['waiter'] != null ? UserModel.fromJson(json['waiter']) : null,
        openedAt: DateTime.parse(json['opened_at']),
        sentAt: json['sent_at'] != null ? DateTime.parse(json['sent_at']) : null,
        paidAt: json['paid_at'] != null ? DateTime.parse(json['paid_at']) : null,
      );

  bool get isDraft => status == 'draft';
  bool get isSent => status == 'sent';
  bool get isInProgress => status == 'in_progress';
  bool get isReady => status == 'ready';
  bool get isPaid => status == 'paid';
  bool get isClosed => ['paid', 'cancelled', 'void'].contains(status);

  List<OrderItemModel> get activeItems =>
      items.where((i) => i.status != 'void' && i.status != 'cancelled').toList();

  int get totalItems => activeItems.fold(0, (sum, i) => sum + i.quantity);

  Color get statusColor {
    switch (status) {
      case 'draft': return const Color(0xFF9E9E9E);
      case 'sent': return const Color(0xFFFFA000);
      case 'in_progress': return const Color(0xFF1E88E5);
      case 'ready': return const Color(0xFF43A047);
      case 'served': return const Color(0xFF00BCD4);
      case 'paid': return const Color(0xFF4CAF50);
      case 'cancelled': return const Color(0xFFE53935);
      default: return const Color(0xFF9E9E9E);
    }
  }

  String get statusLabel {
    switch (status) {
      case 'draft': return 'Draft';
      case 'sent': return 'Sent to Kitchen';
      case 'in_progress': return 'In Progress';
      case 'ready': return 'Ready to Serve';
      case 'served': return 'Served';
      case 'billed': return 'Billed';
      case 'paid': return 'Paid';
      case 'cancelled': return 'Cancelled';
      case 'void': return 'Void';
      default: return status;
    }
  }
}

// ─────────────────── BRANDING ───────────────────

class BrandingModel {
  final String restaurantName;
  final String tagline;
  final String address;
  final String phone;
  final String currency;
  final String currencySymbol;
  final String? logoUrl;
  final String primaryColor;
  final String accentColor;

  const BrandingModel({
    this.restaurantName = 'Wood Natural Bar',
    this.tagline = 'Fresh & Natural',
    this.address = '',
    this.phone = '',
    this.currency = 'USD',
    this.currencySymbol = '\$',
    this.logoUrl,
    this.primaryColor = '#2E7D32',
    this.accentColor = '#FF6F00',
  });

  factory BrandingModel.fromJson(Map<String, dynamic> json) => BrandingModel(
        restaurantName: json['restaurant_name'] ?? 'Wood Natural Bar',
        tagline: json['tagline'] ?? 'Fresh & Natural',
        address: json['address'] ?? '',
        phone: json['phone'] ?? '',
        currency: json['currency'] ?? 'USD',
        currencySymbol: json['currency_symbol'] ?? '\$',
        logoUrl: json['logo_url'],
        primaryColor: json['primary_color'] ?? '#2E7D32',
        accentColor: json['accent_color'] ?? '#FF6F00',
      );

  Color get primaryColorValue {
    try {
      return Color(int.parse(primaryColor.replaceFirst('#', '0xFF')));
    } catch (_) {
      return const Color(0xFF2E7D32);
    }
  }

  Color get accentColorValue {
    try {
      return Color(int.parse(accentColor.replaceFirst('#', '0xFF')));
    } catch (_) {
      return const Color(0xFFFF6F00);
    }
  }
}

// ─────────────────── DASHBOARD STATS ───────────────────

class DashboardStats {
  final double todayRevenue;
  final int todayOrders;
  final int todayCovers;
  final int activeTables;
  final int freeTables;
  final int pendingKitchenItems;
  final int lowStockAlerts;
  final int openReservations;

  const DashboardStats({
    this.todayRevenue = 0,
    this.todayOrders = 0,
    this.todayCovers = 0,
    this.activeTables = 0,
    this.freeTables = 0,
    this.pendingKitchenItems = 0,
    this.lowStockAlerts = 0,
    this.openReservations = 0,
  });

  factory DashboardStats.fromJson(Map<String, dynamic> json) => DashboardStats(
        todayRevenue: (json['today_revenue'] ?? 0).toDouble(),
        todayOrders: json['today_orders'] ?? 0,
        todayCovers: json['today_covers'] ?? 0,
        activeTables: json['active_tables'] ?? 0,
        freeTables: json['free_tables'] ?? 0,
        pendingKitchenItems: json['pending_kitchen_items'] ?? 0,
        lowStockAlerts: json['low_stock_alerts'] ?? 0,
        openReservations: json['open_reservations'] ?? 0,
      );
}
