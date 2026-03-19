import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/providers.dart';
import '../../../data/datasources/api_service.dart';
import '../../../core/theme/app_theme.dart';

class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key});
  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 7));
  DateTime _endDate = DateTime.now();
  Map<String, dynamic>? _report;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _loadReport();
  }

  Future<void> _loadReport() async {
    setState(() => _loading = true);
    try {
      final start = _fmt(_startDate);
      final end = _fmt(_endDate);
      final data = await ref.read(apiProvider).getSalesReport(start, end);
      setState(() { _report = data; _loading = false; });
    } catch (_) { setState(() => _loading = false); }
  }

  String _fmt(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2,'0')}-${d.day.toString().padLeft(2,'0')}';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reports & Analytics'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadReport),
        ],
        bottom: TabBar(
          controller: _tabs,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(text: 'Sales Report', icon: Icon(Icons.bar_chart, size: 16)),
            Tab(text: 'Top Items', icon: Icon(Icons.star_outlined, size: 16)),
          ],
        ),
      ),
      body: Column(
        children: [
          // Date range picker
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: Colors.white,
            child: Row(
              children: [
                const Icon(Icons.date_range, color: Colors.grey, size: 18),
                const SizedBox(width: 8),
                _datePicker('From', _startDate, (d) => setState(() => _startDate = d)),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: Text('→', style: TextStyle(color: Colors.grey)),
                ),
                _datePicker('To', _endDate, (d) => setState(() => _endDate = d)),
                const Spacer(),
                ElevatedButton(
                  onPressed: _loadReport,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text('Apply'),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _report == null
                    ? const Center(child: Text('No data'))
                    : TabBarView(
                        controller: _tabs,
                        children: [
                          _SalesTab(report: _report!),
                          _TopItemsTab(items: (_report!['top_items'] as List?) ?? []),
                        ],
                      ),
          ),
        ],
      ),
    );
  }

  Widget _datePicker(String label, DateTime date, ValueChanged<DateTime> onChanged) {
    return GestureDetector(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: date,
          firstDate: DateTime(2020),
          lastDate: DateTime.now(),
        );
        if (picked != null) { onChanged(picked); }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey[300]!),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
            Text(
              '${date.day}/${date.month}/${date.year}',
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          ],
        ),
      ),
    );
  }
}

class _SalesTab extends StatelessWidget {
  final Map<String, dynamic> report;
  const _SalesTab({required this.report});

