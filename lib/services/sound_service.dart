import 'package:audioplayers/audioplayers.dart';

class SoundService {
  final AudioPlayer _player = AudioPlayer();
  bool _isPlaying = false;

  bool get isPlaying => _isPlaying;

  Future<void> startContinuousAlert() async {
    if (_isPlaying) return;
    _isPlaying = true;
    await _player.setReleaseMode(ReleaseMode.loop);
    await _player.play(AssetSource('sounds/notification-sound.mp3'));
  }

  Future<void> stop() async {
    if (!_isPlaying) return;
    _isPlaying = false;
    await _player.stop();
  }

  Future<void> dispose() async {
    await _player.dispose();
  }
}
