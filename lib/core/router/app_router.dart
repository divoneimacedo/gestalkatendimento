import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../config/app_config.dart';
import '../../controllers/auth_controller.dart';
import '../../models/user.dart';
import '../../screens/about_screen.dart';
import '../../screens/admin_panel_screen.dart';
import '../../screens/attendances_screen.dart';
import '../../screens/channel_form_screen.dart';
import '../../screens/channels_screen.dart';
import '../../screens/call_screen.dart';
import '../../screens/call_review_screen.dart';
import '../../screens/companies_screen.dart';
import '../../screens/company_form_screen.dart';
import '../../screens/interpreters_screen.dart';
import '../../screens/login_screen.dart';
import '../../screens/notifications_screen.dart';
import '../../screens/plan_form_screen.dart';
import '../../screens/plans_screen.dart';
import '../../screens/profile_screen.dart';
import '../../screens/queue_screen.dart';
import '../../screens/reports_screen.dart';
import '../../screens/settings_screen.dart';
import '../../screens/user_edit_screen.dart';
import '../../screens/user_create_screen.dart';
import '../../screens/users_screen.dart';

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
          builder: (_, state) => UsersScreen(
            slug: state.pathParameters['slug'] ?? AppConfig.defaultSlug,
          ),
        ),
        GoRoute(
          path: '/users/:slug/company/:companyId',
          builder: (_, state) => UsersScreen(
            slug: state.pathParameters['slug'] ?? AppConfig.defaultSlug,
            companyId: state.pathParameters['companyId'],
          ),
        ),
        GoRoute(
          path: '/users/:slug/:id/edit',
          builder: (_, state) => UserEditScreen(
            slug: state.pathParameters['slug'] ?? AppConfig.defaultSlug,
            userId: state.pathParameters['id'] ?? '',
            backLocation: state.uri.queryParameters['back'],
          ),
        ),
        GoRoute(
          path: '/users/:slug/create',
          builder: (_, state) => UserCreateScreen(
            slug: state.pathParameters['slug'] ?? AppConfig.defaultSlug,
            backLocation: state.uri.queryParameters['back'],
          ),
        ),
        GoRoute(
          path: '/channels/:slug',
          builder: (_, state) => ChannelsScreen(
            slug: state.pathParameters['slug'] ?? AppConfig.defaultSlug,
          ),
        ),
        GoRoute(
          path: '/channels/:slug/company/:companyId',
          builder: (_, state) => ChannelsScreen(
            slug: state.pathParameters['slug'] ?? AppConfig.defaultSlug,
            companyId: state.pathParameters['companyId'],
          ),
        ),
        GoRoute(
          path: '/channels/:slug/create',
          builder: (_, state) => ChannelFormScreen(
            slug: state.pathParameters['slug'] ?? AppConfig.defaultSlug,
          ),
        ),
        GoRoute(
          path: '/channels/:slug/:id/edit',
          builder: (_, state) => ChannelFormScreen(
            slug: state.pathParameters['slug'] ?? AppConfig.defaultSlug,
            channelId: state.pathParameters['id'] ?? '',
          ),
        ),
        GoRoute(
          path: '/companies/:slug',
          builder: (_, state) => CompaniesScreen(
            slug: state.pathParameters['slug'] ?? AppConfig.defaultSlug,
          ),
        ),
        GoRoute(
          path: '/companies/:slug/create',
          builder: (_, state) => CompanyFormScreen(
            slug: state.pathParameters['slug'] ?? AppConfig.defaultSlug,
          ),
        ),
        GoRoute(
          path: '/companies/:slug/:id/edit',
          builder: (_, state) => CompanyFormScreen(
            slug: state.pathParameters['slug'] ?? AppConfig.defaultSlug,
            companyId: state.pathParameters['id'] ?? '',
          ),
        ),
        GoRoute(
          path: '/plans/:slug',
          builder: (_, state) => PlansScreen(
            slug: state.pathParameters['slug'] ?? AppConfig.defaultSlug,
          ),
        ),
        GoRoute(
          path: '/plans/:slug/create',
          builder: (_, state) => PlanFormScreen(
            slug: state.pathParameters['slug'] ?? AppConfig.defaultSlug,
          ),
        ),
        GoRoute(
          path: '/plans/:slug/:id/edit',
          builder: (_, state) => PlanFormScreen(
            slug: state.pathParameters['slug'] ?? AppConfig.defaultSlug,
            planId: state.pathParameters['id'] ?? '',
          ),
        ),
        GoRoute(
          path: '/admin/:slug',
          builder: (_, state) => AdminPanelScreen(
            slug: state.pathParameters['slug'] ?? AppConfig.defaultSlug,
            initialTab: state.uri.queryParameters['tab'] ?? 'dashboard',
          ),
        ),
        GoRoute(
          path: '/interpreters/:slug',
          builder: (_, state) => InterpretersScreen(
            slug: state.pathParameters['slug'] ?? AppConfig.defaultSlug,
          ),
        ),
        GoRoute(
          path: '/profile/:slug',
          builder: (_, state) => ProfileScreen(
            slug: state.pathParameters['slug'] ?? AppConfig.defaultSlug,
          ),
        ),
        GoRoute(
          path: '/notifications/:slug',
          builder: (_, state) => NotificationsScreen(
            slug: state.pathParameters['slug'] ?? AppConfig.defaultSlug,
          ),
        ),
        GoRoute(
          path: '/settings/:slug',
          builder: (_, state) => SettingsScreen(
            slug: state.pathParameters['slug'] ?? AppConfig.defaultSlug,
          ),
        ),
        GoRoute(
          path: '/about/:slug',
          builder: (_, state) => AboutScreen(
            slug: state.pathParameters['slug'] ?? AppConfig.defaultSlug,
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
}