  @override
  Widget build(BuildContext context) {
    final summary = report['summary'] as Map<String, dynamic>? ?? {};
    final byDay = (report['revenue_by_day'] as List?) ?? [];
    final byCategory = (report['revenue_by_category'] as List?) ?? [];
    final paymentBreakdown = (report['payment_breakdown'] as Map<String, dynamic>?) ?? {};

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // KPI cards
          GridView.count(
            crossAxisCount: 4,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.5,
            children: [
              _kpiCard('Total Revenue',
                '\$${(summary['total_revenue'] ?? 0).toStringAsFixed(2)}',
                Icons.attach_money, Colors.green),
              _kpiCard('Total Orders',
                '${summary['total_orders'] ?? 0}',
                Icons.receipt_outlined, Colors.blue),
              _kpiCard('Avg Order Value',
                '\$${(summary['avg_order_value'] ?? 0).toStringAsFixed(2)}',
                Icons.trending_up, Colors.purple),
              _kpiCard('Total Covers',
                '${summary['total_covers'] ?? 0}',
                Icons.people_outline, Colors.orange),
            ],
          ),
          const SizedBox(height: 20),

          // Revenue by day
          _sectionTitle('Revenue by Day'),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: byDay.isEmpty
                    ? [const Text('No data', style: TextStyle(color: Colors.grey))]
                    : byDay.map<Widget>((d) {
                        final rev = (d['revenue'] as num).toDouble();
                        final maxRev = byDay.fold<double>(0,
                            (m, x) => (x['revenue'] as num).toDouble() > m
                                ? (x['revenue'] as num).toDouble() : m);
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            children: [
                              SizedBox(width: 80,
                                child: Text(d['date'].toString().substring(5),
                                  style: const TextStyle(fontSize: 12))),
                              Expanded(
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(4),
                                  child: LinearProgressIndicator(
                                    value: maxRev > 0 ? rev / maxRev : 0,
                                    backgroundColor: Colors.grey[200],
                                    color: AppColors.primary,
                                    minHeight: 16,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              SizedBox(width: 70,
                                child: Text('\$${rev.toStringAsFixed(0)}',
                                  textAlign: TextAlign.right,
                                  style: const TextStyle(
                                    fontSize: 12, fontWeight: FontWeight.w600))),
                            ],
                          ),
                        );
                      }).toList(),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Payment breakdown + Category side by side
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: Column(children: [
                _sectionTitle('Revenue by Category'),
                const SizedBox(height: 8),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: byCategory.isEmpty
                          ? [const Text('No data', style: TextStyle(color: Colors.grey))]
                          : byCategory.map<Widget>((c) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Row(
                              children: [
                                Expanded(child: Text(c['category'] ?? '',
                                  style: const TextStyle(fontSize: 13))),
                                Text('\$${(c['revenue'] as num).toStringAsFixed(2)}',
                                  style: const TextStyle(fontWeight: FontWeight.bold)),
                              ],
                            ),
                          )).toList(),
                    ),
                  ),
                ),
              ])),
              const SizedBox(width: 16),
              Expanded(child: Column(children: [
                _sectionTitle('Payment Breakdown'),
                const SizedBox(height: 8),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: paymentBreakdown.isEmpty
                          ? [const Text('No data', style: TextStyle(color: Colors.grey))]
                          : paymentBreakdown.entries.map<Widget>((e) {
                            final val = e.value as Map<String, dynamic>;
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: Row(
                                children: [
                                  _payIcon(e.key),
                                  const SizedBox(width: 8),
                                  Expanded(child: Text(e.key.toUpperCase(),
                                    style: const TextStyle(fontSize: 13))),
                                  Text('\$${(val['total'] as num).toStringAsFixed(2)}',
                                    style: const TextStyle(fontWeight: FontWeight.bold)),
                                  Text(' (${val['count']})',
                                    style: const TextStyle(color: Colors.grey, fontSize: 11)),
                                ],
                              ),
                            );
                          }).toList(),
                    ),
                  ),
                ),
              ])),
            ],
          ),
        ],
      ),
    );
  }

  Widget _kpiCard(String label, String value, IconData icon, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Icon(icon, color: color, size: 22),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
                Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15));
  }

  Widget _payIcon(String method) {
    switch (method) {
      case 'cash': return const Icon(Icons.money, size: 18, color: Colors.green);
      case 'card': return const Icon(Icons.credit_card, size: 18, color: Colors.blue);
      case 'mobile': return const Icon(Icons.phone_android, size: 18, color: Colors.purple);
      default: return const Icon(Icons.payment, size: 18, color: Colors.grey);
    }
  }
}

class _TopItemsTab extends StatelessWidget {
  final List items;
  const _TopItemsTab({required this.items});

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const Center(child: Text('No data for selected period'));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: items.length,
      itemBuilder: (_, i) {
        final item = items[i];
        final maxQty = (items.first['total_qty'] as num).toDouble();
        final qty = (item['total_qty'] as num).toDouble();
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    color: i < 3
                        ? [Colors.amber, Colors.grey, Colors.brown[300]!][i].withOpacity(0.2)
                        : Colors.grey[100]!,
                    shape: BoxShape.circle,
                  ),
                  child: Center(child: Text('${i+1}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: i < 3
                          ? [Colors.amber[700]!, Colors.grey[600]!, Colors.brown[400]!][i]
                          : Colors.grey[500]!))),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item['name'] ?? '',
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 4),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: maxQty > 0 ? qty / maxQty : 0,
                          backgroundColor: Colors.grey[200],
                          color: AppColors.primary,
                          minHeight: 6,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('${qty.toInt()} sold',
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                    Text('\$${(item['total_revenue'] as num).toStringAsFixed(2)}',
                      style: const TextStyle(color: Colors.grey, fontSize: 12)),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
