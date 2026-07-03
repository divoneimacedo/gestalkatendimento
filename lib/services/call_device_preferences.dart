import 'package:shared_preferences/shared_preferences.dart';

class CallDevicePreferences {
  static const _videoDeviceKey = 'call_preferred_video_device_id';
  static const _audioInputDeviceKey = 'call_preferred_audio_input_device_id';
  static const _audioOutputDeviceKey = 'call_preferred_audio_output_device_id';

  const CallDevicePreferences();

  Future<CallDevicePreferenceSet> load(String slug) async {
    final prefs = await SharedPreferences.getInstance();
    return CallDevicePreferenceSet(
      videoDeviceId: prefs.getString(_scopedKey(_videoDeviceKey, slug)),
      audioInputDeviceId: prefs.getString(
        _scopedKey(_audioInputDeviceKey, slug),
      ),
      audioOutputDeviceId: prefs.getString(
        _scopedKey(_audioOutputDeviceKey, slug),
      ),
    );
  }

  Future<void> saveVideoDeviceId(String slug, String deviceId) {
    return _save(slug, _videoDeviceKey, deviceId);
  }

  Future<void> saveAudioInputDeviceId(String slug, String deviceId) {
    return _save(slug, _audioInputDeviceKey, deviceId);
  }

  Future<void> saveAudioOutputDeviceId(String slug, String deviceId) {
    return _save(slug, _audioOutputDeviceKey, deviceId);
  }

  Future<void> _save(String slug, String key, String deviceId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_scopedKey(key, slug), deviceId);
  }

  String _scopedKey(String key, String slug) => '${key}_$slug';
}

class CallDevicePreferenceSet {
  final String? videoDeviceId;
  final String? audioInputDeviceId;
  final String? audioOutputDeviceId;

  const CallDevicePreferenceSet({
    required this.videoDeviceId,
    required this.audioInputDeviceId,
    required this.audioOutputDeviceId,
  });
}
