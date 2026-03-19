import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/models.dart';
import '../../core/constants/app_constants.dart';

final apiServiceProvider = Provider<ApiService>((ref) => ApiService());

class ApiService {
  late Dio _dio;
  final _storage = const FlutterSecureStorage();
  String _baseUrl = AppConstants.defaultBaseUrl;

  ApiService() {
    _dio = Dio(BaseOptions(
      connectTimeout: const Duration(milliseconds: AppConstants.connectionTimeout),
      receiveTimeout: const Duration(milliseconds: AppConstants.receiveTimeout),
      headers: {'Content-Type': 'application/json'},
    ));
    _setupInterceptors();
  }

  void setBaseUrl(String url) {
    _baseUrl = url;
    _dio.options.baseUrl = url + AppConstants.apiVersion;
  }

  void _setupInterceptors() {
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await _storage.read(key: AppConstants.accessTokenKey);
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
        onError: (error, handler) async {
          if (error.response?.statusCode == 401) {
            // Try refresh
            final refreshed = await _refreshToken();
            if (refreshed) {
              // Retry
              final token = await _storage.read(key: AppConstants.accessTokenKey);
              error.requestOptions.headers['Authorization'] = 'Bearer $token';
              final response = await _dio.fetch(error.requestOptions);
              return handler.resolve(response);
            }
          }
          handler.next(error);
        },
      ),
    );
  }

  Future<bool> _refreshToken() async {
    try {
      final refreshToken = await _storage.read(key: AppConstants.refreshTokenKey);
      if (refreshToken == null) return false;

      final response = await Dio().post(
        '$_baseUrl${AppConstants.apiVersion}/auth/refresh',
        data: {'refresh_token': refreshToken},
      );

      await _storage.write(
        key: AppConstants.accessTokenKey,
        value: response.data['access_token'],
      );
      await _storage.write(
        key: AppConstants.refreshTokenKey,
        value: response.data['refresh_token'],
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  String get baseUrl => _baseUrl;
  String get apiUrl => _baseUrl + AppConstants.apiVersion;

  // ─── AUTH ───

  Future<AuthResponse> login(String username, String password) async {
    final res = await _dio.post('$apiUrl/auth/login',
        data: {'username': username, 'password': password});
    final auth = AuthResponse.fromJson(res.data);
    await _storage.write(key: AppConstants.accessTokenKey, value: auth.accessToken);
    await _storage.write(key: AppConstants.refreshTokenKey, value: auth.refreshToken);
    return auth;
  }

  Future<AuthResponse> pinLogin(String pin) async {
    final res = await _dio.post('$apiUrl/auth/pin-login', data: {'pin_code': pin});
    final auth = AuthResponse.fromJson(res.data);
    await _storage.write(key: AppConstants.accessTokenKey, value: auth.accessToken);
    await _storage.write(key: AppConstants.refreshTokenKey, value: auth.refreshToken);
    return auth;
  }

  Future<void> logout() async {
    await _storage.delete(key: AppConstants.accessTokenKey);
    await _storage.delete(key: AppConstants.refreshTokenKey);
  }

  Future<UserModel> getMe() async {
    final res = await _dio.get('$apiUrl/auth/me');
    return UserModel.fromJson(res.data);
  }

  // ─── SETTINGS ───

  Future<BrandingModel> getPublicSettings() async {
    final res = await _dio.get('$apiUrl/settings/public');
    return BrandingModel.fromJson(res.data);
  }

  Future<Map<String, dynamic>> getAllSettings() async {
    final res = await _dio.get('$apiUrl/settings/');
    return Map<String, dynamic>.from(res.data);
  }

  Future<void> updateBranding(Map<String, dynamic> data) async {
    await _dio.put('$apiUrl/settings/branding', data: data);
  }

  // ─── MENU ───

  Future<List<CategoryModel>> getCategories() async {
    final res = await _dio.get('$apiUrl/menu/categories');
    return (res.data as List).map((c) => CategoryModel.fromJson(c)).toList();
  }

  Future<List<MenuItemModel>> getMenuItems({int? categoryId, String? search}) async {
    final res = await _dio.get('$apiUrl/menu/items', queryParameters: {
      if (categoryId != null) 'category_id': categoryId,
      if (search != null) 'search': search,
    });
    return (res.data as List).map((i) => MenuItemModel.fromJson(i)).toList();
  }

  Future<MenuItemModel> createMenuItem(Map<String, dynamic> data) async {
    final res = await _dio.post('$apiUrl/menu/items', data: data);
    return MenuItemModel.fromJson(res.data);
  }

  Future<MenuItemModel> updateMenuItem(int id, Map<String, dynamic> data) async {
    final res = await _dio.patch('$apiUrl/menu/items/$id', data: data);
    return MenuItemModel.fromJson(res.data);
  }

  Future<void> toggleItemAvailability(int id) async {
    await _dio.patch('$apiUrl/menu/items/$id/availability');
  }

  Future<void> uploadMenuItemImage(int id, List<int> bytes, String filename) async {
    final formData = FormData.fromMap({
      'file': MultipartFile.fromBytes(bytes, filename: filename),
    });
    await _dio.post('$apiUrl/menu/items/$id/image', data: formData);
  }

  // ─── TABLES ───

  Future<List<TableModel>> getTables() async {
    final res = await _dio.get('$apiUrl/tables/');
    return (res.data as List).map((t) => TableModel.fromJson(t)).toList();
  }

  Future<TableModel> createTable(Map<String, dynamic> data) async {
    final res = await _dio.post('$apiUrl/tables/', data: data);
    return TableModel.fromJson(res.data);
  }

  Future<TableModel> updateTable(int id, Map<String, dynamic> data) async {
    final res = await _dio.patch('$apiUrl/tables/$id', data: data);
    return TableModel.fromJson(res.data);
  }

  Future<void> updateFloorPlan(List<Map<String, dynamic>> tables) async {
    await _dio.put('$apiUrl/tables/floor-plan', data: {'tables': tables});
  }

  Future<List<dynamic>> getSections() async {
    final res = await _dio.get('$apiUrl/tables/sections');
    return res.data;
  }

  // ─── ORDERS ───

  Future<List<OrderModel>> getOrders({
    String? status,
    bool activeOnly = false,
    int limit = 50,
  }) async {
    final res = await _dio.get('$apiUrl/orders/', queryParameters: {
      if (status != null) 'status': status,
      if (activeOnly) 'active_only': true,
      'limit': limit,
    });
    return (res.data as List).map((o) => OrderModel.fromJson(o)).toList();
  }

  Future<List<OrderModel>> getKitchenQueue() async {
    final res = await _dio.get('$apiUrl/orders/kitchen-queue');
    return (res.data as List).map((o) => OrderModel.fromJson(o)).toList();
  }

  Future<OrderModel> getOrder(int id) async {
    final res = await _dio.get('$apiUrl/orders/$id');
    return OrderModel.fromJson(res.data);
  }

  Future<OrderModel> createOrder(Map<String, dynamic> data) async {
    final res = await _dio.post('$apiUrl/orders/', data: data);
    return OrderModel.fromJson(res.data);
  }

  Future<OrderModel> addItemsToOrder(int orderId, List<Map<String, dynamic>> items) async {
    final res = await _dio.post('$apiUrl/orders/$orderId/items', data: items);
    return OrderModel.fromJson(res.data);
  }

  Future<OrderModel> updateOrderItem(int orderId, int itemId, Map<String, dynamic> data) async {
    final res = await _dio.patch('$apiUrl/orders/$orderId/items/$itemId', data: data);
    return OrderModel.fromJson(res.data);
  }

  Future<void> voidOrderItem(int orderId, int itemId, String reason) async {
    await _dio.delete('$apiUrl/orders/$orderId/items/$itemId',
        queryParameters: {'reason': reason});
  }

  Future<OrderModel> sendToKitchen(int orderId) async {
    final res = await _dio.post('$apiUrl/orders/$orderId/send-to-kitchen');
    return OrderModel.fromJson(res.data);
  }

  Future<OrderModel> payOrder(int orderId, List<Map<String, dynamic>> payments) async {
    final res = await _dio.post('$apiUrl/orders/$orderId/pay',
        data: {'order_id': orderId, 'payments': payments});
    return OrderModel.fromJson(res.data);
  }

  Future<OrderModel> applyDiscount(Map<String, dynamic> data) async {
    final res = await _dio.post('$apiUrl/orders/${data['order_id']}/apply-discount', data: data);
    return OrderModel.fromJson(res.data);
  }

  Future<OrderModel> cancelOrder(int orderId, String reason) async {
    final res = await _dio.post('$apiUrl/orders/$orderId/cancel',
        queryParameters: {'reason': reason});
    return OrderModel.fromJson(res.data);
  }

  Future<OrderModel> transferTable(int orderId, int newTableId) async {
    final res = await _dio.post('$apiUrl/orders/$orderId/transfer-table',
        queryParameters: {'new_table_id': newTableId});
    return OrderModel.fromJson(res.data);
  }

  // ─── USERS ───

  Future<List<UserModel>> getUsers() async {
    final res = await _dio.get('$apiUrl/users/');
    return (res.data as List).map((u) => UserModel.fromJson(u)).toList();
  }

  Future<UserModel> createUser(Map<String, dynamic> data) async {
    final res = await _dio.post('$apiUrl/users/', data: data);
    return UserModel.fromJson(res.data);
  }

  Future<UserModel> updateUser(int id, Map<String, dynamic> data) async {
    final res = await _dio.patch('$apiUrl/users/$id', data: data);
    return UserModel.fromJson(res.data);
  }

  // ─── INVENTORY ───

  Future<List<dynamic>> getIngredients({bool lowStockOnly = false}) async {
    final res = await _dio.get('$apiUrl/inventory/ingredients',
        queryParameters: {'low_stock_only': lowStockOnly});
    return res.data;
  }

  Future<dynamic> createIngredient(Map<String, dynamic> data) async {
    final res = await _dio.post('$apiUrl/inventory/ingredients', data: data);
    return res.data;
  }

  Future<dynamic> adjustStock(Map<String, dynamic> data) async {
    final res = await _dio.post('$apiUrl/inventory/adjust', data: data);
    return res.data;
  }

  // ─── REPORTS ───

  Future<DashboardStats> getDashboardStats() async {
    final res = await _dio.get('$apiUrl/reports/dashboard');
    return DashboardStats.fromJson(res.data);
  }

  Future<Map<String, dynamic>> getSalesReport(String startDate, String endDate) async {
    final res = await _dio.get('$apiUrl/reports/sales', queryParameters: {
      'start_date': startDate,
      'end_date': endDate,
    });
    return Map<String, dynamic>.from(res.data);
  }

  Future<dynamic> generateEndOfDayReport(String date) async {
    final res = await _dio.post('$apiUrl/reports/end-of-day',
        queryParameters: {'target_date': date});
    return res.data;
  }

  // ─── RESERVATIONS ───

  Future<List<dynamic>> getReservations({String? date}) async {
    final res = await _dio.get('$apiUrl/reservations/', queryParameters: {
      if (date != null) 'reservation_date': date,
    });
    return res.data;
  }

  Future<dynamic> createReservation(Map<String, dynamic> data) async {
    final res = await _dio.post('$apiUrl/reservations/', data: data);
    return res.data;
  }

  // ─── PRINTING ───

  Future<bool> printReceipt(int orderId, {int? printerId}) async {
    try {
      await _dio.post('$apiUrl/printers/print', data: {
        'order_id': orderId,
        if (printerId != null) 'printer_id': printerId,
        'print_type': 'receipt',
      });
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> printKitchenTicket(int orderId, {int? printerId}) async {
    try {
      await _dio.post('$apiUrl/printers/print', data: {
        'order_id': orderId,
        if (printerId != null) 'printer_id': printerId,
        'print_type': 'kitchen',
      });
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> openCashDrawer() async {
    try {
      await _dio.post('$apiUrl/printers/cash-drawer');
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<List<dynamic>> getPrinters() async {
    final res = await _dio.get('$apiUrl/printers/');
    return res.data;
  }

  Future<List<dynamic>> getDiscounts() async {
    final res = await _dio.get('$apiUrl/discounts/');
    return res.data;
  }

  // ─── SHIFTS ───

  Future<dynamic> startShift(double openingBalance) async {
    final res = await _dio.post('$apiUrl/shifts/start',
        data: {'opening_balance': openingBalance});
    return res.data;
  }

  Future<dynamic> endShift(double closingBalance, String? notes) async {
    final res = await _dio.post('$apiUrl/shifts/end',
        data: {'closing_balance': closingBalance, 'notes': notes});
    return res.data;
  }
}
