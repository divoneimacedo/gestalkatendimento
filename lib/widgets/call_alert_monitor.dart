import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../controllers/auth_controller.dart';
import '../controllers/queue_controller.dart';
import '../core/router/app_router.dart';
import '../core/config/app_theme.dart';
import '../models/queue_call.dart';
import '../services/tray_service.dart';

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
    final wasRunning =
        _timer != null || _activeSlug != null || _knownCallIds.isNotEmpty;

    _timer?.cancel();
    _timer = null;
    _activeSlug = null;
    _firstCheck = true;
    _knownCallIds = {};

    if (mounted && wasRunning) {
      _hideSnackBarSafely();
      unawaited(context.read<AppTrayService>().clearWaitingCalls());
    }
  }

  Future<void> _checkQueue() async {
    if (_checking || !mounted || _activeSlug == null) return;

    _checking = true;
    final queue = context.read<QueueController>();
    final tray = context.read<AppTrayService>();

    try {
      if (_isInCallRoute()) {
        await queue.soundService.stop();
        await tray.clearWaitingCalls();
        _knownCallIds = {};
        _firstCheck = true;
        if (mounted) _hideSnackBarSafely();
        return;
      }

      await queue.refresh(slug: _activeSlug!, enableAlerts: false);

      if (!mounted) return;

      final currentCallIds = queue.calls.map((call) => call.id).toSet();
      final removedCallIds = _knownCallIds.difference(currentCallIds);
      final newCallIds = currentCallIds.difference(_knownCallIds);
      final hasCalls = currentCallIds.isNotEmpty;
      final shouldAlert = _firstCheck ? hasCalls : newCallIds.isNotEmpty;

      if (hasCalls) {
        await queue.soundService.startContinuousAlert();
        await tray.showWaitingCalls(queue.calls.length);
      } else {
        await queue.soundService.stop();
        await tray.clearWaitingCalls();
        if (mounted) {
          _hideSnackBarSafely();
        }
      }

      if (removedCallIds.isNotEmpty && mounted) {
        _hideSnackBarSafely();
      }

      if (shouldAlert) {
        try {
          await queue.notificationService
              .showNewCall(count: queue.calls.length);
        } catch (_) {
          // O SnackBar e o som continuam funcionando mesmo se a notificação
          // nativa não estiver disponível no sistema operacional.
        }
        _showQueueSnackBar(queue.calls.first, queue.calls.length);
      }

      _knownCallIds = currentCallIds;
      _firstCheck = false;
    } finally {
      _checking = false;
    }
  }

  void _showQueueSnackBar(QueueCall call, int count) {
    final messenger = ScaffoldMessenger.of(context);

    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: _CallSnackContent(
            call: call,
            count: count,
            onAccept: () => _acceptCallFromSnack(call),
            onCancel: () => _cancelCallFromSnack(call),
            onOpenQueue: _openQueue,
          ),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 20),
        ),
      );
  }

  Future<void> _acceptCallFromSnack(QueueCall call) async {
    final slug = _activeSlug;
    if (slug == null || !mounted) return;

    final queue = context.read<QueueController>();
    final auth = context.read<AuthController>();
    final attendantId = auth.user?.id ?? '';
    final routerContext = AppRouter.rootNavigatorKey.currentContext;
    final router = routerContext == null ? null : GoRouter.of(routerContext);

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    await queue.accept(call, attendantId);

    if (!mounted || router == null) return;
    router.go('/call/$slug/${call.id}');
  }

  Future<void> _cancelCallFromSnack(QueueCall call) async {
    final slug = _activeSlug;
    if (slug == null || !mounted) return;

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    await context.read<QueueController>().cancel(call.id, slug);
  }

  void _openQueue() {
    final slug = _activeSlug;
    if (slug == null) return;

    final routerContext = AppRouter.rootNavigatorKey.currentContext;
    if (routerContext == null) return;
    GoRouter.of(routerContext).go('/queue/$slug');
  }

  void _hideSnackBarSafely() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
    });
  }

  bool _isInCallRoute() {
    final routerContext = AppRouter.rootNavigatorKey.currentContext;
    if (routerContext == null) return false;

    try {
      final path = GoRouter.of(routerContext)
          .routerDelegate
          .currentConfiguration
          .uri
          .path;

      return path.startsWith('/call/');
    } catch (_) {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}

class _CallSnackContent extends StatelessWidget {
  final QueueCall call;
  final int count;
  final VoidCallback onAccept;
  final VoidCallback onCancel;
  final VoidCallback onOpenQueue;

  const _CallSnackContent({
    required this.call,
    required this.count,
    required this.onAccept,
    required this.onCancel,
    required this.onOpenQueue,
  });

  @override
  Widget build(BuildContext context) {
    final title = count > 1
        ? '$count atendimentos aguardando'
        : 'Novo atendimento aguardando';

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Icon(Icons.call, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            TextButton(
              onPressed: onOpenQueue,
              child: const Text('Ver fila'),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 14,
          runSpacing: 4,
          children: [
            _InfoText(label: 'Canal', value: call.channelName ?? '-'),
            if ((call.protocol ?? '').isNotEmpty)
              _InfoText(label: 'Protocolo', value: call.protocol!),
            _InfoText(label: 'Espera', value: call.waitingTime ?? '-'),
            if ((call.caller ?? '').isNotEmpty)
              _InfoText(label: 'Solicitante', value: call.caller!),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.success,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                ),
                onPressed: onAccept,
                icon: const Icon(Icons.call, size: 18),
                label: const Text('Atender'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.cancel,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                ),
                onPressed: onCancel,
                icon: const Icon(Icons.close, size: 18),
                label: const Text('Cancelar'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _InfoText extends StatelessWidget {
  final String label;
  final String value;

  const _InfoText({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return RichText(
      text: TextSpan(
        style: const TextStyle(color: Colors.white),
        children: [
          TextSpan(
            text: '$label: ',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
          ),
          TextSpan(
            text: value,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
