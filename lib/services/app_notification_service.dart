import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/app_notification.dart';
import 'api/api_service.dart';

typedef AppNotificationHandler = FutureOr<void> Function(
  AppNotification notification,
);

class AppNotificationService extends ChangeNotifier {
  static const _interval = Duration(seconds: 20);

  final ApiService apiService;
  final Set<String> _shownNotificationIds = {};
  List<AppNotification> _notifications = [];

  Timer? _timer;
  bool _checking = false;

  AppNotificationService(this.apiService);

  bool get isActive => _timer != null;
  List<AppNotification> get notifications => List.unmodifiable(_notifications);
  int get unreadCount =>
      _notifications.where((notification) => notification.isUnread).length;

  void start({required AppNotificationHandler onNotification}) {
    if (_timer != null) return;

    unawaited(_check(onNotification));
    _timer = Timer.periodic(_interval, (_) => _check(onNotification));
    debugPrint('Monitor de notificacoes desktop iniciado');
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
    _checking = false;
    debugPrint('Monitor de notificacoes desktop parado');
  }

  Future<List<AppNotification>> fetchNotifications() async {
    final response = await apiService.dio.get<dynamic>(
      '/notifications',
      queryParameters: {
        'page': 1,
        'limit': 10,
      },
    );

    final data = response.data;
    final rawNotifications = data is Map ? data['notifications'] : null;

    if (rawNotifications is! List) return [];

    final notifications = rawNotifications
        .whereType<Map>()
        .map(
            (item) => AppNotification.fromJson(Map<String, dynamic>.from(item)))
        .where((notification) => notification.id.isNotEmpty)
        .toList();

    _notifications = notifications;
    notifyListeners();

    return notifications;
  }

  Future<void> markAsRead(String notificationId) async {
    if (notificationId.isEmpty) return;

    await apiService.dio.patch<dynamic>(
      '/notifications/$notificationId/read',
    );

    _notifications = _notifications
        .map((notification) => notification.id == notificationId
            ? notification.copyWith(status: 'READ')
            : notification)
        .toList();
    notifyListeners();
  }

  Future<void> refresh() async {
    await fetchNotifications();
  }

  Future<void> _check(AppNotificationHandler onNotification) async {
    if (_checking) return;

    _checking = true;
    try {
      final notifications = await fetchNotifications();
      final unread = notifications
          .where((notification) => notification.isUnread)
          .where((notification) =>
              !_shownNotificationIds.contains(notification.id))
          .toList()
        ..sort((a, b) {
          final aDate = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
          final bDate = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
          return aDate.compareTo(bDate);
        });

      for (final notification in unread) {
        _shownNotificationIds.add(notification.id);
        await onNotification(notification);
      }
    } catch (error) {
      debugPrint('Erro ao buscar notificacoes desktop: $error');
    } finally {
      _checking = false;
    }
  }
}
