import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/providers.dart';
import '../../data/datasources/api_service.dart';
import '../../data/models/models.dart';
import '../../core/theme/app_theme.dart';

class OrderListScreen extends ConsumerStatefulWidget {
  const OrderListScreen({super.key});
  @override
  ConsumerState<OrderListScreen> createState() => _OrderListScreenState();
}

class _OrderListScreenState extends ConsumerState<OrderListScreen> {
  String _statusFilter = 'active';
  List<OrderModel> _orders = [];
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final orders = await ref.read(apiProvider).getOrders(
        activeOnly: _statusFilter == 'active',
        status: _statusFilter == 'active' ? null : _statusFilter,
        limit: 100,
      );
      setState(() { _orders = orders; _loading = false; });
    } catch (_) { setState(() => _loading = false); }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Orders'),
        actions: [IconButton(icon: const Icon(Icons.refresh), onPressed: _load)],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Row(
              children: ['active','sent','in_progress','ready','paid','cancelled']
                .map((s) => Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(s.replaceAll('_',' ').toUpperCase(), style: const TextStyle(fontSize: 11)),
                    selected: _statusFilter == s,
                    selectedColor: Colors.white24,
                    checkmarkColor: Colors.white,
                    onSelected: (_) { setState(() => _statusFilter = s); _load(); },
                  ),
                )).toList(),
            ),
          ),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _orders.isEmpty
              ? const Center(child: Text('No orders found'))
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: _orders.length,
                  itemBuilder: (_, i) {
                    final o = _orders[i];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: Container(
                          width: 40, height: 40,
                          decoration: BoxDecoration(
                            color: o.statusColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Center(child: Text(
                            o.table?.number ?? o.orderType.substring(0,1).toUpperCase(),
                            style: TextStyle(fontWeight: FontWeight.bold, color: o.statusColor),
                          )),
                        ),
                        title: Text(o.orderNumber, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text('${o.totalItems} items • ${o.orderType.replaceAll('_',' ')}'),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text('\$${o.totalAmount.toStringAsFixed(2)}',
                              style: const TextStyle(fontWeight: FontWeight.bold)),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: o.statusColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(o.statusLabel,
                                style: TextStyle(fontSize: 10, color: o.statusColor, fontWeight: FontWeight.w600)),
                            ),
                          ],
                        ),
                        onTap: () => context.go('/orders/${o.id}'),
                      ),
                    );
                  },
                ),
    );
  }
}
