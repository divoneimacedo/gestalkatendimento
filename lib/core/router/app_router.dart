import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../config/app_config.dart';
import '../../controllers/auth_controller.dart';
import '../../models/user.dart';
import '../../screens/attendances_screen.dart';
import '../../screens/call_screen.dart';
import '../../screens/call_review_screen.dart';
import '../../screens/login_screen.dart';
import '../../screens/placeholder_page_screen.dart';
import '../../screens/queue_screen.dart';
import '../../screens/reports_screen.dart';

class AppRouter {
  static final rootNavigatorKey = GlobalKey<NavigatorState>();

  static GoRouter create({
    required AuthController authController,
    String? initialSlug,
  }) {
    return GoRouter(
      navigatorKey: rootNavigatorKey,
      refreshListenable: authController,
      initialLocation: authController.isAuthenticated
          ? defaultLocationForUser(
              authController.user,
              initialSlug ?? AppConfig.defaultSlug,
            )
          : '/login',
      redirect: (context, state) {
        final isLoggingIn = state.matchedLocation == '/login';

        if (!authController.isAuthenticated) {
          return isLoggingIn ? null : '/login';
        }

        if (isLoggingIn) {
          return defaultLocationForUser(
            authController.user,
            authController.slug ?? initialSlug ?? AppConfig.defaultSlug,
          );
        }

        return null;
      },
      routes: [
        GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
        GoRoute(
          path: '/queue/:slug',
          builder: (_, state) => QueueScreen(
            slug: state.pathParameters['slug'] ?? AppConfig.defaultSlug,
          ),
        ),
        GoRoute(
          path: '/attendances/:slug',
          builder: (_, state) => AttendancesScreen(
            slug: state.pathParameters['slug'] ?? AppConfig.defaultSlug,
          ),
        ),
        GoRoute(
          path: '/reports/:slug',
          builder: (_, state) => ReportsScreen(
            slug: state.pathParameters['slug'] ?? AppConfig.defaultSlug,
          ),
        ),
        GoRoute(
          path: '/users/:slug',
          builder: (_, state) => _placeholder(
            state,
            routeKey: 'users',
            title: 'Usuários',
            icon: Icons.people_outline,
            description:
                'Área de usuários do desktop. A próxima etapa é conectar a listagem paginada ao endpoint de usuários.',
          ),
        ),
        GoRoute(
          path: '/channels/:slug',
          builder: (_, state) => _placeholder(
            state,
            routeKey: 'channels',
            title: 'Canais',
            icon: Icons.account_tree_outlined,
            description:
                'Área de canais do desktop. A rota já está disponível no menu conforme permissão.',
          ),
        ),
        GoRoute(
          path: '/companies/:slug',
          builder: (_, state) => _placeholder(
            state,
            routeKey: 'companies',
            title: 'Empresas',
            icon: Icons.business_outlined,
            description:
                'Área de empresas do desktop. A tela pode evoluir para listagem paginada igual ao front.',
          ),
        ),
        GoRoute(
          path: '/plans/:slug',
          builder: (_, state) => _placeholder(
            state,
            routeKey: 'plans',
            title: 'Planos',
            icon: Icons.workspace_premium_outlined,
            description:
                'Área de planos do desktop. A rota já respeita as permissões do usuário.',
          ),
        ),
        GoRoute(
          path: '/admin/:slug',
          builder: (_, state) => _placeholder(
            state,
            routeKey: 'admin',
            title: 'Painel Admin',
            icon: Icons.admin_panel_settings_outlined,
            description:
                'Painel administrativo do desktop. Disponível apenas para usuários administradores.',
          ),
        ),
        GoRoute(
          path: '/interpreters/:slug',
          builder: (_, state) => _placeholder(
            state,
            routeKey: 'interpreters',
            title: 'Intérpretes',
            icon: Icons.support_agent_outlined,
            description:
                'Área de intérpretes do desktop. A rota já está pronta para conectar os dados do backend.',
          ),
        ),
        GoRoute(
          path: '/profile/:slug',
          builder: (_, state) => _placeholder(
            state,
            routeKey: 'profile',
            title: 'Meu Perfil',
            icon: Icons.person_outline,
            description: 'Área de perfil do usuário autenticado no desktop.',
          ),
        ),
        GoRoute(
          path: '/notifications/:slug',
          builder: (_, state) => _placeholder(
            state,
            routeKey: 'notifications',
            title: 'Notificações',
            icon: Icons.notifications_outlined,
            description:
                'Área de notificações do desktop. A rota já está no menu superior/lateral.',
          ),
        ),
        GoRoute(
          path: '/call/:slug/:id',
          builder: (_, state) => CallScreen(
            slug: state.pathParameters['slug'] ?? AppConfig.defaultSlug,
            callId: state.pathParameters['id'] ?? '',
          ),
        ),
        GoRoute(
          path: '/call-review/:slug/:id',
          builder: (_, state) => CallReviewScreen(
            slug: state.pathParameters['slug'] ?? AppConfig.defaultSlug,
            callId: state.pathParameters['id'] ?? '',
            protocol: state.uri.queryParameters['protocol'] ?? '',
          ),
        ),
      ],
    );
  }

  static String defaultLocationForUser(User? user, String slug) {
    final permissions = user?.permissions ?? const <String>[];

    if (permissions.contains('call')) return '/queue/$slug';
    if (permissions.contains('reports')) return '/reports/$slug';
    if (permissions.contains('users')) return '/users/$slug';
    if (permissions.contains('channels')) return '/channels/$slug';
    if (permissions.contains('companies')) return '/companies/$slug';
    if (permissions.contains('plans')) return '/plans/$slug';

    return '/profile/$slug';
  }

  static PlaceholderPageScreen _placeholder(
    GoRouterState state, {
    required String routeKey,
    required String title,
    required IconData icon,
    required String description,
  }) {
    return PlaceholderPageScreen(
      slug: state.pathParameters['slug'] ?? AppConfig.defaultSlug,
      routeKey: routeKey,
      title: title,
      icon: icon,
      description: description,
    );
  }
}
