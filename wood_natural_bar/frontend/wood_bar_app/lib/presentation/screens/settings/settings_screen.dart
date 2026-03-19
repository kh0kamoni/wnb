import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../providers/providers.dart';
import '../../../data/datasources/api_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/models.dart';
import '../../../core/constants/app_constants.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).user;
    final branding = ref.watch(brandingProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Profile card
            if (user != null) _profileCard(context, ref, user),
            const SizedBox(height: 20),

            // App Settings
            _sectionTitle('Application'),
            _settingTile(
              icon: Icons.palette_outlined,
              title: 'Branding & Appearance',
              subtitle: branding.when(
                data: (b) => b.restaurantName,
                loading: () => 'Loading...',
                error: (_, __) => 'Error loading',
              ),
              color: Colors.pink,
              onTap: user?.canManage == true ? () => context.go('/admin/branding') : null,
            ),
            _settingTile(
              icon: Icons.dns_outlined,
              title: 'Server Connection',
              subtitle: 'Configure server URL',
              color: Colors.blue,
              onTap: () => context.go('/setup'),
            ),
            _settingTile(
              icon: Icons.print_outlined,
              title: 'Printers',
              subtitle: 'Receipt, kitchen & bar printers',
              color: Colors.brown,
              onTap: user?.canManage == true ? () => context.go('/admin/printers') : null,
            ),
            const SizedBox(height: 16),

            if (user?.canManage == true) ...[ 
              _sectionTitle('Management'),
              _settingTile(
                icon: Icons.people_outlined,
                title: 'User Management',
                subtitle: 'Staff accounts and roles',
                color: Colors.indigo,
                onTap: () => context.go('/admin/users'),
              ),
              _settingTile(
                icon: Icons.inventory_2_outlined,
                title: 'Inventory',
                subtitle: 'Stock and ingredient management',
                color: Colors.orange,
                onTap: () => context.go('/admin/inventory'),
              ),
              _settingTile(
                icon: Icons.admin_panel_settings,
                title: 'Admin Dashboard',
                subtitle: 'Full system administration',
                color: Colors.grey,
                onTap: () => context.go('/admin'),
              ),
              const SizedBox(height: 16),
            ],

            _sectionTitle('Account'),
            _settingTile(
              icon: Icons.lock_outline,
              title: 'Change Password',
              subtitle: 'Update your login password',
              color: Colors.teal,
              onTap: () => _showChangePasswordDialog(context, ref, user),
            ),
            _settingTile(
              icon: Icons.logout,
              title: 'Sign Out',
              subtitle: 'Log out of POS system',
              color: Colors.red,
              onTap: () => _confirmLogout(context, ref),
            ),
            const SizedBox(height: 24),

            // App version footer
            Center(
              child: Text(
                'Wood Natural Bar POS v1.0.0',
                style: const TextStyle(color: Colors.grey, fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _profileCard(BuildContext context, WidgetRef ref, UserModel user) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            CircleAvatar(
              radius: 32,
              backgroundColor: AppColors.primary.withOpacity(0.15),
              child: Text(
                user.fullName.isNotEmpty ? user.fullName[0].toUpperCase() : '?',
                style: TextStyle(
                  fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.primary),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(user.fullName,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
                  Text('@${user.username}',
                    style: const TextStyle(color: Colors.grey, fontSize: 13)),
                  if (user.email != null)
                    Text(user.email!,
                      style: const TextStyle(color: Colors.grey, fontSize: 12)),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(user.role.toUpperCase(),
                style: TextStyle(
                  color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(title,
        style: TextStyle(
          fontSize: 12, fontWeight: FontWeight.bold,
          color: Colors.grey[600], letterSpacing: 0.8)),
    );
  }

  Widget _settingTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    VoidCallback? onTap,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Container(
          width: 40, height: 40,
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
        trailing: onTap != null
            ? const Icon(Icons.chevron_right, color: Colors.grey)
            : const Icon(Icons.lock_outline, color: Colors.grey, size: 16),
        onTap: onTap,
        enabled: onTap != null,
      ),
    );
  }

  void _showChangePasswordDialog(BuildContext context, WidgetRef ref, UserModel? user) {
    if (user == null) return;
    final currentCtrl = TextEditingController();
    final newCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Change Password'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: currentCtrl, obscureText: true,
              decoration: const InputDecoration(labelText: 'Current Password')),
            const SizedBox(height: 8),
            TextField(controller: newCtrl, obscureText: true,
              decoration: const InputDecoration(labelText: 'New Password')),
            const SizedBox(height: 8),
            TextField(controller: confirmCtrl, obscureText: true,
              decoration: const InputDecoration(labelText: 'Confirm New Password')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (newCtrl.text != confirmCtrl.text) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                  content: Text('Passwords do not match'), backgroundColor: Colors.red));
                return;
              }
              Navigator.pop(context);
              try {
                await ref.read(apiProvider).changePassword(user.id, {
                  'current_password': currentCtrl.text,
                  'new_password': newCtrl.text,
                });
                if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Password changed!'), backgroundColor: Colors.green));
              } catch (e) {
                if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
              }
            },
            child: const Text('Change'),
          ),
        ],
      ),
    );
  }

  void _confirmLogout(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await ref.read(authProvider.notifier).logout();
              if (context.mounted) context.go('/auth/login');
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );
  }
}
