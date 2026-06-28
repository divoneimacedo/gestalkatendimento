import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';

class AppTrayService with TrayListener {
  static const _normalTooltip = 'Gestalk Atendimento';
  static const _normalIcon = 'assets/icons/tray.ico';
  static const _alertIcon = 'assets/icons/tray_alert.ico';

  bool _initialized = false;
  int _waitingCallCount = 0;

  Future<void> init() async {
    if (!_isSupported) return;

    try {
      trayManager.addListener(this);
      await _setNormalState();

      await trayManager.setContextMenu(
        Menu(
          items: [
            MenuItem(key: 'show', label: 'Abrir'),
            MenuItem.separator(),
            MenuItem(key: 'exit', label: 'Sair'),
          ],
        ),
      );
      _initialized = true;
    } on MissingPluginException catch (e) {
      debugPrint('Tray nao disponivel nesta plataforma: $e');
    } catch (e) {
      debugPrint('Erro ao iniciar tray: $e');
    }
  }

  Future<void> showWaitingCalls(int count) async {
    if (!_initialized || !_isSupported || count <= 0) return;
    if (_waitingCallCount == count) return;

    try {
      _waitingCallCount = count;
      await trayManager.setIcon(_iconPath(alert: true));
      await trayManager.setToolTip(
        count > 1
            ? 'Gestalk Atendimento - $count chamadas aguardando'
            : 'Gestalk Atendimento - 1 chamada aguardando',
      );
    } catch (e) {
      debugPrint('Erro ao atualizar tray para alerta: $e');
    }
  }

  Future<void> clearWaitingCalls() async {
    if (!_initialized || !_isSupported || _waitingCallCount == 0) return;

    try {
      _waitingCallCount = 0;
      await _setNormalState();
    } catch (e) {
      debugPrint('Erro ao restaurar tray: $e');
    }
  }

  @override
  void onTrayIconMouseDown() {
    _showWindow();
  }

  @override
  void onTrayIconRightMouseDown() {
    trayManager.popUpContextMenu();
  }

  @override
  void onTrayMenuItemClick(MenuItem menuItem) {
    if (menuItem.key == 'show') {
      _showWindow();
    }

    if (menuItem.key == 'exit') {
      trayManager.removeListener(this);
      windowManager.destroy();
    }
  }

  Future<void> _showWindow() async {
    await windowManager.show();
    await windowManager.focus();
  }

  Future<void> _setNormalState() async {
    await trayManager.setIcon(_iconPath());
    await trayManager.setToolTip(_normalTooltip);
  }

  bool get _isSupported =>
      !kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS);

  String _iconPath({bool alert = false}) {
    if (Platform.isWindows) {
      return alert ? _alertIcon : _normalIcon;
    }

    return 'assets/icons/tray.png';
  }
}
