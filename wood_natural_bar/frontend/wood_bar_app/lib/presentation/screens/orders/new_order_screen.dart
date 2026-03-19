import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/providers.dart';
import '../../../data/models/models.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/datasources/api_service.dart';
import '../../../core/constants/app_constants.dart';
import '../../../data/datasources/websocket_service.dart';

class NewOrderScreen extends ConsumerStatefulWidget {
  final int? tableId;
  final int? existingOrderId;
  const NewOrderScreen({super.key, this.tableId, this.existingOrderId});

  @override
  ConsumerState<NewOrderScreen> createState() => _NewOrderScreenState();
}

class _NewOrderScreenState extends ConsumerState<NewOrderScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int? _selectedCategoryId;
  String _searchQuery = '';
  bool _isSubmitting = false;
  OrderModel? _existingOrder;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    if (widget.tableId != null) {
      ref.read(cartProvider.notifier).initForTable(widget.tableId!, 1);
    }
    if (widget.existingOrderId != null) _loadExistingOrder();
  }

  Future<void> _loadExistingOrder() async {
    final order = await ref.read(apiProvider).getOrder(widget.existingOrderId!);
    setState(() => _existingOrder = order);
    ref.read(cartProvider.notifier).setExistingOrderId(order.id);
  }

  @override
  Widget build(BuildContext context) {
    final cart = ref.watch(cartProvider);
    final categoriesAsync = ref.watch(categoriesProvider);
    final user = ref.watch(authProvider).user;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.existingOrderId != null
            ? 'Add Items to Order'
            : widget.tableId != null
                ? 'Table ${widget.tableId} - New Order'
                : 'New Order'),
        actions: [
          if (cart.items.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Badge(
                label: Text('${cart.items.length}'),
                child: IconButton(
                  icon: const Icon(Icons.shopping_cart_outlined),
                  onPressed: () => _showCart(context),
                ),
              ),
            ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(text: 'Menu', icon: Icon(Icons.restaurant_menu, size: 16)),
            Tab(text: 'Cart', icon: Icon(Icons.shopping_cart, size: 16)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // ─── TAB 1: MENU ───
          Row(
            children: [
              // Category sidebar
              categoriesAsync.when(
                loading: () => const SizedBox(width: 120),
                error: (_, __) => const SizedBox(width: 120),
                data: (cats) => _CategorySidebar(
                  categories: cats,
                  selectedId: _selectedCategoryId,
                  onSelect: (id) => setState(() => _selectedCategoryId = id),
                ),
              ),
              // Menu items grid
              Expanded(
                child: Column(
                  children: [
                    _SearchBar(onChanged: (q) => setState(() => _searchQuery = q)),
                    Expanded(
                      child: _MenuItemsGrid(
                        categoryId: _selectedCategoryId,
                        search: _searchQuery,
                        onAddItem: _addToCart,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          // ─── TAB 2: CART ───
          _CartView(
            cart: cart,
            onSubmit: _submitOrder,
            isSubmitting: _isSubmitting,
            existingOrderId: widget.existingOrderId,
          ),
        ],
      ),
      bottomNavigationBar: cart.items.isEmpty
          ? null
          : _BottomCartBar(
              cart: cart,
              onViewCart: () => _tabController.animateTo(1),
              onSubmit: _submitOrder,
              isSubmitting: _isSubmitting,
            ),
    );
  }

  void _addToCart(MenuItemModel item) {
    if (item.modifierGroups.isEmpty) {
      ref.read(cartProvider.notifier).addItem(item);
      _showAddedSnack(item.name);
    } else {
      _showModifierSheet(item);
    }
  }

  void _showModifierSheet(MenuItemModel item) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _ModifierSheet(
        item: item,
        onConfirm: (qty, notes, modifiers) {
          ref.read(cartProvider.notifier).addItem(item,
            quantity: qty, notes: notes, modifiers: modifiers);
          _showAddedSnack(item.name);
        },
      ),
    );
  }

  void _showAddedSnack(String name) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('$name added to cart'),
      duration: const Duration(seconds: 1),
      behavior: SnackBarBehavior.floating,
    ));
  }

  Future<void> _submitOrder() async {
    final cart = ref.read(cartProvider);
    final cartNotifier = ref.read(cartProvider.notifier);
    if (cart.items.isEmpty) return;
    setState(() => _isSubmitting = true);
    try {
      final api = ref.read(apiProvider);
      OrderModel order;
      if (widget.existingOrderId != null) {
        order = await api.addItemsToOrder(
          widget.existingOrderId!, cartNotifier.toAddItemsPayload());
      } else {
        order = await api.createOrder(cartNotifier.toCreateOrderPayload());
        await api.sendToKitchen(order.id);
      }
      ref.read(cartProvider.notifier).clear();
      ref.read(tablesProvider.notifier).load();
      if (mounted) {
        context.go('/orders/${order.id}');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.red,
        ));
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _showCart(BuildContext context) => _tabController.animateTo(1);
}

// ─── Category Sidebar ───
class _CategorySidebar extends StatelessWidget {
  final List<CategoryModel> categories;
  final int? selectedId;
  final ValueChanged<int?> onSelect;

  const _CategorySidebar(
      {required this.categories, this.selectedId, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 110,
      color: Colors.white,
      child: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          _catItem(null, 'All', Icons.grid_view),
          ...categories.map((c) => _catItem(c.id, c.name, Icons.category)),
        ],
      ),
    );
  }

  Widget _catItem(int? id, String name, IconData icon) {
    final selected = selectedId == id;
    return GestureDetector(
      onTap: () => onSelect(id),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary.withOpacity(0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: selected ? Border.all(color: AppColors.primary.withOpacity(0.3)) : null,
        ),
        child: Column(
          children: [
            Icon(icon,
              size: 22,
              color: selected ? AppColors.primary : Colors.grey),
            const SizedBox(height: 4),
            Text(name,
              textAlign: TextAlign.center,
              maxLines: 2,
              style: TextStyle(
                fontSize: 10,
                fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                color: selected ? AppColors.primary : Colors.grey[600],
              )),
          ],
        ),
      ),
    );
  }
}

