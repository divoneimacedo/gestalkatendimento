import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    const linux = LinuxInitializationSettings(
      defaultActionName: 'Abrir',
    );

    const settings = InitializationSettings(
      linux: linux,
    );

    await _plugin.initialize(settings);
  }

  Future<void> showNewCall({int count = 1}) async {
    const linux = LinuxNotificationDetails();

    const details = NotificationDetails(
      linux: linux,
    );

    await _plugin.show(
      1,
      'Nova chamada',
      count > 1
          ? 'Você tem $count chamadas aguardando.'
          : 'Você tem uma nova chamada aguardando.',
      details,
    );
  }
}
