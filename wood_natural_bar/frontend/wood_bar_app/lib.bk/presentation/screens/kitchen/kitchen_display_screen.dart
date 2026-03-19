import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../providers/providers.dart';
import '../../data/models/models.dart';
import '../../data/datasources/api_service.dart';
import '../../data/datasources/websocket_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/constants/app_constants.dart';

class KitchenDisplayScreen extends ConsumerStatefulWidget {
  const KitchenDisplayScreen({super.key});

  @override
  ConsumerState<KitchenDisplayScreen> createState() => _KitchenDisplayScreenState();
}

class _KitchenDisplayScreenState extends ConsumerState<KitchenDisplayScreen> {
  final _audioPlayer = AudioPlayer();
  String _filter = 'all'; // all, pending, in_progress, ready

  @override
  void initState() {
    super.initState();
    WakelockPlus.enable();
    _initWebSocket();
    _startPolling();
  }

  void _initWebSocket() {
    final ws = ref.read(wsServiceProvider);
    final user = ref.read(authProvider).user;
    final serverUrl = ref.read(serverUrlProvider);
    ws.connect(serverUrl, user?.isBar == true
        ? AppConstants.wsRoleBar
        : AppConstants.wsRoleKitchen);

    ws.newOrders.listen((_) {
      _playSound();
      ref.read(kitchenQueueProvider.notifier).load();
    });
    ws.orderUpdates.listen((_) {
      ref.read(kitchenQueueProvider.notifier).load();
    });
  }

  void _startPolling() {
    // Refresh every 30 seconds as fallback
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 30));
      if (mounted) ref.read(kitchenQueueProvider.notifier).load();
      return mounted;
    });
  }

  Future<void> _playSound() async {
    try {
      await _audioPlayer.play(AssetSource(AppConstants.soundNewOrder));
    } catch (_) {}
  }

  @override
  void dispose() {
    WakelockPlus.disable();
    _audioPlayer.dispose();
    ref.read(wsServiceProvider).disconnect();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final queueAsync = ref.watch(kitchenQueueProvider);
    final user = ref.watch(authProvider).user;

    return Theme(
      data: AppTheme.kitchenTheme,
      child: Scaffold(
        backgroundColor: AppColors.kitchenBg,
        appBar: AppBar(
          backgroundColor: AppColors.kitchenBg,
          title: Row(
            children: [
              Container(
                width: 10, height: 10,
                decoration: const BoxDecoration(
                  color: Colors.green, shape: BoxShape.circle),
              ),
              const SizedBox(width: 8),
              Text(user?.isBar == true ? 'Bar Display' : 'Kitchen Display',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              const SizedBox(width: 16),
              queueAsync.when(
                data: (orders) => Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: orders.isEmpty ? Colors.grey[800] : AppColors.kitchenNew,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text('${orders.length} orders',
                    style: const TextStyle(
                      color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                ),
                loading: () => const SizedBox(),
                error: (_, __) => const SizedBox(),
              ),
            ],
          ),
          actions: [
            // Filter chips
            ...['all', 'pending', 'in_progress', 'ready'].map((f) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 8),
              child: FilterChip(
                label: Text(f == 'all' ? 'All' : f.replaceAll('_', ' ').toUpperCase(),
                  style: TextStyle(
                    fontSize: 11,
                    color: _filter == f ? Colors.white : Colors.grey)),
                selected: _filter == f,
                onSelected: (_) => setState(() => _filter = f),
                selectedColor: AppColors.kitchenNew,
                backgroundColor: AppColors.kitchenCard,
                checkmarkColor: Colors.white,
                showCheckmark: false,
                padding: const EdgeInsets.symmetric(horizontal: 8),
              ),
            )),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.refresh, color: Colors.white),
              onPressed: () => ref.read(kitchenQueueProvider.notifier).load(),
            ),
          ],
        ),
        body: queueAsync.when(
          loading: () => const Center(
            child: CircularProgressIndicator(color: Colors.white)),
          error: (e, _) => Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, color: Colors.red, size: 48),
                const SizedBox(height: 12),
                Text('$e', style: const TextStyle(color: Colors.white)),
                TextButton(
                  onPressed: () => ref.read(kitchenQueueProvider.notifier).load(),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
          data: (orders) {
            final filtered = _filterOrders(orders);
            if (filtered.isEmpty) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.check_circle_outline,
                      color: Colors.green[700], size: 80),
                    const SizedBox(height: 16),
                    const Text('All caught up!',
                      style: TextStyle(
                        color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    const Text('No pending orders',
                      style: TextStyle(color: Colors.grey, fontSize: 16)),
                  ],
                ),
              );
            }
            return GridView.builder(
              padding: const EdgeInsets.all(12),
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 320,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 0.65,
              ),
              itemCount: filtered.length,
              itemBuilder: (ctx, i) => _KitchenOrderCard(
                order: filtered[i],
                onRefresh: () => ref.read(kitchenQueueProvider.notifier).load(),
              ),
            );
          },
        ),
      ),
    );
  }

  List<OrderModel> _filterOrders(List<OrderModel> orders) {
    if (_filter == 'all') return orders;
    return orders.where((o) {
      if (_filter == 'pending') {
        return o.items.any((i) => i.status == 'pending');
      }
      if (_filter == 'in_progress') {
        return o.items.any((i) => i.status == 'in_progress');
      }
      if (_filter == 'ready') {
        return o.items.every((i) =>
          i.status == 'ready' || i.status == 'served' ||
          i.status == 'void' || i.status == 'cancelled');
      }
      return true;
    }).toList();
  }
}

