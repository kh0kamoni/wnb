import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/providers.dart';
import '../../../data/datasources/api_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/models.dart';
import '../../../core/constants/app_constants.dart';
import '../../../data/datasources/websocket_service.dart';

class AdminDashboardScreen extends ConsumerWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(dashboardProvider);
    final user = ref.watch(authProvider).user;

    return Scaffold(
      appBar: AppBar(title: const Text('Admin Dashboard')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Stats overview
            stats.when(
              data: (s) => GridView.count(
                crossAxisCount: 4,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1.6,
                children: [
                  _statCard('Today Revenue', '\$${s.todayRevenue.toStringAsFixed(2)}',
                    Icons.attach_money, Colors.green),
                  _statCard('Orders', '${s.todayOrders}',
                    Icons.receipt_outlined, Colors.blue),
                  _statCard('Active Tables', '${s.activeTables}',
                    Icons.table_restaurant, Colors.orange),
                  _statCard('Kitchen Queue', '${s.pendingKitchenItems} items',
                    Icons.kitchen, s.pendingKitchenItems > 5 ? Colors.red : Colors.purple),
                ],
              ),
              loading: () => const LinearProgressIndicator(),
              error: (_, __) => const SizedBox(),
            ),
            const SizedBox(height: 28),

            // Management sections
            const Text('Management',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            GridView.count(
              crossAxisCount: 3,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 1.4,
              children: [
                _mgmtCard(context, 'Users', Icons.people_outlined,
                  Colors.indigo, '/admin/users',
                  subtitle: 'Staff accounts & roles'),
                _mgmtCard(context, 'Menu', Icons.restaurant_menu,
                  Colors.teal, '/menu',
                  subtitle: 'Items, categories & modifiers'),
                _mgmtCard(context, 'Tables', Icons.table_restaurant,
                  Colors.green, '/tables',
                  subtitle: 'Floor plan & sections'),
                _mgmtCard(context, 'Inventory', Icons.inventory_2_outlined,
                  Colors.orange, '/admin/inventory',
                  subtitle: 'Stock & ingredients'),
                _mgmtCard(context, 'Reports', Icons.bar_chart,
                  Colors.purple, '/reports',
                  subtitle: 'Sales & analytics'),
                _mgmtCard(context, 'Reservations', Icons.calendar_today,
                  Colors.blue, '/reservations',
                  subtitle: 'Bookings & schedules'),
                _mgmtCard(context, 'Printers', Icons.print_outlined,
                  Colors.brown, '/admin/printers',
                  subtitle: 'Printer configuration'),
                _mgmtCard(context, 'Branding', Icons.palette_outlined,
                  Colors.pink, '/admin/branding',
                  subtitle: 'Logo, colors & settings'),
                _mgmtCard(context, 'Settings', Icons.settings_outlined,
                  Colors.grey, '/settings',
                  subtitle: 'System configuration'),
              ],
            ),

            const SizedBox(height: 28),
            // Quick actions
            const Text('Quick Actions',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: _quickAction(
                  context, ref,
                  'End of Day Report',
                  Icons.summarize_outlined,
                  Colors.deepPurple,
                  () => _generateEOD(context, ref),
                )),
                const SizedBox(width: 12),
                Expanded(child: _quickAction(
                  context, ref,
                  'Open Cash Drawer',
                  Icons.point_of_sale,
                  Colors.green,
                  () => ref.read(apiProvider).openCashDrawer(),
                )),
                const SizedBox(width: 12),
                Expanded(child: _quickAction(
                  context, ref,
                  'Kitchen Display',
                  Icons.kitchen,
                  Colors.orange,
                  () => context.go('/kitchen'),
                )),
              ],
            ),
          ],
        ),
      ),
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
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(icon, color: color, size: 22),
                Text(value,
                  style: TextStyle(
                    fontSize: 18, fontWeight: FontWeight.bold, color: color)),
              ],
            ),
            Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
          ],
        ),
      ),
    );
  }

  Widget _mgmtCard(BuildContext context, String title, IconData icon,
      Color color, String route, {required String subtitle}) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      elevation: 1,
      child: InkWell(
        onTap: () => context.go(route),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const Spacer(),
              Text(title,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              Text(subtitle,
                style: const TextStyle(color: Colors.grey, fontSize: 11)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _quickAction(BuildContext context, WidgetRef ref, String label,
      IconData icon, Color color, VoidCallback onTap) {
    return Material(
      color: color.withOpacity(0.1),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
          child: Row(
            children: [
              Icon(icon, color: color),
              const SizedBox(width: 8),
              Expanded(
                child: Text(label,
                  style: TextStyle(color: color, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _generateEOD(BuildContext context, WidgetRef ref) async {
    final today = DateTime.now();
    final dateStr = '${today.year}-${today.month.toString().padLeft(2,'0')}-${today.day.toString().padLeft(2,'0')}';
    try {
      final report = await ref.read(apiProvider).generateEndOfDayReport(dateStr);
      if (context.mounted) {
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('End of Day Report'),
            content: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Date: $dateStr', style: const TextStyle(fontWeight: FontWeight.bold)),
                  const Divider(),
                  _reportRow('Total Orders', '${report['total_orders']}'),
                  _reportRow('Total Revenue', '\$${report['total_revenue']}'),
                  _reportRow('Tax Collected', '\$${report['total_tax']}'),
                  _reportRow('Service Charges', '\$${report['total_service_charge']}'),
                  _reportRow('Discounts Given', '\$${report['total_discounts']}'),
                  const Divider(),
                  _reportRow('Cash', '\$${report['cash_revenue']}'),
                  _reportRow('Card', '\$${report['card_revenue']}'),
                  _reportRow('Mobile', '\$${report['mobile_revenue']}'),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error: $e'), backgroundColor: Colors.red));
      }
    }
  }

  Widget _reportRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
