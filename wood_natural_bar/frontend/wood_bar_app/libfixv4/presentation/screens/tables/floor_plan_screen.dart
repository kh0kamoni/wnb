import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/providers.dart';
import '../../../data/models/models.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/datasources/websocket_service.dart';
import '../../../core/constants/app_constants.dart';

class FloorPlanScreen extends ConsumerStatefulWidget {
  const FloorPlanScreen({super.key});

  @override
  ConsumerState<FloorPlanScreen> createState() => _FloorPlanScreenState();
}

class _FloorPlanScreenState extends ConsumerState<FloorPlanScreen> {
  String? _selectedSection;

  @override
  void initState() {
    super.initState();
    // Subscribe to table status updates via WebSocket
    final ws = ref.read(wsServiceProvider);
    ws.tableStatus.listen((msg) {
      final data = msg.data as Map<String, dynamic>;
      ref.read(tablesProvider.notifier).updateTableStatus(
        data['table_id'],
        data['status'],
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final tablesAsync = ref.watch(tablesProvider);
    final user = ref.watch(authProvider).user;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Floor Plan'),
        actions: [
          if (user?.canManage == true)
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              tooltip: 'Edit Floor Plan',
              onPressed: () => context.go('/tables/editor'),
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.read(tablesProvider.notifier).load(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.go('/orders/new'),
        icon: const Icon(Icons.add),
        label: const Text('Takeaway Order'),
        backgroundColor: AppColors.accent,
      ),
      body: tablesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (tables) {
          // Get unique sections
          final sections = tables
              .where((t) => t.section != null)
              .map((t) => t.section!)
              .fold<List<SectionModel>>([], (acc, s) {
                if (!acc.any((x) => x.id == s.id)) acc.add(s);
                return acc;
              });

          final filteredTables = _selectedSection == null
              ? tables
              : tables.where((t) => t.section?.name == _selectedSection).toList();

          return Column(
            children: [
              // Status legend + section filter
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                color: Colors.white,
                child: Column(
                  children: [
                    // Section filter
                    if (sections.isNotEmpty)
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _sectionChip('All', null),
                            ...sections.map((s) => _sectionChip(s.name, s.name)),
                          ],
                        ),
                      ),
                    const SizedBox(height: 8),
                    // Status legend
                    Row(
                      children: [
                        _legend('Free', AppColors.tableFree),
                        const SizedBox(width: 16),
                        _legend('Occupied', AppColors.tableOccupied),
                        const SizedBox(width: 16),
                        _legend('Reserved', AppColors.tableReserved),
                        const SizedBox(width: 16),
                        _legend('Cleaning', AppColors.tableCleaning),
                        const Spacer(),
                        Text('${tables.where((t) => t.isFree).length}/${tables.length} Free',
                          style: const TextStyle(fontSize: 12, color: Colors.grey)),
                      ],
                    ),
                  ],
                ),
              ),

              // Table grid
              Expanded(
                child: filteredTables.isEmpty
                    ? const Center(child: Text('No tables found'))
                    : GridView.builder(
                        padding: const EdgeInsets.all(16),
                        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 160,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          childAspectRatio: 1.0,
                        ),
                        itemCount: filteredTables.length,
                        itemBuilder: (ctx, i) => _tableCard(filteredTables[i]),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _sectionChip(String label, String? value) {
    final selected = _selectedSection == value;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => setState(() => _selectedSection = value),
        selectedColor: AppColors.primary.withOpacity(0.15),
        checkmarkColor: AppColors.primary,
      ),
    );
  }

  Widget _legend(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12, height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
      ],
    );
  }

  Widget _tableCard(TableModel table) {
    final color = table.statusColor;
    final isOccupied = table.isOccupied;

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      elevation: isOccupied ? 4 : 1,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _handleTableTap(table),
        child: Stack(
          children: [
            // Status indicator bar
            Positioned(
              top: 0, left: 0, right: 0,
              child: Container(
                height: 4,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Table shape icon
                  Container(
                    width: 44, height: 44,
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.1),
                      shape: table.shape == 'circle'
                          ? BoxShape.circle
                          : BoxShape.rectangle,
                      borderRadius: table.shape == 'circle'
                          ? null
                          : BorderRadius.circular(8),
                      border: Border.all(color: color.withOpacity(0.4), width: 2),
                    ),
                    child: Icon(Icons.table_restaurant, color: color, size: 22),
                  ),
                  const SizedBox(height: 8),
                  Text(table.displayName,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    overflow: TextOverflow.ellipsis),
                  if (table.section != null)
                    Text(table.section!.name,
                      style: const TextStyle(fontSize: 10, color: Colors.grey),
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.people_outline, size: 12, color: Colors.grey),
                      const SizedBox(width: 2),
                      Text('${table.capacity}',
                        style: const TextStyle(fontSize: 11, color: Colors.grey)),
                    ],
                  ),
                ],
              ),
            ),
            // Order indicator
            if (isOccupied && table.activeOrderId != null)
              Positioned(
                top: 8, right: 8,
                child: Container(
                  width: 8, height: 8,
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _handleTableTap(TableModel table) {
    if (table.isFree) {
      // Start new order
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        builder: (_) => _NewOrderSheet(table: table),
      );
    } else if (table.isOccupied && table.activeOrderId != null) {
      // View existing order
      context.go('/orders/${table.activeOrderId}');
    } else {
      // Show table detail
      context.go('/tables/${table.id}');
    }
  }
}

class _NewOrderSheet extends ConsumerStatefulWidget {
  final TableModel table;
  const _NewOrderSheet({required this.table});

  @override
  ConsumerState<_NewOrderSheet> createState() => _NewOrderSheetState();
}

class _NewOrderSheetState extends ConsumerState<_NewOrderSheet> {
  int _guestCount = 1;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 24, right: 24, top: 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40, height: 4,
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Text('Open Table ${widget.table.number}',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Number of Guests'),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.remove_circle_outline),
                    onPressed: _guestCount > 1 ? () => setState(() => _guestCount--) : null,
                  ),
                  Text('$_guestCount',
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  IconButton(
                    icon: const Icon(Icons.add_circle_outline),
                    onPressed: _guestCount < widget.table.capacity
                        ? () => setState(() => _guestCount++)
                        : null,
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                ref.read(cartProvider.notifier).initForTable(
                  widget.table.id, _guestCount,
                );
                context.go('/orders/new',
                  extra: {'table_id': widget.table.id, 'guest_count': _guestCount});
              },
              child: const Text('Start Order'),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
