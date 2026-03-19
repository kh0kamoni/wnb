import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/providers.dart';
import '../../../data/datasources/api_service.dart';
import '../../../core/theme/app_theme.dart';

class ReservationsScreen extends ConsumerStatefulWidget {
  const ReservationsScreen({super.key});
  @override
  ConsumerState<ReservationsScreen> createState() => _ReservationsScreenState();
}

class _ReservationsScreenState extends ConsumerState<ReservationsScreen> {
  List<dynamic> _reservations = [];
  bool _loading = true;
  DateTime _selectedDate = DateTime.now();

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    final dateStr = '${_selectedDate.year}-'
        '${_selectedDate.month.toString().padLeft(2,'0')}-'
        '${_selectedDate.day.toString().padLeft(2,'0')}';
    try {
      final data = await ref.read(apiProvider).getReservations(date: dateStr);
      setState(() { _reservations = data; _loading = false; });
    } catch (_) { setState(() => _loading = false); }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reservations'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showAddReservationDialog(context),
          ),
        ],
      ),
      body: Column(
        children: [
          // Date selector
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  onPressed: () {
                    setState(() => _selectedDate = _selectedDate.subtract(const Duration(days: 1)));
                    _load();
                  },
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: () => _pickDate(),
                    child: Column(
                      children: [
                        Text(
                          _isToday(_selectedDate)
                              ? 'Today'
                              : _isTomorrow(_selectedDate)
                                  ? 'Tomorrow'
                                  : _formatDate(_selectedDate),
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          textAlign: TextAlign.center,
                        ),
                        Text(_formatDate(_selectedDate),
                          style: const TextStyle(color: Colors.grey, fontSize: 12),
                          textAlign: TextAlign.center),
                      ],
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  onPressed: () {
                    setState(() => _selectedDate = _selectedDate.add(const Duration(days: 1)));
                    _load();
                  },
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          // Stats
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            color: Colors.grey[50],
            child: Row(
              children: [
                _statPill('${_reservations.length}', 'Total', Colors.blue),
                const SizedBox(width: 12),
                _statPill(
                  '${_reservations.where((r) => r['status'] == 'confirmed').length}',
                  'Confirmed', Colors.green),
                const SizedBox(width: 12),
                _statPill(
                  '${_reservations.fold(0, (s, r) => s + (r['guest_count'] as int))}',
                  'Covers', Colors.purple),
              ],
            ),
          ),
          // List
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _reservations.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.calendar_today, size: 64, color: Colors.grey),
                            const SizedBox(height: 16),
                            Text('No reservations for ${_formatDate(_selectedDate)}',
                              style: const TextStyle(color: Colors.grey)),
                            const SizedBox(height: 12),
                            ElevatedButton.icon(
                              onPressed: () => _showAddReservationDialog(context),
                              icon: const Icon(Icons.add),
                              label: const Text('Add Reservation'),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: _reservations.length,
                        itemBuilder: (_, i) => _ReservationCard(
                          reservation: _reservations[i],
                          onStatusChange: (status) => _updateStatus(_reservations[i]['id'], status),
                        ),
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddReservationDialog(context),
        icon: const Icon(Icons.add),
        label: const Text('New Reservation'),
        backgroundColor: AppColors.primary,
      ),
    );
  }

  Widget _statPill(String value, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(value, style: TextStyle(fontWeight: FontWeight.bold, color: color)),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(fontSize: 12, color: color)),
        ],
      ),
    );
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) { setState(() => _selectedDate = picked); _load(); }
  }

  Future<void> _updateStatus(int id, String status) async {
    try {
      await ref.read(apiProvider).updateReservation(id, {'status': status});
      _load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    }
  }

  void _showAddReservationDialog(BuildContext context) {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final guestCtrl = TextEditingController(text: '2');
    TimeOfDay time = const TimeOfDay(hour: 19, minute: 0);
    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: const Text('New Reservation'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'Customer Name *')),
              const SizedBox(height: 8),
              TextField(controller: phoneCtrl,
                decoration: const InputDecoration(labelText: 'Phone *'),
                keyboardType: TextInputType.phone),
              const SizedBox(height: 8),
              TextField(controller: guestCtrl,
                decoration: const InputDecoration(labelText: 'Number of Guests'),
                keyboardType: TextInputType.number),
              const SizedBox(height: 12),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.access_time),
                title: Text(time.format(context)),
                subtitle: const Text('Reservation Time'),
                onTap: () async {
                  final t = await showTimePicker(context: ctx, initialTime: time);
                  if (t != null) setS(() => time = t);
                },
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(context);
                final dateStr = '${_selectedDate.year}-'
                    '${_selectedDate.month.toString().padLeft(2,'0')}-'
                    '${_selectedDate.day.toString().padLeft(2,'0')}';
                final timeStr = '${time.hour.toString().padLeft(2,'0')}:${time.minute.toString().padLeft(2,'0')}:00';
                await ref.read(apiProvider).createReservation({
                  'customer_name': nameCtrl.text,
                  'customer_phone': phoneCtrl.text,
                  'guest_count': int.tryParse(guestCtrl.text) ?? 2,
                  'reservation_date': dateStr,
                  'reservation_time': timeStr,
                });
                _load();
              },
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );
  }

  bool _isToday(DateTime d) {
    final n = DateTime.now();
    return d.year == n.year && d.month == n.month && d.day == n.day;
  }

  bool _isTomorrow(DateTime d) {
    final t = DateTime.now().add(const Duration(days: 1));
    return d.year == t.year && d.month == t.month && d.day == t.day;
  }

  String _formatDate(DateTime d) =>
      '${d.day}/${d.month}/${d.year}';
}

