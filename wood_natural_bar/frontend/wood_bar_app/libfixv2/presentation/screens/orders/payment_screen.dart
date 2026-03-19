import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/providers.dart';
import '../../../data/models/models.dart';
import '../../../data/datasources/api_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/app_constants.dart';
import '../../../data/datasources/websocket_service.dart';

class PaymentScreen extends ConsumerStatefulWidget {
  final int orderId;
  const PaymentScreen({super.key, required this.orderId});

  @override
  ConsumerState<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends ConsumerState<PaymentScreen> {
  OrderModel? _order;
  bool _loading = true;
  bool _processing = false;

  // Payment state
  final List<Map<String, dynamic>> _payments = [];
  String _selectedMethod = 'cash';
  final _amountCtrl = TextEditingController();
  bool _splitMode = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final order = await ref.read(apiProvider).getOrder(widget.orderId);
    setState(() {
      _order = order;
      _loading = false;
      if (!_splitMode) {
        _amountCtrl.text = order.totalAmount.toStringAsFixed(2);
      }
    });
  }

  double get _totalPaid => _payments.fold(0.0, (s, p) => s + (p['amount'] as double));
  double get _remaining => (_order?.totalAmount ?? 0) - _totalPaid;
  double get _change => _totalPaid > (_order?.totalAmount ?? 0)
      ? _totalPaid - (_order?.totalAmount ?? 0)
      : 0;

  void _addPayment() {
    final amount = double.tryParse(_amountCtrl.text);
    if (amount == null || amount <= 0) return;
    setState(() {
      _payments.add({'method': _selectedMethod, 'amount': amount});
      _amountCtrl.text = _remaining > 0 ? _remaining.toStringAsFixed(2) : '0.00';
    });
  }

