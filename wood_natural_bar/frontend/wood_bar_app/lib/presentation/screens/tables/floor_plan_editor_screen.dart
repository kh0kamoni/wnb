import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/providers.dart';
import '../../../data/datasources/api_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/models.dart';

class FloorPlanEditorScreen extends ConsumerStatefulWidget {
  const FloorPlanEditorScreen({super.key});
  @override
  ConsumerState<FloorPlanEditorScreen> createState() => _FloorPlanEditorScreenState();
}

class _FloorPlanEditorScreenState extends ConsumerState<FloorPlanEditorScreen> {
  List<_EditableTable> _tables = [];
  bool _loading = true;
  bool _saving = false;
  _EditableTable? _selected;
  double _scale = 1.0;

  static const double _canvasW = 900;
  static const double _canvasH = 600;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final tables = await ref.read(apiProvider).getTables();
      setState(() {
        _tables = tables.map((t) => _EditableTable(
          id: t.id, number: t.number, name: t.name,
          x: t.posX, y: t.posY, w: t.width, h: t.height,
          shape: t.shape, capacity: t.capacity,
        )).toList();
        _loading = false;
      });
    } catch (_) { setState(() => _loading = false); }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await ref.read(apiProvider).updateFloorPlan(
        _tables.map((t) => {
          'id': t.id, 'pos_x': t.x, 'pos_y': t.y,
          'width': t.w, 'height': t.h, 'shape': t.shape,
        }).toList(),
      );
      ref.read(tablesProvider.notifier).load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Floor plan saved!'), backgroundColor: Colors.green));
        context.pop();
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Floor Plan Editor'),
        actions: [
          TextButton.icon(
            onPressed: _saving ? null : _save,
            icon: _saving
                ? const SizedBox(width: 16, height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.save, color: Colors.white),
            label: const Text('Save', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Row(
              children: [
                // Canvas
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        color: Colors.grey[100],
                        child: Row(
                          children: [
                            const Icon(Icons.info_outline, size: 16, color: Colors.grey),
                            const SizedBox(width: 8),
                            const Text('Drag tables to reposition. Tap to select.',
                              style: TextStyle(fontSize: 12, color: Colors.grey)),
                            const Spacer(),
                            const Text('Zoom:', style: TextStyle(fontSize: 12)),
                            Slider(
                              value: _scale,
                              min: 0.5, max: 2.0,
                              onChanged: (v) => setState(() => _scale = v),
                              divisions: 15,
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: InteractiveViewer(
                          minScale: 0.5,
                          maxScale: 3.0,
                          child: SizedBox(
                            width: _canvasW,
                            height: _canvasH,
                            child: Stack(
                              children: [
                                // Grid background
                                CustomPaint(
                                  painter: _GridPainter(),
                                  size: const Size(_canvasW, _canvasH),
                                ),
                                // Tables
                                ..._tables.map((t) => _DraggableTable(
                                  table: t,
                                  isSelected: _selected?.id == t.id,
                                  onSelect: () => setState(() => _selected = t),
                                  onMove: (dx, dy) => setState(() {
                                    t.x = (t.x + dx).clamp(0, _canvasW - t.w);
                                    t.y = (t.y + dy).clamp(0, _canvasH - t.h);
                                  }),
                                )),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // Properties panel
                if (_selected != null)
                  Container(
                    width: 220,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: const Border(left: BorderSide(color: Color(0xFFEEEEEE))),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Table ${_selected!.number}',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                            IconButton(
                              icon: const Icon(Icons.close, size: 18),
                              onPressed: () => setState(() => _selected = null),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                          ],
                        ),
                        const Divider(),
                        _propRow('X Position', _selected!.x.toStringAsFixed(0)),
                        _propRow('Y Position', _selected!.y.toStringAsFixed(0)),
                        _propRow('Width', _selected!.w.toStringAsFixed(0)),
                        _propRow('Height', _selected!.h.toStringAsFixed(0)),
                        const SizedBox(height: 12),
                        const Text('Shape', style: TextStyle(fontSize: 12, color: Colors.grey)),
                        const SizedBox(height: 6),
                        Row(
                          children: ['rectangle', 'circle'].map((s) {
                            final sel = _selected!.shape == s;
                            return Expanded(
                              child: Padding(
                                padding: const EdgeInsets.only(right: 6),
                                child: ElevatedButton(
                                  onPressed: () => setState(() => _selected!.shape = s),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: sel ? AppColors.primary : Colors.grey[200],
                                    foregroundColor: sel ? Colors.white : Colors.grey[600],
                                    padding: const EdgeInsets.symmetric(vertical: 8),
                                    minimumSize: Size.zero,
                                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  ),
                                  child: Text(s.substring(0, 4).toUpperCase(),
                                    style: const TextStyle(fontSize: 11)),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
    );
  }

  Widget _propRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
          Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}

class _EditableTable {
  final int id;
  final String number;
  final String? name;
  double x, y, w, h;
  String shape;
  final int capacity;
  _EditableTable({required this.id, required this.number, this.name,
    required this.x, required this.y, required this.w, required this.h,
    required this.shape, required this.capacity});
}

class _DraggableTable extends StatelessWidget {
  final _EditableTable table;
  final bool isSelected;
  final VoidCallback onSelect;
  final void Function(double dx, double dy) onMove;
  const _DraggableTable({required this.table, required this.isSelected,
    required this.onSelect, required this.onMove});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: table.x, top: table.y,
      child: GestureDetector(
        onTap: onSelect,
        onPanUpdate: (d) => onMove(d.delta.dx, d.delta.dy),
        child: Container(
          width: table.w, height: table.h,
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.primary.withOpacity(0.2)
                : Colors.white,
            borderRadius: table.shape == 'circle'
                ? BorderRadius.circular(table.w / 2)
                : BorderRadius.circular(8),
            border: Border.all(
              color: isSelected ? AppColors.primary : Colors.grey[400]!,
              width: isSelected ? 2.5 : 1.5,
            ),
            boxShadow: isSelected
                ? [BoxShadow(color: AppColors.primary.withOpacity(0.3),
                    blurRadius: 8)]
                : [const BoxShadow(color: Colors.black12, blurRadius: 2)],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(table.name ?? table.number,
                style: TextStyle(
                  fontSize: 12, fontWeight: FontWeight.bold,
                  color: isSelected ? AppColors.primary : Colors.grey[700]),
                textAlign: TextAlign.center),
              Text('${table.capacity}p',
                style: TextStyle(fontSize: 10, color: Colors.grey[500])),
            ],
          ),
        ),
      ),
    );
  }
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.grey.withOpacity(0.15)
      ..strokeWidth = 0.5;
    const step = 40.0;
    for (double x = 0; x <= size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y <= size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
    // Border
    paint.color = Colors.grey.withOpacity(0.3);
    paint.strokeWidth = 1;
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), paint);
  }
  @override
  bool shouldRepaint(_) => false;
}
