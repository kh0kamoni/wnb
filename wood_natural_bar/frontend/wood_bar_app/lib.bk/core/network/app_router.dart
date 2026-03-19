// import 'package:flutter/material.dart';
// import 'package:go_router/go_router.dart';
// import 'package:flutter_riverpod/flutter_riverpod.dart';
// import '../providers/providers.dart';
// import '../screens/auth/login_screen.dart';
// import '../screens/auth/server_setup_screen.dart';
// import '../screens/auth/pin_login_screen.dart';
// import '../screens/home/home_screen.dart';
// import '../screens/tables/floor_plan_screen.dart';
// import '../screens/tables/table_detail_screen.dart';
// import '../screens/tables/floor_plan_editor_screen.dart';
// import '../screens/orders/new_order_screen.dart';
// import '../screens/orders/order_detail_screen.dart';
// import '../screens/orders/order_list_screen.dart';
// import '../screens/orders/payment_screen.dart';
// import '../screens/menu/menu_management_screen.dart';
// import '../screens/menu/menu_item_form_screen.dart';
// import '../screens/kitchen/kitchen_display_screen.dart';
// import '../screens/cashier/cashier_screen.dart';
// import '../screens/admin/admin_dashboard_screen.dart';
// import '../screens/admin/user_management_screen.dart';
// import '../screens/admin/user_form_screen.dart';
// import '../screens/admin/inventory_screen.dart';
// import '../screens/admin/printer_settings_screen.dart';
// import '../screens/admin/branding_settings_screen.dart';
// import '../screens/reports/reports_screen.dart';
// import '../screens/reservations/reservations_screen.dart';
// import '../screens/settings/settings_screen.dart';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../presentation/providers/providers.dart';
import '../../presentation/screens/auth/login_screen.dart';
import '../../presentation/screens/auth/server_setup_screen.dart';
import '../../presentation/screens/auth/pin_login_screen.dart';
import '../../presentation/screens/home/home_screen.dart';
import '../../presentation/screens/tables/floor_plan_screen.dart';
import '../../presentation/screens/tables/table_detail_screen.dart';
import '../../presentation/screens/tables/floor_plan_editor_screen.dart';
import '../../presentation/screens/orders/new_order_screen.dart';
import '../../presentation/screens/orders/order_detail_screen.dart';
import '../../presentation/screens/orders/order_list_screen.dart';
import '../../presentation/screens/orders/payment_screen.dart';
import '../../presentation/screens/menu/menu_management_screen.dart';
import '../../presentation/screens/menu/menu_item_form_screen.dart';
import '../../presentation/screens/kitchen/kitchen_display_screen.dart';
import '../../presentation/screens/cashier/cashier_screen.dart';
import '../../presentation/screens/admin/admin_dashboard_screen.dart';
import '../../presentation/screens/admin/user_management_screen.dart';
import '../../presentation/screens/admin/user_form_screen.dart';
import '../../presentation/screens/admin/inventory_screen.dart';
import '../../presentation/screens/admin/printer_settings_screen.dart';
import '../../presentation/screens/admin/branding_settings_screen.dart';
import '../../presentation/screens/reports/reports_screen.dart';
import '../../presentation/screens/reservations/reservations_screen.dart';
import '../../presentation/screens/settings/settings_screen.dart';


