import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/providers.dart';
import '../../../data/datasources/api_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/models.dart';

class CashierScreen extends ConsumerStatefulWidget {
  const CashierScreen({super.key});
  @override
  ConsumerState<CashierScreen> createState() => _CashierScreenState();
}

class _CashierScreenState extends ConsumerState<CashierScreen> {
  List<OrderModel> _billableOrders = [];
  bool _loading = true;
  String _search = '';

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final orders = await ref.read(apiProvider).getOrders(activeOnly: true);
      setState(() {
        _billableOrders = orders
            .where((o) => !o.isClosed)
            .toList()
          ..sort((a, b) => b.openedAt.compareTo(a.openedAt));
        _loading = false;
      });
    } catch (_) { setState(() => _loading = false); }
  }

  List<OrderModel> get _filtered => _search.isEmpty
      ? _billableOrders
      : _billableOrders.where((o) =>
          o.orderNumber.toLowerCase().contains(_search.toLowerCase()) ||
          (o.table?.number ?? '').toLowerCase().contains(_search.toLowerCase()) ||
          (o.customerName ?? '').toLowerCase().contains(_search.toLowerCase())).toList();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cashier'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
          IconButton(
            icon: const Icon(Icons.point_of_sale),
            tooltip: 'Open Cash Drawer',
            onPressed: () => ref.read(apiProvider).openCashDrawer(),
          ),
        ],
      ),
      body: Column(
        children: [
          // Summary bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            color: AppColors.primary,
            child: Row(
              children: [
                _summaryChip(Icons.receipt, '${_billableOrders.length}', 'Open Orders'),
                const SizedBox(width: 20),
                _summaryChip(Icons.attach_money,
                  '\$${_billableOrders.fold(0.0, (s, o) => s + o.totalAmount).toStringAsFixed(2)}',
                  'Total Pending'),
                const Spacer(),
                ElevatedButton.icon(
                  onPressed: () => context.go('/orders/new'),
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('New Order'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: AppColors.primary,
                  ),
                ),
              ],
            ),
          ),
          // Search
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              onChanged: (v) => setState(() => _search = v),
              decoration: InputDecoration(
                hintText: 'Search by order #, table, or customer...',
                prefixIcon: const Icon(Icons.search),
                isDense: true, filled: true,
                fillColor: Colors.grey[100],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          // Orders list
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _filtered.isEmpty
                    ? const Center(child: Text('No open orders'))
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        itemCount: _filtered.length,
                        itemBuilder: (_, i) => _OrderCard(
                          order: _filtered[i],
                          onPay: () async {
                            await context.push('/orders/${_filtered[i].id}/pay');
                            _load();
                          },
                          onView: () => context.go('/orders/${_filtered[i].id}'),
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _summaryChip(IconData icon, String value, String label) {
    return Row(
      children: [
        Icon(icon, color: Colors.white70, size: 18),
        const SizedBox(width: 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(value, style: const TextStyle(
              color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
            Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11)),
          ],
        ),
      ],
    );
  }
}

class _OrderCard extends StatelessWidget {
  final OrderModel order;
  final VoidCallback onPay;
  final VoidCallback onView;
  const _OrderCard({required this.order, required this.onPay, required this.onView});

  @override
  Widget build(BuildContext context) {
    final isReady = order.isReady;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isReady
            ? const BorderSide(color: Colors.green, width: 1.5)
            : BorderSide.none,
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            // Table/order info
            Container(
              width: 52, height: 52,
              decoration: BoxDecoration(
                color: order.statusColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: Text(
                  order.table?.number ?? order.orderType.substring(0, 1).toUpperCase(),
                  style: TextStyle(
                    fontSize: 18, fontWeight: FontWeight.bold,
                    color: order.statusColor),
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(order.orderNumber,
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: order.statusColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(order.statusLabel,
                          style: TextStyle(fontSize: 10, color: order.statusColor,
                            fontWeight: FontWeight.w600)),
                      ),
                      if (isReady) ...[ 
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.green.shade50,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.check_circle, size: 12, color: Colors.green),
                              SizedBox(width: 3),
                              Text('Ready to bill',
                                style: TextStyle(fontSize: 10, color: Colors.green,
                                  fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${order.totalItems} items • ${order.table != null ? 'Table ${order.table!.number}' : order.orderType.replaceAll('_', ' ')}${order.customerName != null ? ' • ${order.customerName}' : ''}',
                    style: const TextStyle(color: Colors.grey, fontSize: 12)),
                  const SizedBox(height: 4),
                  Text(
                    'Opened ${_timeAgo(order.openedAt)}',
                    style: const TextStyle(color: Colors.grey, fontSize: 11)),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('\$${order.totalAmount.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    OutlinedButton(
                      onPressed: onView,
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: const Text('View', style: TextStyle(fontSize: 12)),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: onPay,
                      icon: const Icon(Icons.payment, size: 14),
                      label: const Text('Pay', style: TextStyle(fontSize: 12)),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        backgroundColor: AppColors.accent,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    return '${diff.inHours}h ago';
  }
}
