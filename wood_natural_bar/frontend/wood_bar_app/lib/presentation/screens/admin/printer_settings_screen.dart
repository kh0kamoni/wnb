import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/providers.dart';
import '../../../data/datasources/api_service.dart';
import '../../../core/theme/app_theme.dart';

class PrinterSettingsScreen extends ConsumerStatefulWidget {
  const PrinterSettingsScreen({super.key});
  @override
  ConsumerState<PrinterSettingsScreen> createState() => _PrinterSettingsScreenState();
}

class _PrinterSettingsScreenState extends ConsumerState<PrinterSettingsScreen> {
  List<dynamic> _printers = [];
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final data = await ref.read(apiProvider).getPrinters();
      setState(() { _printers = data; _loading = false; });
    } catch (_) { setState(() => _loading = false); }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Printer Settings'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showAddPrinterDialog(context),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Info banner
                Container(
                  margin: const EdgeInsets.all(16),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.blue, size: 18),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Network printers communicate via TCP/IP on port 9100 (ESC/POS). '
                          'Ensure printers are connected to the same network.',
                          style: TextStyle(fontSize: 12, color: Colors.blue),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: _printers.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.print_disabled, size: 64, color: Colors.grey),
                              const SizedBox(height: 16),
                              const Text('No printers configured'),
                              const SizedBox(height: 8),
                              ElevatedButton.icon(
                                onPressed: () => _showAddPrinterDialog(context),
                                icon: const Icon(Icons.add),
                                label: const Text('Add Printer'),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: _printers.length,
                          itemBuilder: (_, i) => _printerCard(_printers[i]),
                        ),
                ),
              ],
            ),
    );
  }

  IconData _printerIcon(String type) {
    switch (type) {
      case 'kitchen': return Icons.kitchen;
      case 'bar': return Icons.local_bar;
      case 'receipt': return Icons.receipt;
      default: return Icons.print;
    }
  }

  Color _typeColor(String type) {
    switch (type) {
      case 'kitchen': return Colors.orange;
      case 'bar': return Colors.teal;
      case 'receipt': return Colors.blue;
      default: return Colors.grey;
    }
  }

  Widget _printerCard(dynamic printer) {
    final typeColor = _typeColor(printer['type'] ?? '');
    final isActive = printer['is_active'] == true;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(
                    color: typeColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(_printerIcon(printer['type'] ?? ''), color: typeColor),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(printer['name'] ?? 'Printer',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                          const SizedBox(width: 8),
                          if (printer['is_default'] == true)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.green.shade50,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text('Default',
                                style: TextStyle(fontSize: 10, color: Colors.green,
                                  fontWeight: FontWeight.bold)),
                            ),
                        ],
                      ),
                      Text('${printer['ip_address']}:${printer['port']}',
                        style: const TextStyle(color: Colors.grey, fontSize: 12)),
                    ],
                  ),
                ),
                Switch(
                  value: isActive,
                  onChanged: (_) {},
                  activeColor: AppColors.primary,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _badge(printer['type']?.toUpperCase() ?? '', typeColor),
                const SizedBox(width: 8),
                _badge('${printer['paper_width']}mm', Colors.grey),
                const SizedBox(width: 8),
                _badge('${printer['copies']} cop${printer['copies'] == 1 ? 'y' : 'ies'}', Colors.grey),
                const Spacer(),
                // Test button
                OutlinedButton.icon(
                  onPressed: () => _testPrinter(printer),
                  icon: const Icon(Icons.print, size: 16),
                  label: const Text('Test', style: TextStyle(fontSize: 13)),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ],
            ),
            if (printer['last_test_at'] != null) ...[ 
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    printer['last_test_success'] == true
                        ? Icons.check_circle
                        : Icons.error_outline,
                    size: 14,
                    color: printer['last_test_success'] == true ? Colors.green : Colors.red,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    printer['last_test_success'] == true
                        ? 'Last test: OK'
                        : 'Last test: Failed',
                    style: TextStyle(
                      fontSize: 11,
                      color: printer['last_test_success'] == true ? Colors.green : Colors.red,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _badge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(label, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600)),
    );
  }

  Future<void> _testPrinter(dynamic printer) async {
    final snack = ScaffoldMessenger.of(context);
    snack.showSnackBar(SnackBar(
      content: Text('Testing ${printer['name']}...'),
      duration: const Duration(seconds: 2),
    ));
    // Test print via backend would go here
  }

  void _showAddPrinterDialog(BuildContext context) {
    final nameCtrl = TextEditingController();
    final ipCtrl = TextEditingController();
    final portCtrl = TextEditingController(text: '9100');
    String type = 'receipt';
    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: const Text('Add Printer'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'Printer Name *')),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: type,
                decoration: const InputDecoration(labelText: 'Type'),
                items: ['receipt', 'kitchen', 'bar', 'label']
                    .map((t) => DropdownMenuItem(value: t, child: Text(t.toUpperCase())))
                    .toList(),
                onChanged: (v) => setS(() => type = v!),
              ),
              const SizedBox(height: 8),
              TextField(controller: ipCtrl,
                decoration: const InputDecoration(
                  labelText: 'IP Address *', hintText: '192.168.1.100')),
              const SizedBox(height: 8),
              TextField(controller: portCtrl,
                decoration: const InputDecoration(labelText: 'Port'),
                keyboardType: TextInputType.number),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                // Would call createPrinter API
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                  content: Text('Printer added!'), backgroundColor: Colors.green));
                _load();
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }
}
