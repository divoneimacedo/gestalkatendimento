import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../controllers/auth_controller.dart';
import '../core/navigation/app_menu_destination.dart';
import '../services/app_notification_service.dart';
import 'app_menu_drawer.dart';
import 'gestalk_brand.dart';

class AppShell extends StatelessWidget {
  final String title;
  final Widget child;
  final List<Widget> actions;
  final String slug;
  final String currentRoute;

  const AppShell({
    super.key,
    required this.title,
    required this.child,
    required this.slug,
    required this.currentRoute,
    this.actions = const [],
  });

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final pagePadding = width <= 1366 ? 14.0 : 24.0;
    final auth = context.watch<AuthController>();
    final notificationService = context.watch<AppNotificationService>();
    final destinations = buildAppMenuDestinations(
      user: auth.user,
      slug: slug,
    );

    return CallbackShortcuts(
      bindings: _shortcutBindings(context, destinations),
      child: Focus(
        autofocus: true,
        child: Scaffold(
          drawer: AppMenuDrawer(slug: slug, currentRoute: currentRoute),
          appBar: AppBar(
            title: Row(
              children: [
                const GestalkBrand(logoWidth: 86),
                const SizedBox(width: 18),
                Flexible(
                  child: Text(
                    title,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            actions: [
              _UserClock(name: auth.user?.name ?? 'Usuário'),
              _NotificationButton(
                unreadCount: notificationService.unreadCount,
                onPressed: () => context.go('/notifications/$slug'),
              ),
              ...actions,
            ],
          ),
          body: Center(
            child: Padding(
              padding: EdgeInsets.all(pagePadding),
              child: SizedBox.expand(
                child: child,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Map<ShortcutActivator, VoidCallback> _shortcutBindings(
    BuildContext context,
    List<AppMenuDestination> destinations,
  ) {
    final bindings = <ShortcutActivator, VoidCallback>{};
    final keys = [
      LogicalKeyboardKey.digit1,
      LogicalKeyboardKey.digit2,
      LogicalKeyboardKey.digit3,
      LogicalKeyboardKey.digit4,
      LogicalKeyboardKey.digit5,
      LogicalKeyboardKey.digit6,
      LogicalKeyboardKey.digit7,
      LogicalKeyboardKey.digit8,
      LogicalKeyboardKey.digit9,
    ];
    final numpadKeys = [
      LogicalKeyboardKey.numpad1,
      LogicalKeyboardKey.numpad2,
      LogicalKeyboardKey.numpad3,
      LogicalKeyboardKey.numpad4,
      LogicalKeyboardKey.numpad5,
      LogicalKeyboardKey.numpad6,
      LogicalKeyboardKey.numpad7,
      LogicalKeyboardKey.numpad8,
      LogicalKeyboardKey.numpad9,
    ];

    for (var i = 0; i < destinations.length && i < keys.length; i++) {
      final destination = destinations[i];
      void callback() => _go(context, destination);

      bindings[SingleActivator(keys[i], control: true)] = callback;
      bindings[SingleActivator(numpadKeys[i], control: true)] = callback;
    }

    return bindings;
  }

  void _go(BuildContext context, AppMenuDestination destination) {
    if (currentRoute == destination.routeKey) return;

    final scaffold = Scaffold.maybeOf(context);
    if (scaffold?.isDrawerOpen ?? false) {
      Navigator.of(context).pop();
    }

    context.go(destination.path);
  }
}

class _UserClock extends StatelessWidget {
  final String name;

  const _UserClock({required this.name});

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    if (width < 900) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: StreamBuilder<DateTime>(
        stream: Stream.periodic(
          const Duration(seconds: 1),
          (_) => DateTime.now(),
        ),
        initialData: DateTime.now(),
        builder: (context, snapshot) {
          final now = snapshot.data ?? DateTime.now();
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.person_outline, size: 18),
              const SizedBox(width: 6),
              ConstrainedBox(
                constraints: BoxConstraints(maxWidth: width < 1200 ? 120 : 180),
                child: Text(
                  name,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelLarge,
                ),
              ),
              const SizedBox(width: 12),
              const Icon(Icons.schedule_outlined, size: 18),
              const SizedBox(width: 6),
              Text(
                DateFormat('dd/MM/yyyy HH:mm').format(now),
                style: Theme.of(context).textTheme.labelLarge,
              ),
            ],
          );
        },
      ),
    );
  }
}

class _NotificationButton extends StatelessWidget {
  final int unreadCount;
  final VoidCallback onPressed;

  const _NotificationButton({
    required this.unreadCount,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'Notificações',
      onPressed: onPressed,
      icon: Badge(
        isLabelVisible: unreadCount > 0,
        label: Text(unreadCount > 99 ? '99+' : unreadCount.toString()),
        child: Icon(
          unreadCount > 0
              ? Icons.notifications_active_outlined
              : Icons.notifications_none_outlined,
        ),
      ),
    );
  }
}
