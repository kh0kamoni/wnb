import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/models.dart';
import '../../../core/constants/app_constants.dart';
import '../../../data/datasources/websocket_service.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _userCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _obscurePass = true;

  Future<void> _login() async {
    final success = await ref.read(authProvider.notifier).login(
      _userCtrl.text.trim(),
      _passCtrl.text,
    );
    if (success && mounted) {
      final user = ref.read(authProvider).user!;
      if (user.isKitchen || user.isBar) {
        context.go('/kitchen');
      } else if (user.isCashier) {
        context.go('/cashier');
      } else {
        context.go('/home');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final size = MediaQuery.of(context).size;

    return Scaffold(
      body: Row(
        children: [
          // Left panel - branding
          if (size.width > 700)
            Expanded(
              flex: 2,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppColors.primaryDark,
                      AppColors.primary,
                      AppColors.primaryLight,
                    ],
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 120, height: 120,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(30),
                        border: Border.all(color: Colors.white30, width: 2),
                      ),
                      child: const Icon(Icons.eco_rounded, size: 70, color: Colors.white),
                    ),
                    const SizedBox(height: 32),
                    const Text('Wood Natural Bar',
                      style: TextStyle(
                        color: Colors.white, fontSize: 28,
                        fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                    const SizedBox(height: 8),
                    const Text('Fresh & Natural',
                      style: TextStyle(color: Colors.white70, fontSize: 16)),
                    const SizedBox(height: 60),
                    _featureBadge(Icons.point_of_sale, 'Point of Sale'),
                    _featureBadge(Icons.kitchen, 'Kitchen Display'),
                    _featureBadge(Icons.table_restaurant, 'Table Management'),
                    _featureBadge(Icons.bar_chart, 'Analytics & Reports'),
                  ],
                ),
              ),
            ),

          // Right panel - login form
          Expanded(
            flex: 3,
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(40),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (size.width <= 700) ...[
                        const Icon(Icons.eco_rounded, size: 60, color: Color(0xFF2E7D32)),
                        const SizedBox(height: 12),
                        const Text('Wood Natural Bar',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 32),
                      ],
                      const Text('Welcome back',
                        style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 6),
                      const Text('Sign in to your POS account',
                        style: TextStyle(color: Colors.grey, fontSize: 14)),
                      const SizedBox(height: 40),
                      TextField(
                        controller: _userCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Username',
                          prefixIcon: Icon(Icons.person_outline),
                        ),
                        textInputAction: TextInputAction.next,
                        onSubmitted: (_) => FocusScope.of(context).nextFocus(),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _passCtrl,
                        obscureText: _obscurePass,
                        decoration: InputDecoration(
                          labelText: 'Password',
                          prefixIcon: const Icon(Icons.lock_outline),
                          suffixIcon: IconButton(
                            icon: Icon(_obscurePass
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined),
                            onPressed: () => setState(() => _obscurePass = !_obscurePass),
                          ),
                        ),
                        onSubmitted: (_) => _login(),
                      ),
                      if (auth.error != null) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.red.shade200),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.error_outline, color: Colors.red, size: 16),
                              const SizedBox(width: 8),
                              Expanded(child: Text(auth.error!,
                                style: const TextStyle(color: Colors.red, fontSize: 13))),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 28),
                      SizedBox(
                        height: 52,
                        child: ElevatedButton(
                          onPressed: auth.isLoading ? null : _login,
                          child: auth.isLoading
                              ? const SizedBox(
                                  width: 20, height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white))
                              : const Text('Sign In', style: TextStyle(fontSize: 16)),
                        ),
                      ),
                      const SizedBox(height: 16),
                      OutlinedButton.icon(
                        onPressed: () => context.go('/auth/pin'),
                        icon: const Icon(Icons.dialpad),
                        label: const Text('Login with PIN'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                      const SizedBox(height: 24),
                      TextButton.icon(
                        onPressed: () => context.go('/setup'),
                        icon: const Icon(Icons.settings_outlined, size: 16),
                        label: const Text('Change Server', style: TextStyle(fontSize: 12)),
                        style: TextButton.styleFrom(foregroundColor: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _featureBadge(IconData icon, String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 40),
      child: Row(
        children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: Colors.white, size: 18),
          ),
          const SizedBox(width: 12),
          Text(label, style: const TextStyle(color: Colors.white, fontSize: 14)),
        ],
      ),
    );
  }
}