// ─── Search Bar ───
class _SearchBar extends StatelessWidget {
  final ValueChanged<String> onChanged;
  const _SearchBar({required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(10),
      child: TextField(
        onChanged: onChanged,
        decoration: InputDecoration(
          hintText: 'Search menu items...',
          prefixIcon: const Icon(Icons.search, size: 20),
          contentPadding: const EdgeInsets.symmetric(vertical: 10),
          isDense: true,
          filled: true,
          fillColor: Colors.grey[100],
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }
}

// ─── Menu Items Grid ───
class _MenuItemsGrid extends ConsumerWidget {
  final int? categoryId;
  final String search;
  final ValueChanged<MenuItemModel> onAddItem;

  const _MenuItemsGrid(
      {this.categoryId, required this.search, required this.onAddItem});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final itemsAsync = ref.watch(menuItemsProvider(categoryId));
    return itemsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('$e')),
      data: (items) {
        final filtered = search.isEmpty
            ? items
            : items.where((i) =>
                i.name.toLowerCase().contains(search.toLowerCase())).toList();

        if (filtered.isEmpty) {
          return const Center(child: Text('No items found'));
        }

        return GridView.builder(
          padding: const EdgeInsets.all(10),
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 180,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 0.8,
          ),
          itemCount: filtered.length,
          itemBuilder: (ctx, i) => _MenuItemCard(
            item: filtered[i],
            onTap: () => onAddItem(filtered[i]),
          ),
        );
      },
    );
  }
}

