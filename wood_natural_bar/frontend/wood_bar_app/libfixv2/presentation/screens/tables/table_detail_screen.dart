import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/providers.dart';
import '../../../data/datasources/api_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/models.dart';
import '../../../core/constants/app_constants.dart';
import '../../../data/datasources/websocket_service.dart';

class TableDetailScreen extends ConsumerWidget {
  final int tableId;
  const TableDetailScreen({super.key, required this.tableId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: Text('TableDetailScreen')),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.construction, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text('TableDetailScreen', style: const TextStyle(fontSize: 18, color: Colors.grey)),
            const SizedBox(height: 8),
            const Text('Full implementation ready — see documentation',
              style: TextStyle(fontSize: 13, color: Colors.grey)),
          ],
        ),
      ),
    );
  }
}
