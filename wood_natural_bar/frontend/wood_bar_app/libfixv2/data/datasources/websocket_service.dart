import 'dart:async';
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../../core/constants/app_constants.dart';

enum WsConnectionState { disconnected, connecting, connected, error }

class WsMessage {
  final String type;
  final dynamic data;

  const WsMessage({required this.type, required this.data});

  factory WsMessage.fromJson(Map<String, dynamic> json) =>
      WsMessage(type: json['type'] ?? '', data: json['data']);
}

final wsServiceProvider = Provider<WebSocketService>((ref) => WebSocketService());

class WebSocketService {
  WebSocketChannel? _channel;
  final _storage = const FlutterSecureStorage();
  final StreamController<WsMessage> _messageController =
      StreamController<WsMessage>.broadcast();
  final StreamController<WsConnectionState> _stateController =
      StreamController<WsConnectionState>.broadcast();

  Timer? _pingTimer;
  Timer? _reconnectTimer;
  String? _currentRole;
  String? _baseUrl;
  bool _shouldReconnect = false;

  Stream<WsMessage> get messages => _messageController.stream;
  Stream<WsConnectionState> get connectionState => _stateController.stream;

  // Filtered message streams
  Stream<WsMessage> get newOrders =>
      messages.where((m) => m.type == 'new_order');
  Stream<WsMessage> get orderUpdates =>
      messages.where((m) => m.type == 'order_update');
  Stream<WsMessage> get itemReady =>
      messages.where((m) => m.type == 'item_ready');
  Stream<WsMessage> get orderComplete =>
      messages.where((m) => m.type == 'order_complete');
  Stream<WsMessage> get tableStatus =>
      messages.where((m) => m.type == 'table_status');
  Stream<WsMessage> get paymentComplete =>
      messages.where((m) => m.type == 'payment_complete');
  Stream<WsMessage> get stockAlerts =>
      messages.where((m) => m.type == 'stock_alert');
  Stream<WsMessage> get voidRequests =>
      messages.where((m) => m.type == 'void_request');

  Future<void> connect(String baseUrl, String role) async {
    _currentRole = role;
    _baseUrl = baseUrl;
    _shouldReconnect = true;
    await _connect();
  }

  Future<void> _connect() async {
    _stateController.add(WsConnectionState.connecting);

    final token = await _storage.read(key: AppConstants.accessTokenKey);
    if (token == null) {
      _stateController.add(WsConnectionState.error);
      return;
    }

    final wsUrl = _baseUrl!
        .replaceFirst('http://', 'ws://')
        .replaceFirst('https://', 'wss://');

    final uri = Uri.parse('$wsUrl/ws/$_currentRole?token=$token');

    try {
      _channel = WebSocketChannel.connect(uri);
      await _channel!.ready;
      _stateController.add(WsConnectionState.connected);

      _channel!.stream.listen(
        (data) {
          try {
            final msg = WsMessage.fromJson(json.decode(data));
            _messageController.add(msg);
          } catch (_) {}
        },
        onDone: () {
          _stateController.add(WsConnectionState.disconnected);
          _scheduleReconnect();
        },
        onError: (_) {
          _stateController.add(WsConnectionState.error);
          _scheduleReconnect();
        },
      );

      // Start ping timer
      _pingTimer?.cancel();
      _pingTimer = Timer.periodic(const Duration(seconds: 30), (_) {
        send({'type': 'ping'});
      });
    } catch (e) {
      _stateController.add(WsConnectionState.error);
      _scheduleReconnect();
    }
  }

  void _scheduleReconnect() {
    if (!_shouldReconnect) return;
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 5), () {
      if (_shouldReconnect) _connect();
    });
  }

  void send(Map<String, dynamic> data) {
    try {
      _channel?.sink.add(json.encode(data));
    } catch (_) {}
  }

  void disconnect() {
    _shouldReconnect = false;
    _pingTimer?.cancel();
    _reconnectTimer?.cancel();
    _channel?.sink.close();
    _stateController.add(WsConnectionState.disconnected);
  }

  void dispose() {
    disconnect();
    _messageController.close();
    _stateController.close();
  }
}
