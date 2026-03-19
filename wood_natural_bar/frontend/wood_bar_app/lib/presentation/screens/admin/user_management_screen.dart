import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/providers.dart';
import '../../../data/datasources/api_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/models.dart';

class UserManagementScreen extends ConsumerStatefulWidget {
  const UserManagementScreen({super.key});
  @override
  ConsumerState<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends ConsumerState<UserManagementScreen> {
  List<UserModel> _users = [];
  bool _loading = true;
  String _search = '';

  @override
  void initState() { 
    super.initState(); 
    _load(); 
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final users = await ref.read(apiProvider).getUsers();
      setState(() { 
        _users = users; 
        _loading = false; 
      });
    } catch (_) { 
      setState(() => _loading = false); 
    }
  }

  List<UserModel> get _filtered => _search.isEmpty
      ? _users
      : _users.where((u) =>
          u.fullName.toLowerCase().contains(_search.toLowerCase()) ||
          u.username.toLowerCase().contains(_search.toLowerCase())).toList();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('User Management'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
          IconButton(
            icon: const Icon(Icons.person_add),
            onPressed: () async {
              await context.push('/admin/users/new');
              _load();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              onChanged: (v) => setState(() => _search = v),
              decoration: InputDecoration(
                hintText: 'Search users...',
                prefixIcon: const Icon(Icons.search),
                isDense: true,
                filled: true,
                fillColor: Colors.grey[100],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _filtered.length,
                    itemBuilder: (_, i) => _UserTile(
                      user: _filtered[i],
                      onToggle: () => _toggleUser(_filtered[i]),
                      onEdit: () async {
                        await context.push('/admin/users/${_filtered[i].id}/edit');
                        _load();
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleUser(UserModel user) async {
    try {
      await ref.read(apiProvider).updateUser(user.id, {'is_active': !user.isActive});
      _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red)
        );
      }
    }
  }
}

class _UserTile extends StatelessWidget {
  final UserModel user;
  final VoidCallback onToggle;
  final VoidCallback onEdit;
  
  const _UserTile({
    required this.user, 
    required this.onToggle, 
    required this.onEdit,
  });

  Color _roleColor(String role) {
    switch (role) {
      case 'admin': return Colors.red;
      case 'manager': return Colors.purple;
      case 'waiter': return Colors.blue;
      case 'cashier': return Colors.green;
      case 'kitchen': return Colors.orange;
      case 'bar': return Colors.teal;
      default: return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _roleColor(user.role);
    
    // Use Opacity widget to wrap the entire Card for opacity effect
    return Opacity(
      opacity: user.isActive ? 1.0 : 0.5,
      child: Card(
        margin: const EdgeInsets.only(bottom: 8),
        child: ListTile(
          leading: CircleAvatar(
            backgroundColor: color.withOpacity(0.15),
            child: Text(
              user.fullName.isNotEmpty ? user.fullName[0].toUpperCase() : '?',
              style: TextStyle(color: color, fontWeight: FontWeight.bold),
            ),
          ),
          title: Row(
            children: [
              Text(user.fullName, style: const TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(width: 8),
              if (!user.isActive)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text('Inactive', style: TextStyle(fontSize: 10, color: Colors.grey)),
                ),
            ],
          ),
          subtitle: Text('@${user.username} • ${user.email ?? 'No email'}'),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  user.role.toUpperCase(),
                  style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.bold),
                ),
              ),
              PopupMenuButton<String>(
                onSelected: (v) {
                  if (v == 'edit') onEdit();
                  if (v == 'toggle') onToggle();
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(
                    value: 'edit', 
                    child: ListTile(
                      leading: Icon(Icons.edit), 
                      title: Text('Edit'), 
                      dense: true,
                    ),
                  ),
                  PopupMenuItem(
                    value: 'toggle', 
                    child: ListTile(
                      leading: Icon(user.isActive ? Icons.block : Icons.check_circle),
                      title: Text(user.isActive ? 'Deactivate' : 'Activate'),
                      dense: true,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}