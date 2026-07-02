import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';
import 'controllers/attendances_controller.dart';
import 'controllers/auth_controller.dart';
import 'controllers/call_controller.dart';
import 'controllers/channels_controller.dart';
import 'controllers/companies_controller.dart';
import 'controllers/interpreters_controller.dart';
import 'controllers/plans_controller.dart';
import 'controllers/queue_controller.dart';
import 'controllers/reports_controller.dart';
import 'controllers/users_controller.dart';
import 'core/config/app_config.dart';
import 'core/config/app_theme.dart';
import 'core/router/app_router.dart';
import 'repositories/auth/auth_repository.dart';
import 'services/api/api_service.dart';
import 'services/admin_service.dart';
import 'services/app_notification_service.dart';
import 'services/attendance_service.dart';
import 'services/call_service.dart';
import 'services/channels_service.dart';
import 'services/companies_service.dart';
import 'services/heartbeat_service.dart';
import 'services/interpreters_service.dart';
import 'services/notification_service.dart';
import 'services/plans_service.dart';
import 'services/profile_service.dart';
import 'services/queue_service.dart';
import 'services/report_service.dart';
import 'services/sound_service.dart';
import 'services/storage/token_storage.dart';
import 'services/tray_service.dart';
import 'services/users_service.dart';
import 'widgets/app_notification_monitor.dart';
import 'widgets/call_alert_monitor.dart';

final _trayService = AppTrayService();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
    await windowManager.ensureInitialized();
    await windowManager.waitUntilReadyToShow(
      const WindowOptions(
        size: Size(1200, 800),
        minimumSize: Size(900, 600),
        center: true,
      ),
      () async {
        await windowManager.show();
        await windowManager.maximize();
        await windowManager.focus();
      },
    );

    if (Platform.isWindows || Platform.isMacOS) {
      windowManager.setPreventClose(true);
      windowManager.addListener(_WindowCloseHandler());
    }
  }

  await _trayService.init();

  final notificationService = NotificationService();

  if (Platform.isWindows || Platform.isLinux) {
    await notificationService.init();
  }

  final storage = TokenStorage();
  final apiService = ApiService(tokenStorage: storage);
  final heartbeatService = HeartbeatService(apiService);
  final appNotificationService = AppNotificationService(apiService);
  final profileService = ProfileService(apiService);
  final adminService = AdminService(apiService);
  final usersService = UsersService(apiService);
  final authController = AuthController(
    AuthRepository(
      apiService: apiService,
      tokenStorage: storage,
    ),
  );
  apiService.onUnauthorized = authController.logout;
  await authController.restoreSession();
  final savedSlug = await authController.getSavedSlug();

  debugPrint('ENV: ${AppConfig.environment}');
  debugPrint('API: ${AppConfig.apiUrl}');

  runApp(
    GestalkApp(
      authController: authController,
      queueController: QueueController(
        queueService: QueueService(apiService),
        notificationService: notificationService,
        soundService: SoundService(),
      ),
      attendancesController: AttendancesController(
        attendanceService: AttendanceService(apiService),
      ),
      callController: CallController(
        callService: CallService(apiService),
      ),
      reportsController: ReportsController(
        reportService: ReportService(apiService),
      ),
      usersController: UsersController(
        usersService: usersService,
      ),
      channelsController: ChannelsController(
        channelsService: ChannelsService(apiService),
      ),
      companiesController: CompaniesController(
        companiesService: CompaniesService(apiService),
      ),
      plansController: PlansController(
        plansService: PlansService(apiService),
      ),
      interpretersController: InterpretersController(
        interpretersService: InterpretersService(apiService),
      ),
      heartbeatService: heartbeatService,
      appNotificationService: appNotificationService,
      notificationService: notificationService,
      profileService: profileService,
      adminService: adminService,
      usersService: usersService,
      initialSlug: savedSlug,
    ),
  );
}

class _WindowCloseHandler with WindowListener {
  @override
  void onWindowClose() async {
    if (Platform.isWindows || Platform.isMacOS) {
      await windowManager.hide();
    }
  }
}

class GestalkApp extends StatelessWidget {
  final AuthController authController;
  final QueueController queueController;
  final AttendancesController attendancesController;
  final CallController callController;
  final ReportsController reportsController;
  final UsersController usersController;
  final ChannelsController channelsController;
  final CompaniesController companiesController;
  final PlansController plansController;
  final InterpretersController interpretersController;
  final HeartbeatService heartbeatService;
  final AppNotificationService appNotificationService;
  final NotificationService notificationService;
  final ProfileService profileService;
  final AdminService adminService;
  final UsersService usersService;
  final String? initialSlug;

  GestalkApp({
    super.key,
    required this.authController,
    required this.queueController,
    required this.attendancesController,
    required this.callController,
    required this.reportsController,
    required this.usersController,
    required this.channelsController,
    required this.companiesController,
    required this.plansController,
    required this.interpretersController,
    required this.heartbeatService,
    required this.appNotificationService,
    required this.notificationService,
    required this.profileService,
    required this.adminService,
    required this.usersService,
    this.initialSlug,
  });

  late final _router = AppRouter.create(
    authController: authController,
    initialSlug: initialSlug,
  );

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: authController),
        ChangeNotifierProvider.value(value: queueController),
        ChangeNotifierProvider.value(value: attendancesController),
        ChangeNotifierProvider.value(value: callController),
        ChangeNotifierProvider.value(value: reportsController),
        ChangeNotifierProvider.value(value: usersController),
        ChangeNotifierProvider.value(value: channelsController),
        ChangeNotifierProvider.value(value: companiesController),
        ChangeNotifierProvider.value(value: plansController),
        ChangeNotifierProvider.value(value: interpretersController),
        Provider<HeartbeatService>.value(value: heartbeatService),
        ChangeNotifierProvider.value(value: appNotificationService),
        Provider<NotificationService>.value(value: notificationService),
        Provider<ProfileService>.value(value: profileService),
        Provider<AdminService>.value(value: adminService),
        Provider<UsersService>.value(value: usersService),
        Provider<AppTrayService>.value(value: _trayService),
      ],
      child: MaterialApp.router(
        title: AppConfig.appName,
        theme: AppTheme.light(),
        routerConfig: _router,
        debugShowCheckedModeBanner: false,
        builder: (context, child) => AppNotificationMonitor(
          child: CallAlertMonitor(
            child: child ?? const SizedBox.shrink(),
          ),
        ),
      ),
    );
  }
}
