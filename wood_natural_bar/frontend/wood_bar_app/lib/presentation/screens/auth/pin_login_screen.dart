import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/providers.dart';
import '../../../data/models/models.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/datasources/websocket_service.dart';

class PinLoginScreen extends ConsumerStatefulWidget {
  const PinLoginScreen({super.key});

  @override
  ConsumerState<PinLoginScreen> createState() => _PinLoginScreenState();
}

class _PinLoginScreenState extends ConsumerState<PinLoginScreen> {
  String _pin = '';
  bool _shake = false;

  void _addDigit(String digit) {
    if (_pin.length >= 6) return;
    setState(() => _pin += digit);
    if (_pin.length >= 4) _tryLogin();
  }

  void _removeDigit() {
    if (_pin.isEmpty) return;
    setState(() => _pin = _pin.substring(0, _pin.length - 1));
  }

  Future<void> _tryLogin() async {
    final auth = ref.read(authProvider);
    if (auth.isLoading) return;

    final success = await ref.read(authProvider.notifier).pinLogin(_pin);
    if (success && mounted) {
      final user = ref.read(authProvider).user!;
      if (user.isKitchen || user.isBar) {
        context.go('/kitchen');
      } else if (user.isCashier) {
        context.go('/cashier');
      } else {
        context.go('/home');
      }
    } else {
      setState(() { _pin = ''; _shake = true; });
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) setState(() => _shake = false);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter, end: Alignment.bottomCenter,
            colors: [Color(0xFF1B5E20), Color(0xFF2E7D32)],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 360),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.lock_outline, size: 48, color: Colors.white70),
                  const SizedBox(height: 16),
                  const Text('Enter PIN',
                    style: TextStyle(color: Colors.white, fontSize: 22,
                      fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  const Text('Use your staff PIN to login',
                    style: TextStyle(color: Colors.white60, fontSize: 13)),
                  const SizedBox(height: 40),

                  // PIN dots
                  AnimatedSlide(
                    offset: _shake ? const Offset(0.05, 0) : Offset.zero,
                    duration: const Duration(milliseconds: 100),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(6, (i) => Container(
                        margin: const EdgeInsets.symmetric(horizontal: 6),
                        width: 16, height: 16,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: i < _pin.length
                              ? Colors.white
                              : Colors.white.withOpacity(0.3),
                          border: Border.all(color: Colors.white54),
                        ),
                      )),
                    ),
                  ),

                  if (auth.error != null) ...[
                    const SizedBox(height: 16),
                    Text('Invalid PIN', style: const TextStyle(color: Colors.redAccent)),
                  ],

                  const SizedBox(height: 40),

                  // Keypad
                  for (final row in [
                    ['1','2','3'],
                    ['4','5','6'],
                    ['7','8','9'],
                    ['','0','⌫'],
                  ])
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: row.map((digit) => Container(
                          margin: const EdgeInsets.symmetric(horizontal: 8),
                          child: digit.isEmpty
                              ? const SizedBox(width: 72, height: 72)
                              : Material(
                                  color: Colors.white.withOpacity(
                                    digit == '⌫' ? 0.1 : 0.15),
                                  borderRadius: BorderRadius.circular(36),
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(36),
                                    onTap: () => digit == '⌫'
                                        ? _removeDigit()
                                        : _addDigit(digit),
                                    child: SizedBox(
                                      width: 72, height: 72,
                                      child: Center(
                                        child: digit == '⌫'
                                            ? const Icon(Icons.backspace_outlined,
                                                color: Colors.white, size: 24)
                                            : Text(digit,
                                                style: const TextStyle(
                                                  color: Colors.white, fontSize: 24,
                                                  fontWeight: FontWeight.w500)),
                                      ),
                                    ),
                                  ),
                                ),
                        )).toList(),
                      ),
                    ),

                  const SizedBox(height: 24),
                  TextButton(
                    onPressed: () => context.go('/auth/login'),
                    child: const Text('Use Password Instead',
                      style: TextStyle(color: Colors.white70)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
