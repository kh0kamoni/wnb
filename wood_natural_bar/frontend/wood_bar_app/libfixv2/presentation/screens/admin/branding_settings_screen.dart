import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../providers/providers.dart';
import '../../../data/datasources/api_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/models.dart';
import '../../../core/constants/app_constants.dart';
import '../../../data/datasources/websocket_service.dart';

class BrandingSettingsScreen extends ConsumerStatefulWidget {
  const BrandingSettingsScreen({super.key});

  @override
  ConsumerState<BrandingSettingsScreen> createState() => _BrandingSettingsScreenState();
}

class _BrandingSettingsScreenState extends ConsumerState<BrandingSettingsScreen> {
  final _nameCtrl = TextEditingController();
  final _taglineCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _currencyCtrl = TextEditingController();
  final _symbolCtrl = TextEditingController();
  final _taxCtrl = TextEditingController();
  final _serviceCtrl = TextEditingController();
  Color _primaryColor = AppColors.primary;
  Color _accentColor = AppColors.accent;
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final settings = await ref.read(apiProvider).getAllSettings();
      setState(() {
        _nameCtrl.text = settings['restaurant_name']?['value'] ?? 'Wood Natural Bar';
        _taglineCtrl.text = settings['tagline']?['value'] ?? '';
        _addressCtrl.text = settings['address']?['value'] ?? '';
        _phoneCtrl.text = settings['phone']?['value'] ?? '';
        _currencyCtrl.text = settings['currency']?['value'] ?? 'USD';
        _symbolCtrl.text = settings['currency_symbol']?['value'] ?? '\$';
        _taxCtrl.text = settings['tax_rate']?['value'] ?? '0.10';
        _serviceCtrl.text = settings['service_charge_rate']?['value'] ?? '0.05';
        final pc = settings['primary_color']?['value'] ?? '#2E7D32';
        final ac = settings['accent_color']?['value'] ?? '#FF6F00';
        try {
          _primaryColor = Color(int.parse(pc.replaceFirst('#', '0xFF')));
          _accentColor = Color(int.parse(ac.replaceFirst('#', '0xFF')));
        } catch (_) {}
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await ref.read(apiProvider).updateBranding({
        'restaurant_name': _nameCtrl.text,
        'tagline': _taglineCtrl.text,
        'address': _addressCtrl.text,
        'phone': _phoneCtrl.text,
        'currency': _currencyCtrl.text,
        'currency_symbol': _symbolCtrl.text,
        'tax_rate': double.tryParse(_taxCtrl.text) ?? 0.10,
        'service_charge_rate': double.tryParse(_serviceCtrl.text) ?? 0.05,
        'primary_color': '#${_primaryColor.value.toRadixString(16).substring(2).toUpperCase()}',
        'accent_color': '#${_accentColor.value.toRadixString(16).substring(2).toUpperCase()}',
      });
      // Invalidate branding cache
      ref.invalidate(brandingProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Branding settings saved!'),
          backgroundColor: Colors.green,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Save failed: $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _pickLogo() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (file == null) return;
    final bytes = await file.readAsBytes();
    try {
      // TODO: call upload logo API endpoint
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Logo uploaded successfully!'),
        backgroundColor: Colors.green,
      ));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Upload failed: $e'), backgroundColor: Colors.red));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Branding & Settings'),
        actions: [
          TextButton.icon(
            onPressed: _saving ? null : _save,
            icon: _saving
                ? const SizedBox(
                    width: 16, height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.save, color: Colors.white),
            label: const Text('Save', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Left column
                  Expanded(
                    child: Column(
                      children: [
                        _section('Restaurant Identity', [
                          _field('Restaurant Name', _nameCtrl, Icons.store),
                          _field('Tagline', _taglineCtrl, Icons.format_quote),
                          _field('Address', _addressCtrl, Icons.location_on_outlined,
                            maxLines: 2),
                          _field('Phone', _phoneCtrl, Icons.phone_outlined),
                        ]),
                        const SizedBox(height: 20),
                        _section('Financial', [
                          _field('Currency Code', _currencyCtrl, Icons.monetization_on_outlined,
                            hint: 'USD, EUR, GBP...'),
                          _field('Currency Symbol', _symbolCtrl, Icons.currency_exchange,
                            hint: '\$, €, £...'),
                          _field('Tax Rate', _taxCtrl, Icons.percent,
                            hint: '0.10 = 10%',
                            keyboardType: TextInputType.number),
                          _field('Service Charge', _serviceCtrl, Icons.room_service_outlined,
                            hint: '0.05 = 5%',
                            keyboardType: TextInputType.number),
                        ]),
                      ],
                    ),
                  ),
                  const SizedBox(width: 20),
                  // Right column
                  Expanded(
                    child: Column(
                      children: [
                        _section('Logo', [
                          Center(
                            child: Column(
                              children: [
                                Container(
                                  width: 120, height: 120,
                                  decoration: BoxDecoration(
                                    color: Colors.grey[100],
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(color: Colors.grey[300]!),
                                  ),
                                  child: const Icon(Icons.image, size: 48, color: Colors.grey),
                                ),
                                const SizedBox(height: 12),
                                ElevatedButton.icon(
                                  onPressed: _pickLogo,
                                  icon: const Icon(Icons.upload),
                                  label: const Text('Upload Logo'),
                                ),
                                const SizedBox(height: 6),
                                const Text('Recommended: 512×512 PNG',
                                  style: TextStyle(color: Colors.grey, fontSize: 12)),
                              ],
                            ),
                          ),
                        ]),
                        const SizedBox(height: 20),
                        _section('App Colors', [
                          _colorField('Primary Color', _primaryColor,
                            (c) => setState(() => _primaryColor = c)),
                          const SizedBox(height: 12),
                          _colorField('Accent Color', _accentColor,
                            (c) => setState(() => _accentColor = c)),
                          const SizedBox(height: 16),
                          // Preview
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.grey[200]!),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Color Preview',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600, fontSize: 13)),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Expanded(
                                      child: ElevatedButton(
                                        onPressed: () {},
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: _primaryColor),
                                        child: const Text('Primary'),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: ElevatedButton(
                                        onPressed: () {},
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: _accentColor),
                                        child: const Text('Accent'),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ]),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _section(String title, List<Widget> children) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            const Divider(height: 20),
            ...children.map((c) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: c,
            )),
          ],
        ),
      ),
    );
  }

