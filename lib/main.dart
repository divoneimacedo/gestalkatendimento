import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';
import 'controllers/attendances_controller.dart';
import 'controllers/auth_controller.dart';
import 'controllers/call_controller.dart';
import 'controllers/queue_controller.dart';
import 'controllers/reports_controller.dart';
import 'core/config/app_config.dart';
import 'core/config/app_theme.dart';
import 'core/router/app_router.dart';
import 'repositories/auth/auth_repository.dart';
import 'services/api/api_service.dart';
import 'services/attendance_service.dart';
import 'services/call_service.dart';
import 'services/notification_service.dart';
import 'services/queue_service.dart';
import 'services/report_service.dart';
import 'services/sound_service.dart';
import 'services/storage/token_storage.dart';
import 'services/tray_service.dart';
import 'widgets/call_alert_monitor.dart';

final _trayService = AppTrayService();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (Platform.isWindows || Platform.isMacOS) {
    await windowManager.ensureInitialized();
    await windowManager.waitUntilReadyToShow(
      const WindowOptions(
        size: Size(1200, 800),
        minimumSize: Size(900, 600),
        center: true,
      ),
      () async {
        await windowManager.show();
        await windowManager.focus();
      },
    );

    windowManager.setPreventClose(true);
    windowManager.addListener(_WindowCloseHandler());
  }

  await _trayService.init();

  final notificationService = NotificationService();

  if (Platform.isWindows || Platform.isLinux) {
    await notificationService.init();
  }

  final storage = TokenStorage();
  final apiService = ApiService(tokenStorage: storage);
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
  final String? initialSlug;

  GestalkApp({
    super.key,
    required this.authController,
    required this.queueController,
    required this.attendancesController,
    required this.callController,
    required this.reportsController,
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
        Provider<AppTrayService>.value(value: _trayService),
      ],
      child: MaterialApp.router(
        title: AppConfig.appName,
        theme: AppTheme.light(),
        routerConfig: _router,
        debugShowCheckedModeBanner: false,
        builder: (context, child) => CallAlertMonitor(
          child: child ?? const SizedBox.shrink(),
        ),
      ),
    );
  }
}