class _MenuItemCard extends StatelessWidget {
  final MenuItemModel item;
  final VoidCallback onTap;
  const _MenuItemCard({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      elevation: 1,
      child: InkWell(
        onTap: item.isAvailable ? onTap : null,
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Image
                Expanded(
                  child: ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                    child: item.imageUrl != null
                        ? Image.network(
                            item.imageUrl!,
                            fit: BoxFit.cover,
                            width: double.infinity,
                            errorBuilder: (_, __, ___) => _placeholder(),
                          )
                        : _placeholder(),
                  ),
                ),
                // Info
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item.name,
                        maxLines: 2,
                        style: const TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w600),
                        overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('\$${item.price.toStringAsFixed(2)}',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary)),
                          Container(
                            width: 28, height: 28,
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.add, color: Colors.white, size: 18),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (!item.isAvailable)
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Center(
                    child: Text('SOLD OUT',
                      style: TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold,
                        fontSize: 13)),
                  ),
                ),
              ),
            if (item.tags.contains('spicy'))
              Positioned(
                top: 6, right: 6,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text('🌶', style: TextStyle(fontSize: 10)),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _placeholder() {
    return Container(
      color: Colors.grey[100],
      child: const Center(child: Icon(Icons.fastfood, size: 36, color: Colors.grey)),
    );
  }
}

// ─── Cart View ───
class _CartView extends ConsumerWidget {
  final CartState cart;
  final VoidCallback onSubmit;
  final bool isSubmitting;
  final int? existingOrderId;

  const _CartView({
    required this.cart,
    required this.onSubmit,
    required this.isSubmitting,
    this.existingOrderId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (cart.items.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.shopping_cart_outlined, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('Cart is empty', style: TextStyle(color: Colors.grey, fontSize: 16)),
            SizedBox(height: 8),
            Text('Go to Menu tab to add items',
              style: TextStyle(color: Colors.grey, fontSize: 13)),
          ],
        ),
      );
    }

    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: cart.items.length,
            itemBuilder: (ctx, i) => _CartItemRow(
              item: cart.items[i],
              index: i,
              onRemove: () => ref.read(cartProvider.notifier).removeItem(i),
              onQtyChange: (q) => ref.read(cartProvider.notifier).updateQuantity(i, q),
            ),
          ),
        ),
        // Order summary
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 8, offset: const Offset(0, -2))],
          ),
          child: Column(
            children: [
              if (cart.tableId != null)
                _summaryRow('Table', 'Table ${cart.tableId}'),
              _summaryRow('Items', '${cart.items.length}'),
              _summaryRow('Subtotal', '\$${cart.subtotal.toStringAsFixed(2)}'),
              const Divider(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Total (est.)',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  Text('\$${cart.subtotal.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 18,
                      color: AppColors.primary)),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: isSubmitting ? null : onSubmit,
                  icon: isSubmitting
                      ? const SizedBox(
                          width: 18, height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.send),
                  label: Text(existingOrderId != null
                    ? 'Add to Order & Send'
                    : 'Place Order & Send to Kitchen'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _summaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 13)),
          Text(value, style: const TextStyle(fontSize: 13)),
        ],
      ),
    );
  }
}

class _CartItemRow extends StatelessWidget {
  final CartItem item;
  final int index;
  final VoidCallback onRemove;
  final ValueChanged<int> onQtyChange;

  const _CartItemRow({
    required this.item, required this.index,
    required this.onRemove, required this.onQtyChange,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.menuItem.name,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                  if (item.selectedModifiers.isNotEmpty)
                    Text(
                      item.selectedModifiers
                          .map((m) => m['option_name'] as String)
                          .join(', '),
                      style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  if (item.notes?.isNotEmpty == true)
                    Text('Note: ${item.notes}',
                      style: const TextStyle(fontSize: 11, color: Colors.orange)),
                ],
              ),
            ),
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.remove, size: 18),
                  onPressed: () => onQtyChange(item.quantity - 1),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                ),
                Container(
                  width: 32, height: 32,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Center(
                    child: Text('${item.quantity}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold, color: AppColors.primary)),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.add, size: 18),
                  onPressed: () => onQtyChange(item.quantity + 1),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                ),
              ],
            ),
            const SizedBox(width: 8),
            Text('\$${item.lineTotal.toStringAsFixed(2)}',
              style: const TextStyle(fontWeight: FontWeight.bold)),
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.red, size: 18),
              onPressed: onRemove,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Bottom Cart Bar ───
class _BottomCartBar extends StatelessWidget {
  final CartState cart;
  final VoidCallback onViewCart;
  final VoidCallback onSubmit;
  final bool isSubmitting;

