import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/providers.dart';
import '../../../data/datasources/api_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/models.dart';

class TableDetailScreen extends ConsumerStatefulWidget {
  final int tableId;
  const TableDetailScreen({super.key, required this.tableId});
  @override
  ConsumerState<TableDetailScreen> createState() => _TableDetailScreenState();
}

class _TableDetailScreenState extends ConsumerState<TableDetailScreen> {
  TableModel? _table;
  List<OrderModel> _orders = [];
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final tablesAsync = ref.read(tablesProvider);
      final tables = tablesAsync.value ?? await ref.read(apiProvider).getTables();
      final table = tables.firstWhere((t) => t.id == widget.tableId,
          orElse: () => throw Exception('Table not found'));
      final orders = await ref.read(apiProvider).getOrders(
          status: null, activeOnly: false, limit: 20);
      final tableOrders = orders.where((o) => o.tableId == widget.tableId).toList();
      setState(() { _table = table; _orders = tableOrders; _loading = false; });
    } catch (_) { setState(() => _loading = false); }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (_table == null) return Scaffold(appBar: AppBar(), body: const Center(child: Text('Table not found')));
    final table = _table!;

    return Scaffold(
      appBar: AppBar(
        title: Text(table.displayName),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Table info card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      width: 64, height: 64,
                      decoration: BoxDecoration(
                        color: table.statusColor.withOpacity(0.1),
                        shape: table.shape == 'circle' ? BoxShape.circle : BoxShape.rectangle,
                        borderRadius: table.shape == 'circle' ? null : BorderRadius.circular(12),
                        border: Border.all(color: table.statusColor, width: 2),
                      ),
                      child: Icon(Icons.table_restaurant, color: table.statusColor, size: 32),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(table.displayName,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                          if (table.section != null)
                            Text(table.section!.name,
                              style: const TextStyle(color: Colors.grey)),
                          Row(
                            children: [
                              const Icon(Icons.people_outline, size: 14, color: Colors.grey),
                              const SizedBox(width: 4),
                              Text('${table.capacity} seats',
                                style: const TextStyle(color: Colors.grey, fontSize: 13)),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: table.statusColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(table.status.toUpperCase(),
                        style: TextStyle(
                          color: table.statusColor, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Actions
            if (table.isFree)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => context.go('/orders/new',
                      extra: {'table_id': table.id}),
                  icon: const Icon(Icons.add),
                  label: Text('Open Order for ${table.displayName}'),
                ),
              ),
            if (table.isOccupied && table.activeOrderId != null)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => context.go('/orders/${table.activeOrderId}'),
                  icon: const Icon(Icons.receipt),
                  label: const Text('View Active Order'),
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.accent),
                ),
              ),
            const SizedBox(height: 20),

            // Order history
            const Text('Order History',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 10),
            if (_orders.isEmpty)
              const Center(child: Text('No orders for this table',
                style: TextStyle(color: Colors.grey)))
            else
              ..._orders.map((o) => Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(
                      color: o.statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(child: Icon(Icons.receipt, color: o.statusColor, size: 18)),
                  ),
                  title: Text(o.orderNumber),
                  subtitle: Text('${o.totalItems} items • ${o.statusLabel}'),
                  trailing: Text('\$${o.totalAmount.toStringAsFixed(2)}',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                  onTap: () => context.go('/orders/${o.id}'),
                ),
              )),
          ],
        ),
      ),
    );
  }
}
