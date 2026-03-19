import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/models.dart';
import '../../../core/constants/app_constants.dart';
import '../../../data/datasources/websocket_service.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;
    final stats = ref.watch(dashboardProvider);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Icon(Icons.eco_rounded, size: 24),
            const SizedBox(width: 8),
            const Text('Wood Natural Bar'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () {},
          ),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: GestureDetector(
              onTap: () => context.go('/settings'),
              child: CircleAvatar(
                backgroundColor: Colors.white24,
                child: Text(
                  (user?.fullName.isNotEmpty == true)
                      ? user!.fullName[0].toUpperCase()
                      : 'U',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Welcome header
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Good ${_greeting()},',
                        style: const TextStyle(fontSize: 14, color: Colors.grey)),
                      Text(user?.fullName ?? 'Staff',
                        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                      Container(
                        margin: const EdgeInsets.only(top: 4),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: AppColors.primary.withOpacity(0.3)),
                        ),
                        child: Text(user?.role.toUpperCase() ?? '',
                          style: TextStyle(
                            fontSize: 11, color: AppColors.primary,
                            fontWeight: FontWeight.w600, letterSpacing: 1)),
                      ),
                    ],
                  ),
                ),
                Text(DateTime.now().toString().substring(0, 10),
                  style: const TextStyle(color: Colors.grey, fontSize: 13)),
              ],
            ),
            const SizedBox(height: 24),

            // Stats cards (for managers/admin)
            if (user?.canManage == true)
              stats.when(
                data: (s) => _statsGrid(s),
                loading: () => const LinearProgressIndicator(),
                error: (_, __) => const SizedBox(),
              ),

            const SizedBox(height: 24),

            // Quick action tiles
            Text('Quick Actions',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            _buildActionGrid(context, user),
          ],
        ),
      ),
    );
  }

  Widget _statsGrid(DashboardStats stats) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("Today's Overview",
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        GridView.count(
          crossAxisCount: 4,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.5,
          children: [
            _statCard('Revenue', '\$${stats.todayRevenue.toStringAsFixed(0)}',
              Icons.attach_money, Colors.green),
            _statCard('Orders', '${stats.todayOrders}',
              Icons.receipt_outlined, Colors.blue),
            _statCard('Covers', '${stats.todayCovers}',
              Icons.people_outline, Colors.purple),
            _statCard('Kitchen', '${stats.pendingKitchenItems} pending',
              Icons.kitchen, stats.pendingKitchenItems > 0 ? Colors.orange : Colors.grey),
          ],
        ),
        if (stats.lowStockAlerts > 0) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.orange.shade200),
            ),
            child: Row(
              children: [
                const Icon(Icons.warning_amber, color: Colors.orange, size: 20),
                const SizedBox(width: 8),
                Text('${stats.lowStockAlerts} ingredients at low stock level',
                  style: const TextStyle(color: Colors.orange, fontSize: 13)),
                const Spacer(),
                TextButton(
                  onPressed: () => context.go('/admin/inventory'),
                  child: const Text('View'),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _statCard(String label, String value, IconData icon, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Icon(icon, color: color, size: 24),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value,
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
                Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionGrid(BuildContext context, UserModel? user) {
    final actions = _getActionsForRole(user);
    return GridView.count(
      crossAxisCount: MediaQuery.of(context).size.width > 600 ? 4 : 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      children: actions.map((a) => _actionTile(
        context, a['icon'] as IconData, a['label'] as String,
        a['route'] as String, a['color'] as Color,
        extra: a['extra'],
      )).toList(),
    );
  }

  List<Map<String, dynamic>> _getActionsForRole(UserModel? user) {
    final all = [
      {'icon': Icons.table_restaurant, 'label': 'Floor Plan',
        'route': '/tables', 'color': const Color(0xFF2E7D32), 'roles': ['admin','manager','waiter'], 'extra': null},
      {'icon': Icons.receipt_long, 'label': 'New Order',
        'route': '/orders/new', 'color': const Color(0xFF1565C0), 'roles': ['admin','manager','waiter','cashier'], 'extra': null},
      {'icon': Icons.list_alt, 'label': 'Orders',
        'route': '/orders', 'color': const Color(0xFF6A1B9A), 'roles': ['admin','manager','waiter','cashier'], 'extra': null},
      {'icon': Icons.kitchen, 'label': 'Kitchen Display',
        'route': '/kitchen', 'color': const Color(0xFFE65100), 'roles': ['admin','manager','kitchen','bar'], 'extra': null},
      {'icon': Icons.point_of_sale, 'label': 'Cashier',
        'route': '/cashier', 'color': const Color(0xFF00695C), 'roles': ['admin','manager','cashier'], 'extra': null},
      {'icon': Icons.restaurant_menu, 'label': 'Menu',
        'route': '/menu', 'color': const Color(0xFFAD1457), 'roles': ['admin','manager'], 'extra': null},
      {'icon': Icons.bar_chart, 'label': 'Reports',
        'route': '/reports', 'color': const Color(0xFF4527A0), 'roles': ['admin','manager'], 'extra': null},
      {'icon': Icons.calendar_today, 'label': 'Reservations',
        'route': '/reservations', 'color': const Color(0xFF0277BD), 'roles': ['admin','manager','waiter'], 'extra': null},
      {'icon': Icons.admin_panel_settings, 'label': 'Admin',
        'route': '/admin', 'color': const Color(0xFF37474F), 'roles': ['admin'], 'extra': null},
      {'icon': Icons.settings, 'label': 'Settings',
        'route': '/settings', 'color': const Color(0xFF546E7A), 'roles': ['admin','manager','waiter','cashier','kitchen','bar'], 'extra': null},
    ];

    return all.where((a) {
      final roles = a['roles'] as List<String>;
      return user == null || roles.contains(user.role);
    }).toList();
  }

  Widget _actionTile(BuildContext context, IconData icon, String label,
      String route, Color color, {dynamic extra}) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      elevation: 2,
      child: InkWell(
        onTap: () => context.go(route, extra: extra),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 52, height: 52,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: color, size: 28),
              ),
              const SizedBox(height: 12),
              Text(label,
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
            ],
          ),
        ),
      ),
    );
  }

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Morning';
    if (h < 17) return 'Afternoon';
    return 'Evening';
  }
}
