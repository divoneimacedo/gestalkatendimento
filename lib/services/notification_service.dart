import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:local_notifier/local_notifier.dart';
import 'package:window_manager/window_manager.dart';

class NotificationService {
  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _linuxInitialized = false;
  bool _windowsInitialized = false;

  Future<void> init() async {
    if (kIsWeb) return;

    if (Platform.isWindows) {
      await localNotifier.setup(
        appName: 'Gestalk Atendimento',
        shortcutPolicy: ShortcutPolicy.requireCreate,
      );
      _windowsInitialized = true;
      return;
    }

    if (Platform.isLinux) {
      const linux = LinuxInitializationSettings(
        defaultActionName: 'Abrir',
      );

      const settings = InitializationSettings(
        linux: linux,
      );

      await _plugin.initialize(settings);
      _linuxInitialized = true;
    }
  }

  Future<void> showNewCall({int count = 1}) async {
    final isWindows = !kIsWeb && Platform.isWindows;
    final body = _newCallMessage(count: count, useAscii: isWindows);

    if (isWindows) {
      await _showWindowsNotification(body);
      return;
    }

    if (!kIsWeb && Platform.isLinux) {
      await _showLinuxNotification(body);
    }
  }

  Future<void> _showWindowsNotification(String body) async {
    if (!_windowsInitialized) {
      await init();
    }

    final notification = LocalNotification(
      title: 'Nova chamada',
      body: body,
    );
    notification.onClick = () {
      unawaited(_showAppWindow());
    };

    await notification.show();
  }

  Future<void> _showLinuxNotification(String body) async {
    if (!_linuxInitialized) {
      await init();
    }

    const linux = LinuxNotificationDetails();
    const details = NotificationDetails(linux: linux);

    await _plugin.show(
      1,
      'Nova chamada',
      body,
      details,
    );
  }

  String _newCallMessage({required int count, required bool useAscii}) {
    if (useAscii) {
      return count > 1
          ? 'Voce tem $count chamadas aguardando.'
          : 'Voce tem uma nova chamada aguardando.';
    }

    return count > 1
        ? 'Você tem $count chamadas aguardando.'
        : 'Você tem uma nova chamada aguardando.';
  }

  Future<void> _showAppWindow() async {
    if (!Platform.isWindows && !Platform.isMacOS && !Platform.isLinux) return;

    if (await windowManager.isMinimized()) {
      await windowManager.restore();
    }

    await windowManager.show();
    await windowManager.focus();
  }
}
