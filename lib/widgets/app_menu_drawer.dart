import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../controllers/auth_controller.dart';
import '../core/config/app_theme.dart';
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
    final permissions = user?.permissions ?? const <String>[];
    final isAdmin = user?.isAdmin ?? false;

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
                  if (_hasPermission(permissions, 'call')) ...[
                    _DrawerItem(
                      icon: Icons.pending_actions_outlined,
                      title: 'Fila de atendimento',
                      selected: currentRoute == 'queue',
                      onTap: () => _go(context, '/queue/$slug'),
                    ),
                    _DrawerItem(
                      icon: Icons.video_call_outlined,
                      title: 'Atendimentos',
                      selected: currentRoute == 'attendances',
                      onTap: () => _go(context, '/attendances/$slug'),
                    ),
                  ],
                  if (_hasPermission(permissions, 'reports'))
                    _DrawerItem(
                      icon: Icons.analytics_outlined,
                      title: 'Relatórios',
                      selected: currentRoute == 'reports',
                      onTap: () => _go(context, '/reports/$slug'),
                    ),
                  if (_hasPermission(permissions, 'users')) ...[
                    _DrawerItem(
                      icon: Icons.people_outline,
                      title: isAdmin ? 'Usuários' : 'Usuário',
                      selected: currentRoute == 'users',
                      onTap: () => _go(context, '/users/$slug'),
                    ),
                    if (isAdmin)
                      _DrawerItem(
                        icon: Icons.admin_panel_settings_outlined,
                        title: 'Painel Admin',
                        selected: currentRoute == 'admin',
                        onTap: () => _go(context, '/admin/$slug'),
                      ),
                  ],
                  if (_hasPermission(permissions, 'channels'))
                    _DrawerItem(
                      icon: Icons.account_tree_outlined,
                      title: 'Canais',
                      selected: currentRoute == 'channels',
                      onTap: () => _go(context, '/channels/$slug'),
                    ),
                  if (_hasPermission(permissions, 'companies'))
                    _DrawerItem(
                      icon: Icons.business_outlined,
                      title: 'Empresas',
                      selected: currentRoute == 'companies',
                      onTap: () => _go(context, '/companies/$slug'),
                    ),
                  if (_hasPermission(permissions, 'plans')) ...[
                    _DrawerItem(
                      icon: Icons.workspace_premium_outlined,
                      title: 'Planos',
                      selected: currentRoute == 'plans',
                      onTap: () => _go(context, '/plans/$slug'),
                    ),
                    _DrawerItem(
                      icon: Icons.support_agent_outlined,
                      title: 'Intérpretes',
                      selected: currentRoute == 'interpreters',
                      onTap: () => _go(context, '/interpreters/$slug'),
                    ),
                  ],
                  _DrawerItem(
                    icon: Icons.person_outline,
                    title: 'Meu Perfil',
                    selected: currentRoute == 'profile',
                    onTap: () => _go(context, '/profile/$slug'),
                  ),
                  _DrawerItem(
                    icon: Icons.notifications_outlined,
                    title: 'Notificações',
                    selected: currentRoute == 'notifications',
                    onTap: () => _go(context, '/notifications/$slug'),
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

  bool _hasPermission(List<String> permissions, String permission) {
    return permissions.contains(permission);
  }
}

class _DrawerItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final bool selected;
  final VoidCallback? onTap;

  const _DrawerItem({
    required this.icon,
    required this.title,
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        onTap: onTap,
      ),
    );
  }
}
