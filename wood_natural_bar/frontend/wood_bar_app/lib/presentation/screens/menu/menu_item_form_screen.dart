import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../providers/providers.dart';
import '../../../data/datasources/api_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/models.dart';

class MenuItemFormScreen extends ConsumerStatefulWidget {
  final int? itemId;
  const MenuItemFormScreen({super.key, this.itemId});
  @override
  ConsumerState<MenuItemFormScreen> createState() => _MenuItemFormScreenState();
}

class _MenuItemFormScreenState extends ConsumerState<MenuItemFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _costCtrl = TextEditingController();
  final _prepCtrl = TextEditingController(text: '0');
  int? _categoryId;
  String _printerTarget = 'kitchen';
  bool _isActive = true;
  bool _isFeatured = false;
  bool _loading = false;
  bool _loadingData = false;

  @override
  void initState() {
    super.initState();
    if (widget.itemId != null) _loadItem();
  }

  Future<void> _loadItem() async {
    setState(() => _loadingData = true);
    try {
      final item = await ref.read(apiProvider).getMenuItem(widget.itemId!);
      _nameCtrl.text = item.name;
      _descCtrl.text = item.description ?? '';
      _priceCtrl.text = item.price.toString();
      _costCtrl.text = item.costPrice?.toString() ?? '';
      _prepCtrl.text = item.preparationTime.toString();
      setState(() {
        _categoryId = item.categoryId;
        _printerTarget = item.printerTarget;
        _isActive = item.isActive;
        _isFeatured = item.isFeatured;
        _loadingData = false;
      });
    } catch (_) { setState(() => _loadingData = false); }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    final data = {
      'name': _nameCtrl.text.trim(),
      'description': _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
      'price': double.parse(_priceCtrl.text),
      'cost_price': _costCtrl.text.isEmpty ? null : double.tryParse(_costCtrl.text),
      'category_id': _categoryId,
      'preparation_time': int.tryParse(_prepCtrl.text) ?? 0,
      'printer_target': _printerTarget,
      'is_active': _isActive,
      'is_featured': _isFeatured,
    };
    try {
      if (widget.itemId == null) {
        await ref.read(apiProvider).createMenuItem(data);
      } else {
        await ref.read(apiProvider).updateMenuItem(widget.itemId!, data);
      }
      ref.invalidate(menuItemsProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(widget.itemId == null ? 'Item created!' : 'Item updated!'),
          backgroundColor: Colors.green));
        context.pop();
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(categoriesProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.itemId == null ? 'New Menu Item' : 'Edit Menu Item'),
        actions: [
          TextButton.icon(
            onPressed: _loading ? null : _save,
            icon: _loading
                ? const SizedBox(width: 16, height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.save, color: Colors.white),
            label: const Text('Save', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
      body: _loadingData
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 2,
                      child: Column(
                        children: [
                          _card('Basic Info', [
                            TextFormField(
                              controller: _nameCtrl,
                              decoration: const InputDecoration(
                                labelText: 'Item Name *',
                                prefixIcon: Icon(Icons.restaurant_menu)),
                              validator: (v) => v?.isEmpty == true ? 'Required' : null,
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _descCtrl,
                              decoration: const InputDecoration(
                                labelText: 'Description',
                                prefixIcon: Icon(Icons.notes)),
                              maxLines: 3,
                            ),
                            const SizedBox(height: 12),
                            categoriesAsync.when(
                              data: (cats) => DropdownButtonFormField<int?>(
                                value: _categoryId,
                                decoration: const InputDecoration(
                                  labelText: 'Category',
                                  prefixIcon: Icon(Icons.category)),
                                items: [
                                  const DropdownMenuItem(value: null, child: Text('No Category')),
                                  ...cats.map((c) => DropdownMenuItem(
                                    value: c.id, child: Text(c.name))),
                                ],
                                onChanged: (v) => setState(() => _categoryId = v),
                              ),
                              loading: () => const LinearProgressIndicator(),
                              error: (_, __) => const SizedBox(),
                            ),
                          ]),
                          const SizedBox(height: 16),
                          _card('Pricing', [
                            Row(children: [
                              Expanded(
                                child: TextFormField(
                                  controller: _priceCtrl,
                                  decoration: const InputDecoration(
                                    labelText: 'Selling Price *',
                                    prefixText: '\$ '),
                                  keyboardType: TextInputType.number,
                                  validator: (v) {
                                    if (v?.isEmpty == true) return 'Required';
                                    if (double.tryParse(v!) == null) return 'Invalid';
                                    return null;
                                  },
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: TextFormField(
                                  controller: _costCtrl,
                                  decoration: const InputDecoration(
                                    labelText: 'Cost Price',
                                    prefixText: '\$ '),
                                  keyboardType: TextInputType.number,
                                ),
                              ),
                            ]),
                          ]),
                        ],
                      ),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: Column(
                        children: [
                          _card('Settings', [
                            DropdownButtonFormField<String>(
                              value: _printerTarget,
                              decoration: const InputDecoration(
                                labelText: 'Printer Target',
                                prefixIcon: Icon(Icons.print)),
                              items: ['kitchen', 'bar', 'none'].map((t) =>
                                DropdownMenuItem(value: t,
                                  child: Text(t.toUpperCase()))).toList(),
                              onChanged: (v) => setState(() => _printerTarget = v!),
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _prepCtrl,
                              decoration: const InputDecoration(
                                labelText: 'Prep Time (minutes)',
                                prefixIcon: Icon(Icons.timer)),
                              keyboardType: TextInputType.number,
                            ),
                            const SizedBox(height: 8),
                            SwitchListTile(
                              title: const Text('Active'),
                              subtitle: const Text('Visible in menu'),
                              value: _isActive,
                              onChanged: (v) => setState(() => _isActive = v),
                              contentPadding: EdgeInsets.zero,
                              activeColor: AppColors.primary,
                            ),
                            SwitchListTile(
                              title: const Text('Featured'),
                              subtitle: const Text('Show on homepage'),
                              value: _isFeatured,
                              onChanged: (v) => setState(() => _isFeatured = v),
                              contentPadding: EdgeInsets.zero,
                              activeColor: AppColors.primary,
                            ),
                          ]),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _card(String title, List<Widget> children) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            const Divider(height: 20),
            ...children,
          ],
        ),
      ),
    );
  }
}
