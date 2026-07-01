import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../core/config/app_theme.dart';
import '../models/app_notification.dart';
import '../services/app_notification_service.dart';
import '../widgets/app_shell.dart';

class NotificationsScreen extends StatefulWidget {
  final String slug;

  const NotificationsScreen({super.key, required this.slug});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _refresh());
  }

  Future<void> _refresh() async {
    if (_loading) return;

    setState(() => _loading = true);
    try {
      await context.read<AppNotificationService>().refresh();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final service = context.watch<AppNotificationService>();
    final notifications = service.notifications;

    return AppShell(
      title: 'Notificações',
      slug: widget.slug,
      currentRoute: 'notifications',
      actions: [
        IconButton(
          tooltip: 'Atualizar',
          onPressed: _loading ? null : _refresh,
          icon: const Icon(Icons.refresh),
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text(
                '${service.unreadCount} não lida(s)',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              if (_loading)
                const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: Card(
              clipBehavior: Clip.antiAlias,
              child: notifications.isEmpty && _loading
                  ? const Center(child: CircularProgressIndicator())
                  : notifications.isEmpty
                      ? const Center(
                          child: Text('Nenhuma notificação encontrada.'),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.all(12),
                          itemCount: notifications.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final notification = notifications[index];
                            return _NotificationTile(
                              notification: notification,
                              onTap: () => _openNotification(notification),
                            );
                          },
                        ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openNotification(AppNotification notification) async {
    await context.read<AppNotificationService>().markAsRead(notification.id);

    if (!mounted) return;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(notification.title),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  notification.message.isEmpty
                      ? 'Sem mensagem adicional.'
                      : notification.message,
                ),
                const SizedBox(height: 16),
                Text(
                  _formatDate(notification.createdAt),
                  style: Theme.of(dialogContext).textTheme.bodySmall,
                ),
                if (notification.videoUrl != null) ...[
                  const SizedBox(height: 12),
                  SelectableText(notification.videoUrl!),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Fechar'),
            ),
          ],
        );
      },
    );
  }
}

class _NotificationTile extends StatelessWidget {
  final AppNotification notification;
  final VoidCallback onTap;

  const _NotificationTile({
    required this.notification,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final unread = notification.isUnread;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      leading: CircleAvatar(
        backgroundColor: unread
            ? AppTheme.primary
            : AppTheme.secondary.withValues(alpha: 0.1),
        foregroundColor: unread ? Colors.white : AppTheme.secondary,
        child: Icon(
          unread
              ? Icons.notifications_active_outlined
              : Icons.notifications_none_outlined,
        ),
      ),
      title: Text(
        notification.title,
        style: TextStyle(
          fontWeight: unread ? FontWeight.w800 : FontWeight.w600,
        ),
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Text(
          notification.message.isEmpty
              ? _formatDate(notification.createdAt)
              : notification.message,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            _formatDate(notification.createdAt),
            style: Theme.of(context).textTheme.labelSmall,
          ),
          const SizedBox(height: 6),
          if (unread)
            Container(
              width: 10,
              height: 10,
              decoration: const BoxDecoration(
                color: AppTheme.primary,
                shape: BoxShape.circle,
              ),
            ),
        ],
      ),
      onTap: onTap,
    );
  }
}

String _formatDate(DateTime? date) {
  if (date == null) return '-';
  return DateFormat('dd/MM/yyyy HH:mm').format(date.toLocal());
}
