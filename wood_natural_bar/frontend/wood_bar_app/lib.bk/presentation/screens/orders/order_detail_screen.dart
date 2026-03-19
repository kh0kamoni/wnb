import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/providers.dart';
import '../../data/models/models.dart';
import '../../data/datasources/api_service.dart';
import '../../core/theme/app_theme.dart';

class OrderDetailScreen extends ConsumerStatefulWidget {
  final int orderId;
  const OrderDetailScreen({super.key, required this.orderId});

  @override
  ConsumerState<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends ConsumerState<OrderDetailScreen> {
  OrderModel? _order;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
    // Listen for realtime updates
    final ws = ref.read(wsServiceProvider);
    ws.orderUpdates.listen((msg) {
      final data = msg.data as Map<String, dynamic>;
      if (data['id'] == widget.orderId) _load();
    });
    ws.itemReady.listen((msg) {
      final data = msg.data as Map<String, dynamic>;
      if (data['order_id'] == widget.orderId) _load();
    });
    ws.orderComplete.listen((msg) {
      final data = msg.data as Map<String, dynamic>;
      if (data['id'] == widget.orderId) _load();
    });
  }

  Future<void> _load() async {
    try {
      final order = await ref.read(apiProvider).getOrder(widget.orderId);
      if (mounted) setState(() { _order = order; _loading = false; });
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;

    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (_order == null) return Scaffold(appBar: AppBar(), body: const Center(child: Text('Order not found')));

    final order = _order!;

    return Scaffold(
      appBar: AppBar(
        title: Text('Order ${order.orderNumber}'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
          PopupMenuButton<String>(
            onSelected: (v) => _handleAction(v, order),
            itemBuilder: (_) => [
              if (!order.isClosed)
                const PopupMenuItem(value: 'add_items', child: ListTile(
                  leading: Icon(Icons.add), title: Text('Add Items'), dense: true)),
              if (!order.isClosed)
                const PopupMenuItem(value: 'transfer', child: ListTile(
                  leading: Icon(Icons.swap_horiz), title: Text('Transfer Table'), dense: true)),
              const PopupMenuItem(value: 'print_kitchen', child: ListTile(
                leading: Icon(Icons.print), title: Text('Print Kitchen Ticket'), dense: true)),
              const PopupMenuItem(value: 'print_receipt', child: ListTile(
                leading: Icon(Icons.receipt), title: Text('Print Receipt'), dense: true)),
              if (!order.isClosed && user?.canManage == true)
                const PopupMenuItem(value: 'cancel', child: ListTile(
                  leading: Icon(Icons.cancel, color: Colors.red),
                  title: Text('Cancel Order', style: TextStyle(color: Colors.red)),
                  dense: true)),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // Status bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: order.statusColor.withOpacity(0.1),
            child: Row(
              children: [
                Container(
                  width: 10, height: 10,
                  decoration: BoxDecoration(
                    color: order.statusColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(order.statusLabel,
                  style: TextStyle(
                    color: order.statusColor,
                    fontWeight: FontWeight.bold)),
                const Spacer(),
                if (order.table != null)
                  Text('Table ${order.table!.number}',
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(width: 12),
                Text('${order.guestCount} guests',
                  style: const TextStyle(color: Colors.grey)),
              ],
            ),
          ),

          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Items list
                Expanded(
                  flex: 3,
                  child: ListView(
                    padding: const EdgeInsets.all(12),
                    children: [
                      // Group by course
                      ...{for (var i in order.activeItems) i.course}
                          .toList()
                          ..sort()
                          ..map((course) {
                            final courseItems = order.activeItems
                                .where((i) => i.course == course).toList();
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (order.activeItems.any((i) => i.course > 1))
                                  Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 8),
                                    child: Text('Course $course',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.grey)),
                                  ),
                                ...courseItems.map((item) => _OrderItemRow(
                                  item: item,
                                  orderId: order.id,
                                  canVoid: !order.isClosed && user?.canManage == true,
                                  onVoided: _load,
                                )),
                              ],
                            );
                          }),
                      if (order.notes?.isNotEmpty == true) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.orange.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.orange.shade200),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.notes, color: Colors.orange, size: 16),
                              const SizedBox(width: 8),
                              Expanded(child: Text(order.notes!,
                                style: const TextStyle(fontSize: 13))),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                // Right panel - summary + actions
                Container(
                  width: 240,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    border: const Border(left: BorderSide(color: Color(0xFFEEEEEE))),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Order Summary',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      const SizedBox(height: 12),
                      _summaryRow('Subtotal', '\$${order.subtotal.toStringAsFixed(2)}'),
                      if (order.discountAmount > 0)
                        _summaryRow('Discount', '-\$${order.discountAmount.toStringAsFixed(2)}',
                          color: Colors.green),
                      _summaryRow('Tax', '\$${order.taxAmount.toStringAsFixed(2)}'),
                      _summaryRow('Service', '\$${order.serviceChargeAmount.toStringAsFixed(2)}'),
                      const Divider(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Total',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                          Text('\$${order.totalAmount.toStringAsFixed(2)}',
                            style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 18,
                              color: AppColors.primary)),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // Action buttons
                      if (!order.isClosed) ...[
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: () => context.go(
                              '/orders/new',
                              extra: {'order_id': order.id}),
                            icon: const Icon(Icons.add, size: 16),
                            label: const Text('Add Items'),
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 10)),
                          ),
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: () => context.go('/orders/${order.id}/pay'),
                            icon: const Icon(Icons.payment, size: 16),
                            label: const Text('Process Payment'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.accent,
                              padding: const EdgeInsets.symmetric(vertical: 10)),
                          ),
                        ),
                      ],
                      if (order.isPaid) ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.green.shade50,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.check_circle, color: Colors.green, size: 18),
                              const SizedBox(width: 8),
                              const Expanded(
                                child: Text('PAID', style: TextStyle(
                                  color: Colors.green, fontWeight: FontWeight.bold))),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: () => _printReceipt(order.id),
                            icon: const Icon(Icons.print, size: 16),
                            label: const Text('Print Receipt'),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryRow(String label, String value, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
          Text(value, style: TextStyle(fontSize: 12, color: color)),
        ],
      ),
    );
  }

  Future<void> _printReceipt(int orderId) async {
    final success = await ref.read(apiProvider).printReceipt(orderId);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(success ? 'Receipt printed' : 'Print failed'),
        backgroundColor: success ? Colors.green : Colors.red,
      ));
    }
  }

  void _handleAction(String action, OrderModel order) async {
    switch (action) {
      case 'add_items':
        context.go('/orders/new', extra: {'order_id': order.id});
        break;
      case 'print_receipt':
        _printReceipt(order.id);
        break;
      case 'print_kitchen':
        await ref.read(apiProvider).printKitchenTicket(order.id);
        break;
      case 'cancel':
        _showCancelDialog(order);
        break;
    }
  }

  void _showCancelDialog(OrderModel order) {
    final reasonCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Cancel Order'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Please provide a reason for cancellation:'),
            const SizedBox(height: 12),
            TextField(
              controller: reasonCtrl,
              decoration: const InputDecoration(hintText: 'Reason...'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await ref.read(apiProvider).cancelOrder(
                  order.id, reasonCtrl.text);
              _load();
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Confirm Cancel'),
          ),
        ],
      ),
    );
  }
}