class _ReservationCard extends StatelessWidget {
  final dynamic reservation;
  final ValueChanged<String> onStatusChange;
  const _ReservationCard({required this.reservation, required this.onStatusChange});

  Color _statusColor(String status) {
    switch (status) {
      case 'confirmed': return Colors.green;
      case 'seated': return Colors.blue;
      case 'cancelled': return Colors.red;
      case 'no_show': return Colors.grey;
      default: return Colors.orange;
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = reservation['status'] ?? 'confirmed';
    final color = _statusColor(status);

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              width: 52, height: 52,
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: Text('${reservation['guest_count']}',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(reservation['customer_name'] ?? '',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  Text('${reservation['customer_phone']} • ${reservation['reservation_time']?.substring(0, 5) ?? ''}',
                    style: const TextStyle(color: Colors.grey, fontSize: 12)),
                  if (reservation['notes']?.isNotEmpty == true)
                    Text(reservation['notes'],
                      style: const TextStyle(fontSize: 11, color: Colors.orange)),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(status.toUpperCase(),
                    style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(height: 8),
                PopupMenuButton<String>(
                  onSelected: onStatusChange,
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Actions', style: TextStyle(fontSize: 12, color: Colors.blue)),
                      Icon(Icons.arrow_drop_down, size: 16, color: Colors.blue),
                    ],
                  ),
                  itemBuilder: (_) => [
                    if (status == 'confirmed')
                      const PopupMenuItem(value: 'seated', child: ListTile(
                        leading: Icon(Icons.chair, color: Colors.blue),
                        title: Text('Mark Seated'), dense: true)),
                    if (status != 'cancelled' && status != 'no_show')
                      const PopupMenuItem(value: 'cancelled', child: ListTile(
                        leading: Icon(Icons.cancel, color: Colors.red),
                        title: Text('Cancel'), dense: true)),
                    if (status == 'confirmed')
                      const PopupMenuItem(value: 'no_show', child: ListTile(
                        leading: Icon(Icons.person_off, color: Colors.grey),
                        title: Text('No Show'), dense: true)),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
