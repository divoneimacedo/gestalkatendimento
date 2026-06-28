import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../controllers/auth_controller.dart';
import '../core/config/app_theme.dart';
import '../core/navigation/app_menu_destination.dart';
import 'gestalk_brand.dart';

class AppMenuDrawer extends StatelessWidget {
  final String slug;
  final String currentRoute;

  const AppMenuDrawer({
    super.key,
    required this.slug,
    required this.currentRoute,
  });

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final user = auth.user;
    final destinations = buildAppMenuDestinations(user: user, slug: slug);

    return Drawer(
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
              color: AppTheme.secondary,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const GestalkBrand(logoWidth: 150),
                  const SizedBox(height: 18),
                  Text(
                    user?.name ?? 'Gestalk',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    user?.profile ?? 'Atendimento',
                    style: const TextStyle(color: Colors.white70),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  for (var i = 0; i < destinations.length; i++)
                    _DrawerItem(
                      icon: destinations[i].icon,
                      title: destinations[i].title,
                      shortcutLabel: i < 9 ? 'Ctrl+${i + 1}' : null,
                      selected: currentRoute == destinations[i].routeKey,
                      onTap: () => _go(context, destinations[i].path),
                    ),
                ],
              ),
            ),
            const Divider(height: 1),
            _DrawerItem(
              icon: Icons.logout,
              title: 'Sair',
              onTap: () async {
                await auth.logout();
                if (context.mounted) context.go('/login');
              },
            ),
          ],
        ),
      ),
    );
  }

  void _go(BuildContext context, String route) {
    Navigator.of(context).pop();
    context.go(route);
  }
}

class _DrawerItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? shortcutLabel;
  final bool selected;
  final VoidCallback? onTap;

  const _DrawerItem({
    required this.icon,
    required this.title,
    this.shortcutLabel,
    this.selected = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: ListTile(
        enabled: onTap != null,
        selected: selected,
        selectedTileColor: AppTheme.primary.withValues(alpha: 0.12),
        selectedColor: AppTheme.primary,
        leading: Icon(icon),
        title: Text(title),
        trailing: shortcutLabel == null
            ? null
            : Text(
                shortcutLabel!,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: selected ? AppTheme.primary : Colors.black54,
                      fontWeight: FontWeight.w600,
                    ),
              ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        onTap: onTap,
      ),
    );
  }
}