class _OrderItemRow extends ConsumerWidget {
  final OrderItemModel item;
  final int orderId;
  final bool canVoid;
  final VoidCallback onVoided;

  const _OrderItemRow({
    required this.item, required this.orderId,
    required this.canVoid, required this.onVoided,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isVoid = item.status == 'void' || item.status == 'cancelled';

    return Opacity(
      opacity: isVoid ? 0.4 : 1.0,
      child: Card(
        margin: const EdgeInsets.only(bottom: 6),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              // Status dot
              Container(
                width: 8, height: 8,
                decoration: BoxDecoration(
                  color: item.statusColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${item.quantity}x ${item.menuItem?.name ?? ''}',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        decoration: isVoid ? TextDecoration.lineThrough : null)),
                    if (item.modifiers.isNotEmpty)
                      Text(item.modifiers.map((m) => m['option_name']).join(', '),
                        style: const TextStyle(fontSize: 11, color: Colors.grey)),
                    if (item.notes?.isNotEmpty == true)
                      Text('⚠ ${item.notes}',
                        style: const TextStyle(fontSize: 11, color: Colors.orange)),
                  ],
                ),
              ),
              Text('\$${item.lineTotal.toStringAsFixed(2)}',
                style: const TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(width: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: item.statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(item.status.replaceAll('_', ' '),
                  style: TextStyle(
                    fontSize: 10, color: item.statusColor,
                    fontWeight: FontWeight.w600)),
              ),
              if (canVoid && !isVoid)
                IconButton(
                  icon: const Icon(Icons.remove_circle_outline,
                    color: Colors.red, size: 18),
                  onPressed: () => _showVoidDialog(context, ref),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _showVoidDialog(BuildContext context, WidgetRef ref) {
    final reasonCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Void ${item.menuItem?.name ?? 'Item'}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Provide a reason for voiding this item:'),
            const SizedBox(height: 8),
            TextField(
              controller: reasonCtrl,
              decoration: const InputDecoration(hintText: 'Void reason...'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await ref.read(apiProvider).voidOrderItem(
                  orderId, item.id, reasonCtrl.text);
              onVoided();
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Void Item'),
          ),
        ],
      ),
    );
  }
}
