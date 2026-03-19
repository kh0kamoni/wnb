import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/providers.dart';
import '../../../data/datasources/api_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/models.dart';

class InventoryScreen extends ConsumerStatefulWidget {
  const InventoryScreen({super.key});
  @override
  ConsumerState<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends ConsumerState<InventoryScreen> {
  List<dynamic> _ingredients = [];
  bool _loading = true;
  bool _lowStockOnly = false;
  String _search = '';

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final data = await ref.read(apiProvider).getIngredients(lowStockOnly: _lowStockOnly);
      setState(() { _ingredients = data; _loading = false; });
    } catch (_) { setState(() => _loading = false); }
  }

  List<dynamic> get _filtered => _search.isEmpty
      ? _ingredients
      : _ingredients.where((i) =>
          (i['name'] as String).toLowerCase().contains(_search.toLowerCase())).toList();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Inventory'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showIngredientDialog(context),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    onChanged: (v) => setState(() => _search = v),
                    decoration: InputDecoration(
                      hintText: 'Search ingredients...',
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
                const SizedBox(width: 12),
                FilterChip(
                  label: const Text('Low Stock'),
                  selected: _lowStockOnly,
                  selectedColor: Colors.red.shade100,
                  onSelected: (v) { setState(() => _lowStockOnly = v); _load(); },
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _filtered.isEmpty
                    ? const Center(child: Text('No ingredients found'))
                    : ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: _filtered.length,
                        itemBuilder: (_, i) {
                          final item = _filtered[i];
                          final current = (item['current_stock'] as num).toDouble();
                          final minimum = (item['minimum_stock'] as num).toDouble();
                          final isLow = current <= minimum;
                          final pct = minimum > 0
                              ? (current / (minimum * 2)).clamp(0.0, 1.0)
                              : 1.0;
                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Row(
                                children: [
                                  Container(
                                    width: 40, height: 40,
                                    decoration: BoxDecoration(
                                      color: isLow
                                          ? Colors.red.withOpacity(0.1)
                                          : Colors.green.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Icon(
                                      isLow ? Icons.warning_amber : Icons.inventory_2_outlined,
                                      color: isLow ? Colors.red : Colors.green, size: 20,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Text(item['name'],
                                              style: const TextStyle(fontWeight: FontWeight.w600)),
                                            if (isLow) ...[ 
                                              const SizedBox(width: 8),
                                              Container(
                                                padding: const EdgeInsets.symmetric(
                                                  horizontal: 6, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: Colors.red.shade50,
                                                  borderRadius: BorderRadius.circular(4),
                                                ),
                                                child: const Text('LOW',
                                                  style: TextStyle(
                                                    fontSize: 10, color: Colors.red,
                                                    fontWeight: FontWeight.bold)),
                                              ),
                                            ],
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        Row(
                                          children: [
                                            Text('${current.toStringAsFixed(2)} ${item['unit']}',
                                              style: TextStyle(
                                                fontSize: 13,
                                                color: isLow ? Colors.red : Colors.grey[700],
                                                fontWeight: FontWeight.w500)),
                                            Text(' / min: ${minimum.toStringAsFixed(2)} ${item['unit']}',
                                              style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                                          ],
                                        ),
                                        const SizedBox(height: 6),
                                        ClipRRect(
                                          borderRadius: BorderRadius.circular(4),
                                          child: LinearProgressIndicator(
                                            value: pct,
                                            backgroundColor: Colors.grey[200],
                                            color: isLow ? Colors.red : Colors.green,
                                            minHeight: 4,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  TextButton.icon(
                                    onPressed: () => _showAdjustDialog(context, item),
                                    icon: const Icon(Icons.add_circle_outline, size: 18),
                                    label: const Text('Adjust'),
                                    style: TextButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(horizontal: 8)),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  void _showIngredientDialog(BuildContext context) {
    final nameCtrl = TextEditingController();
    final unitCtrl = TextEditingController();
    final stockCtrl = TextEditingController(text: '0');
    final minCtrl = TextEditingController(text: '0');
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Add Ingredient'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameCtrl,
              decoration: const InputDecoration(labelText: 'Ingredient Name *')),
            const SizedBox(height: 8),
            TextField(controller: unitCtrl,
              decoration: const InputDecoration(labelText: 'Unit (kg, g, l, pcs)', hintText: 'kg')),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(child: TextField(controller: stockCtrl,
                decoration: const InputDecoration(labelText: 'Current Stock'),
                keyboardType: TextInputType.number)),
              const SizedBox(width: 8),
              Expanded(child: TextField(controller: minCtrl,
                decoration: const InputDecoration(labelText: 'Minimum Stock'),
                keyboardType: TextInputType.number)),
            ]),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await ref.read(apiProvider).createIngredient({
                'name': nameCtrl.text,
                'unit': unitCtrl.text,
                'current_stock': double.tryParse(stockCtrl.text) ?? 0,
                'minimum_stock': double.tryParse(minCtrl.text) ?? 0,
              });
              _load();
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _showAdjustDialog(BuildContext context, dynamic item) {
    final ctrl = TextEditingController();
    String type = 'purchase';
    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: Text('Adjust: ${item['name']}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Current: ${item['current_stock']} ${item['unit']}',
                style: const TextStyle(color: Colors.grey)),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: type,
                decoration: const InputDecoration(labelText: 'Movement Type'),
                items: ['purchase', 'adjustment', 'waste', 'return']
                    .map((t) => DropdownMenuItem(value: t,
                        child: Text(t.toUpperCase())))
                    .toList(),
                onChanged: (v) => setS(() => type = v!),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: ctrl,
                decoration: InputDecoration(
                  labelText: type == 'waste' ? 'Quantity to remove' : 'Quantity to add',
                  suffixText: item['unit'],
                ),
                keyboardType: TextInputType.number,
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                final qty = double.tryParse(ctrl.text) ?? 0;
                Navigator.pop(context);
                await ref.read(apiProvider).adjustStock({
                  'ingredient_id': item['id'],
                  'quantity': (type == 'waste' || type == 'usage') ? -qty : qty,
                  'movement_type': type,
                });
                _load();
              },
              child: const Text('Apply'),
            ),
          ],
        ),
      ),
    );
  }
}