  const _BottomCartBar({
    required this.cart, required this.onViewCart,
    required this.onSubmit, required this.isSubmitting,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: AppColors.primary,
      child: SafeArea(
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '${cart.items.fold(0, (s, i) => s + i.quantity)} items',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(width: 12),
            Text('\$${cart.subtotal.toStringAsFixed(2)}',
              style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
            const Spacer(),
            ElevatedButton.icon(
              onPressed: isSubmitting ? null : onSubmit,
              icon: const Icon(Icons.send, size: 16),
              label: const Text('Send to Kitchen'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: AppColors.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Modifier Sheet ───
class _ModifierSheet extends StatefulWidget {
  final MenuItemModel item;
  final Function(int, String?, List<Map<String, dynamic>>) onConfirm;

  const _ModifierSheet({required this.item, required this.onConfirm});

  @override
  State<_ModifierSheet> createState() => _ModifierSheetState();
}

class _ModifierSheetState extends State<_ModifierSheet> {
  int _qty = 1;
  final _notesCtrl = TextEditingController();
  final Map<int, List<int>> _selectedOptions = {};

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      maxChildSize: 0.95,
      minChildSize: 0.4,
      expand: false,
      builder: (_, scrollCtrl) => Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
                ),
                const SizedBox(height: 12),
                Text(widget.item.name,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                Text('\$${widget.item.price.toStringAsFixed(2)}',
                  style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              controller: scrollCtrl,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                ...widget.item.modifierGroups.map((group) => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(group.name,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        const SizedBox(width: 8),
                        if (group.isRequired)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.red.shade50,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text('Required',
                              style: TextStyle(color: Colors.red, fontSize: 11)),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8, runSpacing: 8,
                      children: group.options.map((opt) {
                        final isSelected = _selectedOptions[group.id]?.contains(opt.id) ?? false;
                        return FilterChip(
                          label: Text(
                            opt.priceAdjustment > 0
                                ? '${opt.name} (+\$${opt.priceAdjustment.toStringAsFixed(2)})'
                                : opt.name,
                            style: const TextStyle(fontSize: 12),
                          ),
                          selected: isSelected,
                          onSelected: (sel) => setState(() {
                            _selectedOptions.putIfAbsent(group.id, () => []);
                            if (sel) {
                              if (group.maxSelections == 1) {
                                _selectedOptions[group.id] = [opt.id];
                              } else {
                                _selectedOptions[group.id]!.add(opt.id);
                              }
                            } else {
                              _selectedOptions[group.id]!.remove(opt.id);
                            }
                          }),
                          selectedColor: AppColors.primary.withOpacity(0.15),
                          checkmarkColor: AppColors.primary,
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),
                  ],
                )),
                TextField(
                  controller: _notesCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Special instructions (optional)',
                    hintText: 'e.g., No onions, extra sauce...',
                    prefixIcon: Icon(Icons.notes),
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(
                16, 8, 16, MediaQuery.of(context).viewInsets.bottom + 16),
            child: Row(
              children: [
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.remove_circle_outline),
                      onPressed: _qty > 1 ? () => setState(() => _qty--) : null,
                    ),
                    Text('$_qty', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    IconButton(
                      icon: const Icon(Icons.add_circle_outline),
                      onPressed: () => setState(() => _qty++),
                    ),
                  ],
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      final modifiers = <Map<String, dynamic>>[];
                      for (final group in widget.item.modifierGroups) {
                        final selected = _selectedOptions[group.id] ?? [];
                        for (final optId in selected) {
                          final opt = group.options.firstWhere((o) => o.id == optId);
                          modifiers.add({
                            'group_id': group.id,
                            'group_name': group.name,
                            'option_id': opt.id,
                            'option_name': opt.name,
                            'price_adjustment': opt.priceAdjustment,
                          });
                        }
                      }
                      Navigator.pop(context);
                      widget.onConfirm(_qty, _notesCtrl.text.isEmpty ? null : _notesCtrl.text, modifiers);
                    },
                    child: Text('Add to Order • \$${(widget.item.price * _qty).toStringAsFixed(2)}'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
