import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api/api_service.dart';

class HeartbeatService {
  static const _sessionIdKey = 'gestalk.desktop.sessionId';
  static const _interval = Duration(seconds: 5);

  final ApiService apiService;

  Timer? _timer;
  String? _sessionId;

  HeartbeatService(this.apiService);

  bool get isActive => _timer != null;

  Future<void> start() async {
    if (_timer != null) return;

    await _sendHeartbeat();
    _timer = Timer.periodic(_interval, (_) => _sendHeartbeat());
    debugPrint('Heartbeat desktop iniciado');
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
    debugPrint('Heartbeat desktop parado');
  }

  Future<void> clearSessionId() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_sessionIdKey);
    _sessionId = null;
  }

  Future<String> _getSessionId() async {
    if (_sessionId != null) return _sessionId!;

    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_sessionIdKey);

    if (stored != null && stored.isNotEmpty) {
      _sessionId = stored;
      return stored;
    }

    final nextSessionId =
        'flutter_${Platform.operatingSystem}_${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(999999)}';
    await prefs.setString(_sessionIdKey, nextSessionId);
    _sessionId = nextSessionId;
    return nextSessionId;
  }

  Future<void> _sendHeartbeat() async {
    try {
      await apiService.dio.post<dynamic>(
        '/user/heartbeat',
        data: {
          'sessionId': await _getSessionId(),
          'platform': 'flutter-desktop-${Platform.operatingSystem}',
        },
      );
    } catch (error) {
      debugPrint('Heartbeat desktop falhou: $error');
    }
  }
}
