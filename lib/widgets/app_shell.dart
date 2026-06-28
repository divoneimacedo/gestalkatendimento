import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../controllers/auth_controller.dart';
import '../core/navigation/app_menu_destination.dart';
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
              mainAxisSize: MainAxisSize.min,
              children: [
                const GestalkBrand(logoWidth: 86),
                const SizedBox(width: 18),
                Text(title),
              ],
            ),
            actions: actions,
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
