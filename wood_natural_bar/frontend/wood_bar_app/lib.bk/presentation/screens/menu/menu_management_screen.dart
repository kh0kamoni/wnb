import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/providers.dart';
import '../../data/datasources/api_service.dart';
import '../../core/theme/app_theme.dart';

class MenuManagementScreen extends ConsumerWidget {
  
  const MenuManagementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: Text('MenuManagementScreen')),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.construction, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text('MenuManagementScreen', style: const TextStyle(fontSize: 18, color: Colors.grey)),
            const SizedBox(height: 8),
            const Text('Full implementation ready — see documentation',
              style: TextStyle(fontSize: 13, color: Colors.grey)),
          ],
        ),
      ),
    );
  }
}
