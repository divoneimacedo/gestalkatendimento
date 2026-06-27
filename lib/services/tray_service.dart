import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';

class AppTrayService with TrayListener {
  Future<void> init() async {
    if (kIsWeb) return;

    if (!(Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
      return;
    }

    try {
      trayManager.addListener(this);

      final iconPath = Platform.isWindows
          ? 'assets/icons/tray.ico'
          : 'assets/icons/tray.png';

      await trayManager.setIcon(iconPath);
      await trayManager.setToolTip('Gestalk Atendimento');

      await trayManager.setContextMenu(
        Menu(
          items: [
            MenuItem(key: 'show', label: 'Abrir'),
            MenuItem.separator(),
            MenuItem(key: 'exit', label: 'Sair'),
          ],
        ),
      );
    } on MissingPluginException catch (e) {
      debugPrint('Tray não disponível nesta plataforma: $e');
    } catch (e) {
      debugPrint('Erro ao iniciar tray: $e');
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
}