import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/providers.dart';
import '../../../data/datasources/api_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/models.dart';

class MenuManagementScreen extends ConsumerStatefulWidget {
  const MenuManagementScreen({super.key});
  @override
  ConsumerState<MenuManagementScreen> createState() => _MenuManagementScreenState();
}

class _MenuManagementScreenState extends ConsumerState<MenuManagementScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  int? _selectedCategoryId;
  String _search = '';

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
  }

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(categoriesProvider);
    final itemsAsync = ref.watch(menuItemsProvider(_selectedCategoryId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Menu Management'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Add Item',
            onPressed: () async {
              await context.push('/menu/new');
              ref.invalidate(menuItemsProvider);
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabs,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(text: 'Items', icon: Icon(Icons.restaurant_menu, size: 16)),
            Tab(text: 'Categories', icon: Icon(Icons.category, size: 16)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          // ── Items Tab ──
          Column(
            children: [
              // Search + category filter
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                child: TextField(
                  onChanged: (v) => setState(() => _search = v),
                  decoration: InputDecoration(
                    hintText: 'Search items...',
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
              categoriesAsync.when(
                data: (cats) => SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Row(
                    children: [
                      _catChip(null, 'All'),
                      ...cats.map((c) => _catChip(c.id, c.name)),
                    ],
                  ),
                ),
                loading: () => const SizedBox(height: 48),
                error: (_, __) => const SizedBox(height: 48),
              ),
              Expanded(
                child: itemsAsync.when(
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Center(child: Text('$e')),
                  data: (items) {
                    final filtered = _search.isEmpty
                        ? items
                        : items.where((i) =>
                            i.name.toLowerCase().contains(_search.toLowerCase())).toList();
                    if (filtered.isEmpty) {
                      return const Center(child: Text('No items found'));
                    }
                    return ListView.builder(
                      padding: const EdgeInsets.all(12),
                      itemCount: filtered.length,
                      itemBuilder: (_, i) => _MenuItemTile(
                        item: filtered[i],
                        onEdit: () async {
                          await context.push('/menu/${filtered[i].id}/edit');
                          ref.invalidate(menuItemsProvider);
                        },
                        onToggleAvail: () => _toggleAvailability(filtered[i]),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
          // ── Categories Tab ──
          categoriesAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('$e')),
            data: (cats) => ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: cats.length,
              itemBuilder: (_, i) {
                final cat = cats[i];
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: Container(
                      width: 36, height: 36,
                      decoration: BoxDecoration(
                        color: cat.displayColor.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(Icons.category, color: cat.displayColor, size: 20),
                    ),
                    title: Text(cat.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text(cat.description ?? 'No description'),
                    trailing: Switch(
                      value: cat.isActive,
                      onChanged: (_) {},
                      activeColor: AppColors.primary,
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddCategoryDialog(context),
        icon: const Icon(Icons.add),
        label: const Text('Add Category'),
        backgroundColor: AppColors.accent,
      ),
    );
  }

  Widget _catChip(int? id, String name) {
    final selected = _selectedCategoryId == id;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(name, style: const TextStyle(fontSize: 12)),
        selected: selected,
        onSelected: (_) => setState(() => _selectedCategoryId = id),
        selectedColor: AppColors.primary.withOpacity(0.15),
        checkmarkColor: AppColors.primary,
      ),
    );
  }

  Future<void> _toggleAvailability(MenuItemModel item) async {
    await ref.read(apiProvider).toggleItemAvailability(item.id);
    ref.invalidate(menuItemsProvider);
  }

  void _showAddCategoryDialog(BuildContext context) {
    final nameCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Add Category'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameCtrl,
              decoration: const InputDecoration(labelText: 'Category Name *')),
            const SizedBox(height: 8),
            TextField(controller: descCtrl,
              decoration: const InputDecoration(labelText: 'Description')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await ref.read(apiProvider).createCategory({
                'name': nameCtrl.text,
                'description': descCtrl.text,
              });
              ref.invalidate(categoriesProvider);
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }
}

class _MenuItemTile extends StatelessWidget {
  final MenuItemModel item;
  final VoidCallback onEdit;
  final VoidCallback onToggleAvail;
  const _MenuItemTile({required this.item, required this.onEdit, required this.onToggleAvail});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: item.imageUrl != null
              ? Image.network(item.imageUrl!, width: 48, height: 48, fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => _placeholder())
              : _placeholder(),
        ),
        title: Row(
          children: [
            Flexible(child: Text(item.name,
              style: const TextStyle(fontWeight: FontWeight.w600))),
            if (!item.isAvailable) ...[ 
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text('Unavailable',
                  style: TextStyle(fontSize: 10, color: Colors.red)),
              ),
            ],
          ],
        ),
        subtitle: Text(
          '${item.category?.name ?? 'Uncategorized'} • \$${item.price.toStringAsFixed(2)}',
          style: const TextStyle(fontSize: 12)),
        trailing: PopupMenuButton<String>(
          onSelected: (v) {
            if (v == 'edit') onEdit();
            if (v == 'avail') onToggleAvail();
          },
          itemBuilder: (_) => [
            PopupMenuItem(value: 'edit', child: ListTile(
              leading: const Icon(Icons.edit), title: const Text('Edit'), dense: true)),
            PopupMenuItem(value: 'avail', child: ListTile(
              leading: Icon(item.isAvailable ? Icons.visibility_off : Icons.visibility),
              title: Text(item.isAvailable ? 'Mark Unavailable' : 'Mark Available'),
              dense: true,
            )),
          ],
        ),
      ),
    );
  }

  Widget _placeholder() => Container(
    width: 48, height: 48, color: Colors.grey[100],
    child: const Icon(Icons.fastfood, size: 24, color: Colors.grey));
}