class _KitchenOrderCard extends ConsumerStatefulWidget {
  final OrderModel order;
  final VoidCallback onRefresh;

  const _KitchenOrderCard({required this.order, required this.onRefresh});

  @override
  ConsumerState<_KitchenOrderCard> createState() => _KitchenOrderCardState();
}

class _KitchenOrderCardState extends ConsumerState<_KitchenOrderCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseCtrl;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    );
    // Pulse for new orders
    if (widget.order.items.every((i) => i.status == 'pending')) {
      _pulseCtrl.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  Color _cardBorderColor() {
    final statuses = widget.order.activeItems.map((i) => i.status).toSet();
    if (statuses.contains('pending')) return AppColors.kitchenNew;
    if (statuses.contains('in_progress')) return AppColors.kitchenProgress;
    return AppColors.kitchenDone;
  }

  int _elapsedMinutes() {
    final sentAt = widget.order.sentAt;
    if (sentAt == null) return 0;
    return DateTime.now().difference(sentAt).inMinutes;
  }

  @override
  Widget build(BuildContext context) {
    final order = widget.order;
    final elapsed = _elapsedMinutes();
    final isUrgent = elapsed > 15;
    final borderColor = _cardBorderColor();

    return AnimatedBuilder(
      animation: _pulseCtrl,
      builder: (_, child) => Container(
        decoration: BoxDecoration(
          color: AppColors.kitchenCard,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: borderColor.withOpacity(
              borderColor == AppColors.kitchenNew
                  ? 0.5 + 0.5 * _pulseCtrl.value
                  : 0.6),
            width: 2,
          ),
          boxShadow: isUrgent
              ? [BoxShadow(
                  color: Colors.red.withOpacity(0.3),
                  blurRadius: 12, spreadRadius: 2)]
              : null,
        ),
        child: child,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: isUrgent
                  ? Colors.red.withOpacity(0.2)
                  : borderColor.withOpacity(0.15),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            order.table != null
                                ? 'TABLE ${order.table!.number}'
                                : order.orderType.toUpperCase(),
                            style: TextStyle(
                              color: borderColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          if (isUrgent) ...[
                            const SizedBox(width: 6),
                            const Icon(Icons.warning_amber,
                              color: Colors.red, size: 16),
                          ],
                        ],
                      ),
                      Text(order.orderNumber,
                        style: TextStyle(
                          color: Colors.grey[400], fontSize: 11)),
                    ],
                  ),
                ),
                // Timer
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isUrgent
                        ? Colors.red.withOpacity(0.3)
                        : Colors.black.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text('$elapsed min',
                    style: TextStyle(
                      color: isUrgent ? Colors.red : Colors.white70,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    )),
                ),
              ],
            ),
          ),

          // Items
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(10),
              itemCount: order.activeItems.length,
              itemBuilder: (ctx, i) {
                final item = order.activeItems[i];
                return _KitchenItemRow(
                  item: item,
                  orderId: order.id,
                  onStatusChange: (status) async {
                    await ref.read(apiProvider).updateOrderItem(
                      order.id, item.id, {'status': status});
                    widget.onRefresh();
                  },
                );
              },
            ),
          ),

          // Footer
          Padding(
            padding: const EdgeInsets.all(10),
            child: Row(
              children: [
                Icon(Icons.people_outline, size: 14, color: Colors.grey[500]),
                const SizedBox(width: 4),
                Text('${order.guestCount}',
                  style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                const Spacer(),
                // Bump button
                ElevatedButton(
                  onPressed: () => _bumpOrder(order),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.kitchenDone,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text('BUMP', style: TextStyle(fontSize: 12)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _bumpOrder(OrderModel order) async {
    // Mark all remaining items as ready
    for (final item in order.activeItems) {
      if (item.status != 'ready') {
        await ref.read(apiProvider).updateOrderItem(
          order.id, item.id, {'status': 'ready'});
      }
    }
    widget.onRefresh();
  }
}

class _KitchenItemRow extends StatelessWidget {
  final OrderItemModel item;
  final int orderId;
  final ValueChanged<String> onStatusChange;

  const _KitchenItemRow({
    required this.item, required this.orderId, required this.onStatusChange,
  });

  @override
  Widget build(BuildContext context) {
    final isDone = item.status == 'ready';
    final isProgress = item.status == 'in_progress';

    return GestureDetector(
      onTap: () {
        if (item.status == 'pending') {
          onStatusChange('in_progress');
        } else if (item.status == 'in_progress') {
          onStatusChange('ready');
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: isDone
              ? AppColors.kitchenDone.withOpacity(0.15)
              : isProgress
                  ? AppColors.kitchenProgress.withOpacity(0.15)
                  : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isDone
                ? AppColors.kitchenDone.withOpacity(0.4)
                : isProgress
                    ? AppColors.kitchenProgress.withOpacity(0.4)
                    : Colors.grey[800]!,
          ),
        ),
        child: Row(
          children: [
            // Status icon
            Icon(
              isDone
                  ? Icons.check_circle
                  : isProgress
                      ? Icons.timelapse
                      : Icons.radio_button_unchecked,
              color: isDone
                  ? AppColors.kitchenDone
                  : isProgress
                      ? AppColors.kitchenProgress
                      : Colors.grey[600],
              size: 20,
            ),
            const SizedBox(width: 8),
            // Item details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${item.quantity}x ${item.menuItem?.name ?? ''}',
                    style: TextStyle(
                      color: isDone ? Colors.grey[500] : Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      decoration: isDone ? TextDecoration.lineThrough : null,
                    ),
                  ),
                  if (item.modifiers.isNotEmpty)
                    Text(
                      item.modifiers.map((m) => m['option_name']).join(', '),
                      style: TextStyle(color: Colors.grey[400], fontSize: 11),
                    ),
                  if (item.notes?.isNotEmpty == true)
                    Row(
                      children: [
                        const Icon(Icons.warning_amber,
                          color: Colors.amber, size: 12),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(item.notes!,
                            style: const TextStyle(
                              color: Colors.amber, fontSize: 11,
                              fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