  Future<void> _processPayment() async {
    if (_order == null) return;
    final paymentsToSend = _payments.isEmpty
        ? [{'method': _selectedMethod, 'amount': _order!.totalAmount}]
        : _payments;

    if (_remaining > 0.01 && _payments.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Total payment is less than order total'),
        backgroundColor: Colors.red,
      ));
      return;
    }

    setState(() => _processing = true);
    try {
      await ref.read(apiProvider).payOrder(_order!.id, paymentsToSend);
      ref.read(tablesProvider.notifier).load();

      // Open cash drawer if cash payment
      if (paymentsToSend.any((p) => p['method'] == 'cash')) {
        await ref.read(apiProvider).openCashDrawer();
      }

      if (mounted) {
        // Show success then navigate
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => _PaymentSuccessDialog(
            change: _change,
            onDone: () {
              Navigator.pop(context);
              context.go('/tables');
            },
            onPrintReceipt: () async {
              Navigator.pop(context);
              await ref.read(apiProvider).printReceipt(_order!.id);
              if (mounted) context.go('/tables');
            },
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Payment failed: $e'),
          backgroundColor: Colors.red,
        ));
      }
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (_order == null) return const Scaffold(body: Center(child: Text('Order not found')));
    final order = _order!;

    return Scaffold(
      appBar: AppBar(
        title: Text('Payment — ${order.orderNumber}'),
        actions: [
          TextButton.icon(
            onPressed: () => setState(() {
              _splitMode = !_splitMode;
              _payments.clear();
            }),
            icon: Icon(_splitMode ? Icons.payment : Icons.call_split,
              color: Colors.white),
            label: Text(_splitMode ? 'Simple' : 'Split',
              style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
      body: Row(
        children: [
          // Left: Order Summary
          Expanded(
            flex: 2,
            child: Container(
              color: Colors.grey[50],
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Order Summary',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  Expanded(
                    child: ListView.builder(
                      itemCount: order.activeItems.length,
                      itemBuilder: (_, i) {
                        final item = order.activeItems[i];
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            children: [
                              SizedBox(
                                width: 28,
                                child: Text('${item.quantity}x',
                                  style: const TextStyle(color: Colors.grey)),
                              ),
                              const SizedBox(width: 8),
                              Expanded(child: Text(item.menuItem?.name ?? '')),
                              Text('\$${item.lineTotal.toStringAsFixed(2)}'),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                  const Divider(),
                  _billRow('Subtotal', '\$${order.subtotal.toStringAsFixed(2)}'),
                  if (order.discountAmount > 0)
                    _billRow('Discount', '-\$${order.discountAmount.toStringAsFixed(2)}',
                      color: Colors.green),
                  _billRow('Tax', '\$${order.taxAmount.toStringAsFixed(2)}'),
                  _billRow('Service Charge', '\$${order.serviceChargeAmount.toStringAsFixed(2)}'),
                  const Divider(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('TOTAL DUE',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      Text('\$${order.totalAmount.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 22,
                          color: AppColors.primary)),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Right: Payment input
          Expanded(
            flex: 3,
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_splitMode ? 'Split Payment' : 'Payment Method',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),

                  // Method selector
                  Row(
                    children: ['cash', 'card', 'mobile', 'complimentary']
                        .map((m) => Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: _methodButton(m),
                          ),
                        ))
                        .toList(),
                  ),
                  const SizedBox(height: 20),

                  // Amount input
                  TextField(
                    controller: _amountCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                    decoration: InputDecoration(
                      labelText: _splitMode ? 'Payment Amount' : 'Amount Tendered',
                      prefixText: '\$ ',
                      prefixStyle: const TextStyle(fontSize: 24, fontWeight: FontWeight.w300),
                    ),
                  ),

                  // Quick amount buttons
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      if (order.totalAmount > 0)
                        ...[order.totalAmount, 20, 50, 100]
                            .where((v) => v >= order.totalAmount || v == order.totalAmount)
                            .take(4)
                            .map((v) => ActionChip(
                              label: Text('\$${v.toStringAsFixed(0)}'),
                              onPressed: () => _amountCtrl.text = v.toStringAsFixed(2),
                            )),
                    ],
                  ),

                  if (_splitMode) ...[
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _addPayment,
                        icon: const Icon(Icons.add),
                        label: const Text('Add Payment'),
                      ),
                    ),
                    if (_payments.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      const Text('Payments Added:',
                        style: TextStyle(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      ..._payments.asMap().entries.map((e) => ListTile(
                        dense: true,
                        leading: _methodIcon(e.value['method']),
                        title: Text(e.value['method'].toString().toUpperCase()),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('\$${(e.value['amount'] as double).toStringAsFixed(2)}',
                              style: const TextStyle(fontWeight: FontWeight.bold)),
                            IconButton(
                              icon: const Icon(Icons.close, size: 16),
                              onPressed: () => setState(() => _payments.removeAt(e.key)),
                            ),
                          ],
                        ),
                      )),
                      const Divider(),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Remaining: \$${_remaining.toStringAsFixed(2)}',
                            style: TextStyle(
                              color: _remaining > 0 ? Colors.red : Colors.green,
                              fontWeight: FontWeight.bold)),
                          if (_change > 0)
                            Text('Change: \$${_change.toStringAsFixed(2)}',
                              style: const TextStyle(
                                color: Colors.green, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ],
                  ],

                  if (!_splitMode && _selectedMethod == 'cash') ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Change Due:',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                          Text(
                            '\$${((double.tryParse(_amountCtrl.text) ?? 0) - order.totalAmount).clamp(0, double.infinity).toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontSize: 20, fontWeight: FontWeight.bold,
                              color: Colors.green)),
                        ],
                      ),
                    ),
                  ],

                  const Spacer(),

                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton.icon(
                      onPressed: _processing ? null : _processPayment,
                      icon: _processing
                          ? const SizedBox(
                              width: 20, height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.check_circle),
                      label: Text(_processing
                          ? 'Processing...'
                          : 'Confirm Payment • \$${order.totalAmount.toStringAsFixed(2)}',
                        style: const TextStyle(fontSize: 16)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.accent,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _methodButton(String method) {
    final selected = _selectedMethod == method;
    final icons = {
      'cash': Icons.money,
      'card': Icons.credit_card,
      'mobile': Icons.phone_android,
      'complimentary': Icons.card_giftcard,
    };
    return Material(
      color: selected ? AppColors.primary : Colors.white,
      borderRadius: BorderRadius.circular(10),
      elevation: selected ? 0 : 1,
      child: InkWell(
        onTap: () => setState(() => _selectedMethod = method),
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: selected
                ? null
                : Border.all(color: Colors.grey[300]!),
          ),
          child: Column(
            children: [
              Icon(icons[method] ?? Icons.payment,
                color: selected ? Colors.white : Colors.grey),
              const SizedBox(height: 4),
              Text(method[0].toUpperCase() + method.substring(1),
                style: TextStyle(
                  fontSize: 11, fontWeight: FontWeight.w600,
                  color: selected ? Colors.white : Colors.grey)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _methodIcon(String method) {
    final icons = {
      'cash': Icons.money,
      'card': Icons.credit_card,
      'mobile': Icons.phone_android,
      'complimentary': Icons.card_giftcard,
    };
    return Icon(icons[method] ?? Icons.payment, size: 20);
  }

  Widget _billRow(String label, String value, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 13)),
          Text(value, style: TextStyle(fontSize: 13, color: color)),
        ],
      ),
    );
  }
}

class _PaymentSuccessDialog extends StatelessWidget {
  final double change;
  final VoidCallback onDone;
  final VoidCallback onPrintReceipt;

  const _PaymentSuccessDialog({
    required this.change, required this.onDone, required this.onPrintReceipt,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72, height: 72,
              decoration: const BoxDecoration(
                color: Color(0xFF43A047), shape: BoxShape.circle),
              child: const Icon(Icons.check, color: Colors.white, size: 40),
            ),
            const SizedBox(height: 20),
            const Text('Payment Successful!',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            if (change > 0) ...[
              const Text('Change Due:', style: TextStyle(color: Colors.grey)),
              Text('\$${change.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: 32, fontWeight: FontWeight.bold, color: Colors.green)),
            ],
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onPrintReceipt,
                    icon: const Icon(Icons.print),
                    label: const Text('Print Receipt'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: onDone,
                    icon: const Icon(Icons.check),
                    label: const Text('Done'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
