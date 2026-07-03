import 'package:flutter/material.dart';

import '../../models/user.dart';

class AppMenuDestination {
  final String routeKey;
  final String title;
  final IconData icon;
  final String path;

  const AppMenuDestination({
    required this.routeKey,
    required this.title,
    required this.icon,
    required this.path,
  });
}

List<AppMenuDestination> buildAppMenuDestinations({
  required User? user,
  required String slug,
}) {
  final permissions = user?.permissions ?? const <String>[];
  final isAdmin = user?.isAdmin ?? false;
  final destinations = <AppMenuDestination>[];

  if (permissions.contains('call')) {
    destinations.addAll([
      AppMenuDestination(
        routeKey: 'queue',
        title: 'Fila de atendimento',
        icon: Icons.pending_actions_outlined,
        path: '/queue/$slug',
      ),
      AppMenuDestination(
        routeKey: 'attendances',
        title: 'Atendimentos',
        icon: Icons.video_call_outlined,
        path: '/attendances/$slug',
      ),
    ]);
  }

  if (permissions.contains('reports')) {
    destinations.add(
      AppMenuDestination(
        routeKey: 'reports',
        title: 'Relatórios',
        icon: Icons.analytics_outlined,
        path: '/reports/$slug',
      ),
    );
  }

  if (permissions.contains('users')) {
    destinations.add(
      AppMenuDestination(
        routeKey: 'users',
        title: isAdmin ? 'Usuários' : 'Usuário',
        icon: Icons.people_outline,
        path: '/users/$slug',
      ),
    );

    if (isAdmin) {
      destinations.add(
        AppMenuDestination(
          routeKey: 'admin',
          title: 'Painel Admin',
          icon: Icons.admin_panel_settings_outlined,
          path: '/admin/$slug',
        ),
      );
    }
  }

  if (permissions.contains('channels')) {
    destinations.add(
      AppMenuDestination(
        routeKey: 'channels',
        title: 'Canais',
        icon: Icons.account_tree_outlined,
        path: '/channels/$slug',
      ),
    );
  }

  if (permissions.contains('companies')) {
    destinations.add(
      AppMenuDestination(
        routeKey: 'companies',
        title: 'Empresas',
        icon: Icons.business_outlined,
        path: '/companies/$slug',
      ),
    );
  }

  if (permissions.contains('plans')) {
    destinations.addAll([
      AppMenuDestination(
        routeKey: 'plans',
        title: 'Planos',
        icon: Icons.workspace_premium_outlined,
        path: '/plans/$slug',
      ),
      AppMenuDestination(
        routeKey: 'interpreters',
        title: 'Intérpretes',
        icon: Icons.support_agent_outlined,
        path: '/interpreters/$slug',
      ),
    ]);
  }

  destinations.addAll([
    AppMenuDestination(
      routeKey: 'profile',
      title: 'Meu Perfil',
      icon: Icons.person_outline,
      path: '/profile/$slug',
    ),
    AppMenuDestination(
      routeKey: 'notifications',
      title: 'Notificações',
      icon: Icons.notifications_outlined,
      path: '/notifications/$slug',
    ),
    AppMenuDestination(
      routeKey: 'settings',
      title: 'Configuracoes',
      icon: Icons.settings_outlined,
      path: '/settings/$slug',
    ),
    AppMenuDestination(
      routeKey: 'about',
      title: 'Sobre',
      icon: Icons.info_outline,
      path: '/about/$slug',
    ),
  ]);

  return destinations;
}