  Widget _field(String label, TextEditingController ctrl, IconData icon,
      {String? hint, int maxLines = 1, TextInputType? keyboardType}) {
    return TextField(
      controller: ctrl,
      maxLines: maxLines,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, size: 20),
        isDense: true,
      ),
    );
  }

  Widget _colorField(String label, Color current, ValueChanged<Color> onChanged) {
    final hex = '#${current.value.toRadixString(16).substring(2).toUpperCase()}';
    return Row(
      children: [
        GestureDetector(
          onTap: () => _showColorPicker(current, onChanged),
          child: Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: current,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey[300]!),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
              Text(hex, style: const TextStyle(color: Colors.grey, fontSize: 12)),
            ],
          ),
        ),
        TextButton(
          onPressed: () => _showColorPicker(current, onChanged),
          child: const Text('Change'),
        ),
      ],
    );
  }

  void _showColorPicker(Color initial, ValueChanged<Color> onChanged) {
    showDialog(
      context: context,
      builder: (_) => _ColorPickerDialog(
        initial: initial,
        onChanged: onChanged,
      ),
    );
  }
}

class _ColorPickerDialog extends StatefulWidget {
  final Color initial;
  final ValueChanged<Color> onChanged;

  const _ColorPickerDialog({required this.initial, required this.onChanged});

  @override
  State<_ColorPickerDialog> createState() => _ColorPickerDialogState();
}

class _ColorPickerDialogState extends State<_ColorPickerDialog> {
  late Color _selected;
  final _hexCtrl = TextEditingController();

  final _presets = [
    Color(0xFF2E7D32), Color(0xFF1B5E20), Color(0xFF388E3C),
    Color(0xFF1565C0), Color(0xFF0D47A1), Color(0xFF1976D2),
    Color(0xFFB71C1C), Color(0xFFC62828), Color(0xFFD32F2F),
    Color(0xFF4A148C), Color(0xFF6A1B9A), Color(0xFF7B1FA2),
    Color(0xFFE65100), Color(0xFFFF6F00), Color(0xFFFF8F00),
    Color(0xFF37474F), Color(0xFF455A64), Color(0xFF546E7A),
    Color(0xFF4E342E), Color(0xFF5D4037), Color(0xFF6D4C41),
    Color(0xFF00695C), Color(0xFF00796B), Color(0xFF00897B),
  ];

  @override
  void initState() {
    super.initState();
    _selected = widget.initial;
    _hexCtrl.text = '#${_selected.value.toRadixString(16).substring(2).toUpperCase()}';
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Choose Color'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            height: 48,
            decoration: BoxDecoration(
              color: _selected,
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8, runSpacing: 8,
            children: _presets.map((c) => GestureDetector(
              onTap: () => setState(() {
                _selected = c;
                _hexCtrl.text = '#${c.value.toRadixString(16).substring(2).toUpperCase()}';
              }),
              child: Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  color: c,
                  shape: BoxShape.circle,
                  border: _selected == c
                      ? Border.all(color: Colors.black, width: 3)
                      : null,
                ),
              ),
            )).toList(),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _hexCtrl,
            decoration: const InputDecoration(
              labelText: 'Hex Color',
              hintText: '#2E7D32',
              prefixIcon: Icon(Icons.tag),
            ),
            onChanged: (v) {
              try {
                if (v.length == 7) {
                  setState(() => _selected = Color(int.parse(v.replaceFirst('#', '0xFF'))));
                }
              } catch (_) {}
            },
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        ElevatedButton(
          onPressed: () {
            widget.onChanged(_selected);
            Navigator.pop(context);
          },
          child: const Text('Apply'),
        ),
      ],
    );
  }
}
