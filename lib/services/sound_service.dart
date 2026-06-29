import 'dart:ffi';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:ffi/ffi.dart';

class SoundService {
  AudioPlayer? _player;
  _WindowsSoundPlayer? _windowsPlayer;
  bool _isPlaying = false;

  bool get isPlaying => _isPlaying;

  Future<void> startContinuousAlert() async {
    if (_isPlaying) return;
    _isPlaying = true;

    if (Platform.isWindows) {
      _windowsPlayer ??= _WindowsSoundPlayer();
      _windowsPlayer!.playLoop(_windowsAlertSoundPath());
      return;
    }

    final player = _player ??= AudioPlayer();
    await player.setReleaseMode(ReleaseMode.loop);
    await player.play(AssetSource('sounds/notification-sound.mp3'));
  }

  Future<void> stop() async {
    if (!_isPlaying) return;
    _isPlaying = false;

    if (Platform.isWindows) {
      _windowsPlayer?.stop();
      return;
    }

    await _player?.stop();
  }

  Future<void> dispose() async {
    if (Platform.isWindows) {
      _windowsPlayer?.dispose();
      return;
    }

    await _player?.dispose();
  }

  String _windowsAlertSoundPath() {
    final executableDir = File(Platform.resolvedExecutable).parent.path;
    return '$executableDir\\data\\flutter_assets\\assets\\sounds\\notification-sound.mp3';
  }
}

typedef _MciSendStringNative = Uint32 Function(
  Pointer<Utf16> command,
  Pointer<Utf16> returnString,
  Uint32 returnLength,
  IntPtr callback,
);

typedef _MciSendStringDart = int Function(
  Pointer<Utf16> command,
  Pointer<Utf16> returnString,
  int returnLength,
  int callback,
);

class _WindowsSoundPlayer {
  static const _alias = 'gestalk_alert_sound';

  late final DynamicLibrary _winmm = DynamicLibrary.open('winmm.dll');
  late final _MciSendStringDart _mciSendString =
      _winmm.lookupFunction<_MciSendStringNative, _MciSendStringDart>(
    'mciSendStringW',
  );

  void playLoop(String filePath) {
    stop();
    _send('open "$filePath" type mpegvideo alias $_alias');
    _send('play $_alias repeat');
  }

  void stop() {
    _send('stop $_alias');
    _send('close $_alias');
  }

  void dispose() {
    stop();
  }

  void _send(String command) {
    final commandPointer = command.toNativeUtf16();
    try {
      _mciSendString(commandPointer, nullptr, 0, 0);
    } finally {
      calloc.free(commandPointer);
    }
  }
}
