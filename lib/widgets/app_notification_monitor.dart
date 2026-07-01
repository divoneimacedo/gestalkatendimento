import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../controllers/auth_controller.dart';
import '../core/config/app_config.dart';
import '../core/router/app_router.dart';
import '../models/app_notification.dart';
import '../services/app_notification_service.dart';
import '../services/heartbeat_service.dart';
import '../services/notification_service.dart';

class AppNotificationMonitor extends StatefulWidget {
  final Widget child;

  const AppNotificationMonitor({super.key, required this.child});

  @override
  State<AppNotificationMonitor> createState() => _AppNotificationMonitorState();
}

class _AppNotificationMonitorState extends State<AppNotificationMonitor> {
  bool _running = false;
  String? _activeUserId;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void dispose() {
    _stop();
    super.dispose();
  }

  void _sync() {
    final auth = context.watch<AuthController>();

    final userId = auth.user?.id;

    if (!auth.isAuthenticated || userId == null || userId.isEmpty) {
      _stop();
      return;
    }

    if (_running && _activeUserId == userId) return;

    _stop(clearSessionId: _activeUserId != userId);
    _running = true;
    _activeUserId = userId;
    context.read<HeartbeatService>().start();
    context.read<AppNotificationService>().start(
          onNotification: _handleNotification,
        );
  }

  void _stop({bool clearSessionId = true}) {
    if (!_running) return;

    _running = false;
    _activeUserId = null;
    context.read<HeartbeatService>().stop();
    context.read<AppNotificationService>().stop();

    if (clearSessionId) {
      unawaited(context.read<HeartbeatService>().clearSessionId());
    }
  }

  Future<void> _handleNotification(AppNotification notification) async {
    if (!mounted) return;

    final nativeNotifications = context.read<NotificationService>();

    try {
      await nativeNotifications.showNotification(
        title: notification.title,
        body: notification.message,
      );
    } catch (_) {
      // O SnackBar continua funcionando mesmo sem notificacao nativa.
    }

    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(notification.title),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 12),
          action: SnackBarAction(
            label: 'Ver',
            onPressed: _goToNotifications,
          ),
        ),
      );
  }

  void _goToNotifications() {
    final auth = context.read<AuthController>();
    final slug = auth.slug ?? AppConfig.defaultSlug;
    final routerContext = AppRouter.rootNavigatorKey.currentContext;

    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    if (routerContext != null) {
      GoRouter.of(routerContext).go('/notifications/$slug');
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
