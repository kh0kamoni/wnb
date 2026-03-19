import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/providers.dart';
import '../../../data/datasources/api_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/models.dart';

class UserFormScreen extends ConsumerStatefulWidget {
  final int? userId;
  const UserFormScreen({super.key, this.userId});
  @override
  ConsumerState<UserFormScreen> createState() => _UserFormScreenState();
}

class _UserFormScreenState extends ConsumerState<UserFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _usernameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _pinCtrl = TextEditingController();
  String _role = 'waiter';
  bool _loading = false;
  bool _loadingData = false;
  bool _obscurePass = true;

  final _roles = ['admin', 'manager', 'waiter', 'cashier', 'kitchen', 'bar'];

  @override
  void initState() {
    super.initState();
    if (widget.userId != null) _loadUser();
  }

  Future<void> _loadUser() async {
    setState(() => _loadingData = true);
    try {
      final users = await ref.read(apiProvider).getUsers();
      final user = users.firstWhere((u) => u.id == widget.userId);
      _nameCtrl.text = user.fullName;
      _usernameCtrl.text = user.username;
      _emailCtrl.text = user.email ?? '';
      _phoneCtrl.text = user.phone ?? '';
      setState(() { _role = user.role; _loadingData = false; });
    } catch (_) { setState(() => _loadingData = false); }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      final data = {
        'full_name': _nameCtrl.text.trim(),
        'username': _usernameCtrl.text.trim(),
        'email': _emailCtrl.text.trim().isEmpty ? null : _emailCtrl.text.trim(),
        'phone': _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
        'role': _role,
        if (_pinCtrl.text.isNotEmpty) 'pin_code': _pinCtrl.text.trim(),
      };
      if (widget.userId == null) {
        data['password'] = _passCtrl.text;
        await ref.read(apiProvider).createUser(data);
      } else {
        await ref.read(apiProvider).updateUser(widget.userId!, data);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(widget.userId == null ? 'User created!' : 'User updated!'),
          backgroundColor: Colors.green,
        ));
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
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.userId == null ? 'New User' : 'Edit User'),
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
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 600),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _section('Personal Information', [
                        TextFormField(
                          controller: _nameCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Full Name *',
                            prefixIcon: Icon(Icons.person_outline),
                          ),
                          validator: (v) => v?.isEmpty == true ? 'Required' : null,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _usernameCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Username *',
                            prefixIcon: Icon(Icons.alternate_email),
                          ),
                          validator: (v) => v?.isEmpty == true ? 'Required' : null,
                          enabled: widget.userId == null,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _emailCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Email',
                            prefixIcon: Icon(Icons.email_outlined),
                          ),
                          keyboardType: TextInputType.emailAddress,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _phoneCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Phone',
                            prefixIcon: Icon(Icons.phone_outlined),
                          ),
                          keyboardType: TextInputType.phone,
                        ),
                      ]),
                      const SizedBox(height: 20),
                      _section('Role & Access', [
                        const Text('Role *', style: TextStyle(fontWeight: FontWeight.w500, fontSize: 13)),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8, runSpacing: 8,
                          children: _roles.map((r) {
                            final selected = _role == r;
                            return ChoiceChip(
                              label: Text(r.toUpperCase(),
                                style: TextStyle(fontSize: 12,
                                  color: selected ? Colors.white : null)),
                              selected: selected,
                              onSelected: (_) => setState(() => _role = r),
                              selectedColor: AppColors.primary,
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _pinCtrl,
                          decoration: const InputDecoration(
                            labelText: 'PIN Code (4-6 digits for quick login)',
                            prefixIcon: Icon(Icons.dialpad),
                          ),
                          keyboardType: TextInputType.number,
                          maxLength: 6,
                        ),
                      ]),
                      if (widget.userId == null) ...[ 
                        const SizedBox(height: 20),
                        _section('Password', [
                          TextFormField(
                            controller: _passCtrl,
                            obscureText: _obscurePass,
                            decoration: InputDecoration(
                              labelText: 'Password *',
                              prefixIcon: const Icon(Icons.lock_outline),
                              suffixIcon: IconButton(
                                icon: Icon(_obscurePass
                                    ? Icons.visibility_off_outlined
                                    : Icons.visibility_outlined),
                                onPressed: () => setState(() => _obscurePass = !_obscurePass),
                              ),
                            ),
                            validator: (v) => (v?.length ?? 0) < 6
                                ? 'Minimum 6 characters' : null,
                          ),
                        ]),
                      ],
                    ],
                  ),
                ),
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
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            const Divider(height: 20),
            ...children,
          ],
        ),
      ),
    );
  }
}
