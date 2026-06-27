import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../controllers/auth_controller.dart';
import '../controllers/queue_controller.dart';
import '../core/router/app_router.dart';

class CallAlertMonitor extends StatefulWidget {
  final Widget child;

  const CallAlertMonitor({super.key, required this.child});

  @override
  State<CallAlertMonitor> createState() => _CallAlertMonitorState();
}

class _CallAlertMonitorState extends State<CallAlertMonitor> {
  Timer? _timer;
  Set<String> _knownCallIds = {};
  String? _activeSlug;
  bool _firstCheck = true;
  bool _checking = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncMonitor();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _syncMonitor() {
    final auth = context.watch<AuthController>();
    final user = auth.user;
    final slug = auth.slug;
    final canReceiveCalls = auth.isAuthenticated &&
        slug != null &&
        slug.isNotEmpty &&
        !(user?.isAdmin ?? false) &&
        (user?.permissions.contains('call') ?? false);

    if (!canReceiveCalls) {
      _stopMonitor();
      return;
    }

    if (_activeSlug == slug && _timer != null) return;

    _stopMonitor();
    _activeSlug = slug;
    _firstCheck = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _checkQueue();
    });
    _timer = Timer.periodic(const Duration(seconds: 15), (_) => _checkQueue());
  }

  void _stopMonitor() {
    _timer?.cancel();
    _timer = null;
    _activeSlug = null;
    _firstCheck = true;
    _knownCallIds = {};
  }

  Future<void> _checkQueue() async {
    if (_checking || !mounted || _activeSlug == null) return;

    _checking = true;
    final queue = context.read<QueueController>();

    try {
      await queue.refresh(slug: _activeSlug!, enableAlerts: false);

      if (!mounted) return;

      final currentCallIds = queue.calls.map((call) => call.id).toSet();
      final newCallIds = currentCallIds.difference(_knownCallIds);
      final hasCalls = currentCallIds.isNotEmpty;
      final shouldAlert = _firstCheck ? hasCalls : newCallIds.isNotEmpty;

      if (hasCalls) {
        await queue.soundService.startContinuousAlert();
      } else {
        await queue.soundService.stop();
        if (mounted) {
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
        }
      }

      if (shouldAlert) {
        try {
          await queue.notificationService.showNewCall(count: queue.calls.length);
        } catch (_) {
          // O SnackBar e o som continuam funcionando mesmo se a notificação
          // nativa não estiver disponível no sistema operacional.
        }
        _showQueueSnackBar(queue.calls.length);
      }

      _knownCallIds = currentCallIds;
      _firstCheck = false;
    } finally {
      _checking = false;
    }
  }

  void _showQueueSnackBar(int count) {
    final messenger = ScaffoldMessenger.of(context);

    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            count > 1
                ? 'Você tem $count atendimentos aguardando.'
                : 'Você tem um novo atendimento aguardando.',
          ),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 12),
          action: SnackBarAction(
            label: 'Ver fila',
            onPressed: () {
              final slug = _activeSlug;
              if (slug == null) return;
              final routerContext = AppRouter.rootNavigatorKey.currentContext;
              if (routerContext == null) return;
              GoRouter.of(routerContext).go('/queue/$slug');
            },
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
