import 'dart:async';
import 'dart:ffi';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:ffi/ffi.dart';
import 'package:window_manager/window_manager.dart';

class SoundService {
  AudioPlayer? _player;
  _WindowsSoundPlayer? _windowsPlayer;
  Timer? _reinforcementTimer;
  bool _isPlaying = false;

  bool get isPlaying => _isPlaying;

  Future<void> startContinuousAlert() async {
    if (_isPlaying) return;
    _isPlaying = true;
    _startReinforcement();
    unawaited(_bringAppToFront());

    if (Platform.isWindows) {
      _windowsPlayer ??= _WindowsSoundPlayer();
      _windowsPlayer!.playLoop(_windowsAlertSoundPath());
      return;
    }

    final player = _player ??= AudioPlayer();
    await _configurePlayer(player);
    await player.setReleaseMode(ReleaseMode.loop);
    await player.play(
      AssetSource('sounds/notification-sound.mp3'),
      volume: 1,
      mode: PlayerMode.mediaPlayer,
    );
  }

  Future<void> stop() async {
    if (!_isPlaying) return;
    _isPlaying = false;
    _reinforcementTimer?.cancel();
    _reinforcementTimer = null;

    if (Platform.isWindows) {
      _windowsPlayer?.stop();
      return;
    }

    await _player?.stop();
  }

  Future<void> dispose() async {
    _reinforcementTimer?.cancel();
    _reinforcementTimer = null;

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

  Future<void> _configurePlayer(AudioPlayer player) async {
    try {
      await player.setPlayerMode(PlayerMode.mediaPlayer);
    } catch (_) {}

    try {
      await player.setVolume(1);
    } catch (_) {}

    try {
      await player.setAudioContext(
        AudioContextConfig(
          focus: AudioContextConfigFocus.gain,
          route: AudioContextConfigRoute.speaker,
        ).build(),
      );
    } catch (_) {
      // Alguns desktops ignoram AudioContext. O volume/loop continuam ativos.
    }
  }

  void _startReinforcement() {
    _reinforcementTimer?.cancel();
    _reinforcementTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!_isPlaying) return;

      if (Platform.isWindows) {
        _windowsPlayer?.boostVolume();
      } else {
        final player = _player;
        if (player != null) {
          unawaited(_reinforcePlayer(player));
        }
      }

      unawaited(_bringAppToFront(inactive: true));
    });
  }

  Future<void> _reinforcePlayer(AudioPlayer player) async {
    try {
      await player.setVolume(1);
      await player.resume();
    } catch (_) {
      try {
        await player.play(
          AssetSource('sounds/notification-sound.mp3'),
          volume: 1,
          mode: PlayerMode.mediaPlayer,
        );
      } catch (_) {}
    }
  }

  Future<void> _bringAppToFront({bool inactive = false}) async {
    if (!Platform.isWindows && !Platform.isMacOS && !Platform.isLinux) return;

    try {
      if (await windowManager.isMinimized()) {
        await windowManager.restore();
      }
      await windowManager.show(inactive: inactive);
      if (!inactive) {
        await windowManager.focus();
      }
    } catch (_) {}
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
    boostVolume();
    _send('play $_alias repeat');
  }

  void boostVolume() {
    _send('setaudio $_alias volume to 1000');
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