final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authProvider);

  return GoRouter(
    initialLocation: '/setup',
    redirect: (context, state) {
      final isLoggedIn = authState.isAuthenticated;
      final isAuthRoute = state.matchedLocation.startsWith('/auth') ||
          state.matchedLocation == '/setup';

      if (!isLoggedIn && !isAuthRoute) return '/auth/login';
      if (isLoggedIn && isAuthRoute) {
        // Route to role-appropriate home
        final user = authState.user;
        if (user?.isKitchen == true) return '/kitchen';
        if (user?.isBar == true) return '/kitchen';
        if (user?.isCashier == true) return '/cashier';
        return '/home';
      }
      return null;
    },
    routes: [
      // ─── SETUP ───
      GoRoute(
        path: '/setup',
        builder: (ctx, state) => const ServerSetupScreen(),
      ),

      // ─── AUTH ───
      GoRoute(
        path: '/auth/login',
        builder: (ctx, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/auth/pin',
        builder: (ctx, state) => const PinLoginScreen(),
      ),

      // ─── MAIN HOME ───
      GoRoute(
        path: '/home',
        builder: (ctx, state) => const HomeScreen(),
      ),

      // ─── FLOOR PLAN ───
      GoRoute(
        path: '/tables',
        builder: (ctx, state) => const FloorPlanScreen(),
        routes: [
          GoRoute(
            path: 'editor',
            builder: (ctx, state) => const FloorPlanEditorScreen(),
          ),
          GoRoute(
            path: ':tableId',
            builder: (ctx, state) => TableDetailScreen(
              tableId: int.parse(state.pathParameters['tableId']!),
            ),
          ),
        ],
      ),

      // ─── ORDERS ───
      GoRoute(
        path: '/orders',
        builder: (ctx, state) => const OrderListScreen(),
        routes: [
          GoRoute(
            path: 'new',
            builder: (ctx, state) {
              final extra = state.extra as Map<String, dynamic>?;
              return NewOrderScreen(
                tableId: extra?['table_id'],
                existingOrderId: extra?['order_id'],
              );
            },
          ),
          GoRoute(
            path: ':orderId',
            builder: (ctx, state) => OrderDetailScreen(
              orderId: int.parse(state.pathParameters['orderId']!),
            ),
          ),
          GoRoute(
            path: ':orderId/pay',
            builder: (ctx, state) => PaymentScreen(
              orderId: int.parse(state.pathParameters['orderId']!),
            ),
          ),
        ],
      ),

      // ─── KITCHEN ───
      GoRoute(
        path: '/kitchen',
        builder: (ctx, state) => const KitchenDisplayScreen(),
      ),

      // ─── CASHIER ───
      GoRoute(
        path: '/cashier',
        builder: (ctx, state) => const CashierScreen(),
      ),

      // ─── MENU MANAGEMENT ───
      GoRoute(
        path: '/menu',
        builder: (ctx, state) => const MenuManagementScreen(),
        routes: [
          GoRoute(
            path: 'new',
            builder: (ctx, state) => const MenuItemFormScreen(),
          ),
          GoRoute(
            path: ':itemId/edit',
            builder: (ctx, state) => MenuItemFormScreen(
              itemId: int.parse(state.pathParameters['itemId']!),
            ),
          ),
        ],
      ),

      // ─── ADMIN ───
      GoRoute(
        path: '/admin',
        builder: (ctx, state) => const AdminDashboardScreen(),
        routes: [
          GoRoute(
            path: 'users',
            builder: (ctx, state) => const UserManagementScreen(),
            routes: [
              GoRoute(
                path: 'new',
                builder: (ctx, state) => const UserFormScreen(),
              ),
              GoRoute(
                path: ':userId/edit',
                builder: (ctx, state) => UserFormScreen(
                  userId: int.parse(state.pathParameters['userId']!),
                ),
              ),
            ],
          ),
          GoRoute(
            path: 'inventory',
            builder: (ctx, state) => const InventoryScreen(),
          ),
          GoRoute(
            path: 'printers',
            builder: (ctx, state) => const PrinterSettingsScreen(),
          ),
          GoRoute(
            path: 'branding',
            builder: (ctx, state) => const BrandingSettingsScreen(),
          ),
          GoRoute(
            path: 'reports',
            builder: (ctx, state) => const ReportsScreen(),
          ),
          GoRoute(
            path: 'reservations',
            builder: (ctx, state) => const ReservationsScreen(),
          ),
        ],
      ),

      // ─── SETTINGS ───
      GoRoute(
        path: '/settings',
        builder: (ctx, state) => const SettingsScreen(),
      ),

      // ─── REPORTS ───
      GoRoute(
        path: '/reports',
        builder: (ctx, state) => const ReportsScreen(),
      ),

      // ─── RESERVATIONS ───
      GoRoute(
        path: '/reservations',
        builder: (ctx, state) => const ReservationsScreen(),
      ),
    ],
  );
});
