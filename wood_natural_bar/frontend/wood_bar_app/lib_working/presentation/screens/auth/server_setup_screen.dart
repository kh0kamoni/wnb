import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dio/dio.dart';
import '../../../core/constants/app_constants.dart';
import '../../../data/datasources/api_service.dart';
import '../../providers/providers.dart';
import '../../../data/models/models.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/datasources/websocket_service.dart';

class ServerSetupScreen extends ConsumerStatefulWidget {
  const ServerSetupScreen({super.key});

  @override
  ConsumerState<ServerSetupScreen> createState() => _ServerSetupScreenState();
}

class _ServerSetupScreenState extends ConsumerState<ServerSetupScreen> {
  final _urlController = TextEditingController();
  bool _isChecking = false;
  bool? _connectionOk;
  String? _serverName;
  String _error = '';

  @override
  void initState() {
    super.initState();
    _loadSavedUrl();
  }

  Future<void> _loadSavedUrl() async {
    final prefs = ref.read(sharedPrefsProvider);
    final saved = prefs.getString(AppConstants.serverUrlKey);
    if (saved != null) {
      _urlController.text = saved;
      // Auto-connect if already configured
      await _checkConnection(saved, autoNavigate: true);
    } else {
      _urlController.text = AppConstants.defaultBaseUrl;
    }
  }

  Future<void> _checkConnection(String url, {bool autoNavigate = false}) async {
    setState(() { _isChecking = true; _connectionOk = null; _error = ''; });
    try {
      final dio = Dio(BaseOptions(connectTimeout: const Duration(seconds: 5)));
      final res = await dio.get('$url/health');
      setState(() {
        _connectionOk = true;
        _serverName = res.data['restaurant'] ?? 'Restaurant POS';
        _isChecking = false;
      });
      if (autoNavigate) _proceed(url);
    } catch (e) {
      setState(() {
        _connectionOk = false;
        _error = 'Cannot connect to server. Check IP and ensure server is running.';
        _isChecking = false;
      });
    }
  }

  Future<void> _proceed(String url) async {
    final prefs = ref.read(sharedPrefsProvider);
    await prefs.setString(AppConstants.serverUrlKey, url);
    ref.read(apiProvider).setBaseUrl(url);
    if (mounted) context.go('/auth/login');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF1B5E20), Color(0xFF2E7D32), Color(0xFF388E3C)],
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 500),
              child: Card(
                elevation: 20,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                child: Padding(
                  padding: const EdgeInsets.all(40),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 80, height: 80,
                        decoration: BoxDecoration(
                          color: const Color(0xFF2E7D32),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Icon(Icons.restaurant, size: 48, color: Colors.white),
                      ),
                      const SizedBox(height: 24),
                      const Text('Wood Natural Bar',
                        style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                      const Text('POS System Setup',
                        style: TextStyle(color: Colors.grey, fontSize: 14)),
                      const SizedBox(height: 32),
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text('Server Address',
                          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _urlController,
                        decoration: InputDecoration(
                          hintText: 'http://192.168.1.100:8000',
                          prefixIcon: const Icon(Icons.dns_outlined),
                          suffixIcon: _connectionOk == true
                              ? const Icon(Icons.check_circle, color: Colors.green)
                              : _connectionOk == false
                                  ? const Icon(Icons.error, color: Colors.red)
                                  : null,
                        ),
                        keyboardType: TextInputType.url,
                      ),
                      if (_error.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(_error,
                          style: const TextStyle(color: Colors.red, fontSize: 12)),
                      ],
                      if (_serverName != null) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.green.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.green.shade200),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.check_circle, color: Colors.green, size: 16),
                              const SizedBox(width: 8),
                              Text('Connected to: $_serverName',
                                style: const TextStyle(color: Colors.green, fontSize: 13)),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _isChecking
                              ? null
                              : () => _checkConnection(_urlController.text.trim()),
                          icon: _isChecking
                              ? const SizedBox(
                                  width: 16, height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white))
                              : const Icon(Icons.wifi_find),
                          label: Text(_isChecking ? 'Connecting...' : 'Connect to Server'),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                        ),
                      ),
                      if (_connectionOk == true) ...[
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: () => _proceed(_urlController.text.trim()),
                            icon: const Icon(Icons.login),
                            label: const Text('Continue to Login'),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 24),
                      Text(
                        'Default: ${AppConstants.defaultBaseUrl}\n'
                        'Or find server at woodbar-server.local:8000',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.grey, fontSize: 11),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
