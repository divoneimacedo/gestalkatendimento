import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:videosdk/videosdk.dart' as sdk;
import 'package:window_manager/window_manager.dart';

import '../controllers/auth_controller.dart';
import '../controllers/call_controller.dart';
import '../core/config/app_theme.dart';
import '../services/call_device_preferences.dart';
import '../widgets/app_shell.dart';

class CallScreen extends StatefulWidget {
  final String slug;
  final String callId;

  const CallScreen({
    super.key,
    required this.slug,
    required this.callId,
  });

  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> {
  static const _chatTopic = 'CHAT';

  sdk.Room? _room;
  final _devicePreferences = const CallDevicePreferences();
  Timer? _localMediaWatchdogTimer;
  final Map<String, sdk.Participant> _remoteParticipants = {};
  final List<sdk.PubSubMessage> _chatMessages = [];
  final TextEditingController _chatController = TextEditingController();

  bool _joining = true;
  bool _joined = false;
  bool _cameraEnabled = true;
  bool _microphoneEnabled = true;
  bool _speakerEnabled = true;
  bool _chatOpen = true;
  bool _chatSubscribed = false;
  bool _devicesLoading = false;
  bool _deviceSwitching = false;
  bool _pictureInPicture = false;
  bool _windowWasMaximized = false;
  int _unreadChatMessages = 0;
  String? _callError;
  String? _deviceWarning;
  String _roomState = 'Conectando';
  Rect? _windowBoundsBeforePip;
  List<sdk.VideoDeviceInfo> _videoDevices = const [];
  List<sdk.AudioDeviceInfo> _audioInputDevices = const [];
  List<sdk.AudioDeviceInfo> _audioOutputDevices = const [];
  String? _selectedVideoDeviceId;
  String? _selectedAudioInputDeviceId;
  String? _selectedAudioOutputDeviceId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _startCallFlow());
  }

  @override
  void dispose() {
    _localMediaWatchdogTimer?.cancel();
    unawaited(_restoreWindowFromPictureInPicture());
    _leaveRoom();
    _chatController.dispose();
    super.dispose();
  }

  Future<void> _startCallFlow() async {
    setState(() {
      _joining = true;
      _callError = null;
      _deviceWarning = null;
      _cameraEnabled = true;
      _microphoneEnabled = true;
    });

    final controller = context.read<CallController>();
    final auth = context.read<AuthController>();

    try {
      final granted = await _requestMediaPermissions();
      if (!granted) {
        await _sendTechnicalLog(
          event: 'media_permission_denied',
          error: {
            'message': 'Permissao de camera ou microfone nao concedida.',
          },
        );
        setState(() {
          _joining = false;
          _callError =
              'Permissão de câmera ou microfone não concedida. Libere o acesso nas configurações do sistema.';
        });
        return;
      }

      await _loadMediaDevices();

      final mediaCheck = await _checkMediaAvailability();
      if (!mediaCheck.cameraAvailable || !mediaCheck.microphoneAvailable) {
        await _sendTechnicalLog(
          event: mediaCheck.suspectedConcurrency
              ? 'media_device_concurrency_suspected'
              : 'media_device_unavailable',
          error: mediaCheck.toLog(),
          mediaProbe: mediaCheck.toLog(),
        );

        if (!mounted) return;
        setState(() {
          _cameraEnabled = mediaCheck.cameraAvailable;
          _microphoneEnabled = mediaCheck.microphoneAvailable;
          _deviceWarning = mediaCheck.message;
        });
        _showDeviceWarning(mediaCheck.message);
      }

      await controller.load(widget.callId);

      final call = controller.currentCall;
      final token = controller.videoSdkToken;

      if (call == null || call.meetingId.isEmpty) {
        await _sendTechnicalLog(
          event: 'call_start_error',
          error: {
            'message': 'Chamada sem sala VideoSDK vinculada.',
          },
        );
        setState(() {
          _joining = false;
          _callError = 'A chamada não possui sala VideoSDK vinculada.';
        });
        return;
      }

      if (token == null || token.isEmpty) {
        await _sendTechnicalLog(
          event: 'call_start_error',
          callId: call.id,
          meetingId: call.meetingId,
          error: {
            'message': 'Token temporario do VideoSDK nao retornado.',
          },
        );
        setState(() {
          _joining = false;
          _callError = 'Não foi possível obter o token temporário do VideoSDK.';
        });
        return;
      }

      await _sendTechnicalLog(
        callId: call.id,
        meetingId: call.meetingId,
        sdkState: {
          'roomId': call.meetingId,
          'micEnabled': _microphoneEnabled,
          'camEnabled': _cameraEnabled,
          'multiStream': true,
          'mode': 'SEND_AND_RECV',
        },
      );

      await _joinRoom(
        meetingId: call.meetingId,
        token: token,
        displayName:
            auth.user?.name.isNotEmpty == true ? auth.user!.name : 'Atendente',
      );
    } catch (error, stackTrace) {
      await _sendTechnicalLog(
        event: 'call_start_error',
        error: {
          'message': error.toString(),
          'stack': stackTrace.toString(),
        },
      );
      setState(() {
        _joining = false;
        _callError = 'Não foi possível iniciar a chamada.';
      });
    }
  }

  Future<bool> _requestMediaPermissions() async {
    if (Platform.isLinux) return true;

    final camera = await Permission.camera.request();
    final microphone = await Permission.microphone.request();

    return camera.isGranted && microphone.isGranted;
  }

  Future<_MediaAvailability> _checkMediaAvailability() async {
    final camera = _videoDevices.isEmpty
        ? const _DeviceProbe.unavailable(
            label: 'Câmera',
            reason: 'Nenhuma câmera foi encontrada pelo sistema.',
          )
        : const _DeviceProbe.available(label: 'Câmera');
    final microphone = _audioInputDevices.isEmpty
        ? const _DeviceProbe.unavailable(
            label: 'Microfone',
            reason: 'Nenhum microfone foi encontrado pelo sistema.',
          )
        : const _DeviceProbe.available(label: 'Microfone');

    return _MediaAvailability(camera: camera, microphone: microphone);
  }

  Future<sdk.CustomTrack?> _createCameraTrack() async {
    final track = await sdk.VideoSDK.createCameraVideoTrack(
      cameraId: _selectedVideoDeviceId,
      encoderConfig: sdk.CustomVideoTrackConfig.h360p_w640p,
      multiStream: true,
    );

    return track is sdk.CustomTrack ? track : null;
  }

  Future<sdk.CustomTrack?> _createMicrophoneTrack() async {
    final track = await sdk.VideoSDK.createMicrophoneAudioTrack(
      microphoneId: _selectedAudioInputDeviceId,
      encoderConfig: sdk.CustomAudioTrackConfig.speech_standard,
    );

    return track is sdk.CustomTrack ? track : null;
  }

  void _showDeviceWarning(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 12),
          content: Text(message),
          action: SnackBarAction(
            label: 'OK',
            onPressed: () {},
          ),
        ),
      );
  }

  Future<void> _warnMediaToggleFailure({
    required String deviceLabel,
    required String reason,
  }) async {
    final message = _buildDeviceWarningMessage(
      unavailableLabels: [deviceLabel],
      reasons: {deviceLabel: reason},
    );

    await _sendTechnicalLog(
      event: _isPossibleDeviceConcurrency(reason)
          ? 'media_toggle_concurrency_suspected'
          : 'media_toggle_unavailable',
      error: {
        'device': deviceLabel,
        'reason': reason,
        'suspectedConcurrency': _isPossibleDeviceConcurrency(reason),
      },
    );

    if (!mounted) return;
    setState(() => _deviceWarning = message);
    _showDeviceWarning(message);
  }

  Future<void> _sendTechnicalLog({
    String event = 'call_start_snapshot',
    String? callId,
    String? meetingId,
    Map<String, dynamic>? sdkState,
    Map<String, dynamic>? error,
    Map<String, dynamic>? mediaProbe,
  }) async {
    try {
      final controller = context.read<CallController>();
      final auth = context.read<AuthController>();
      final call = controller.currentCall;
      final user = auth.user;

      await controller.callService.sendTechnicalLog({
        'callId': callId ?? call?.id ?? widget.callId,
        'meetingId': meetingId ?? call?.meetingId,
        'source': 'flutter-desktop',
        'actorType': user?.isAdmin == true ? 'admin' : 'attendant',
        'event': event,
        'userId': user?.id,
        'userName': user?.name,
        'companySlug': widget.slug,
        'platform': Platform.operatingSystem,
        'os': Platform.operatingSystemVersion,
        'permissions': await _permissionSnapshot(),
        'mediaDevices': await _mediaDevicesSnapshot(),
        'constraints': {
          'audio': true,
          'video': true,
        },
        'deviceInfo': await _deviceInfoSnapshot(),
        'sdkState': sdkState,
        'mediaProbe': mediaProbe,
        'error': error,
        'raw': {
          'route': '/call/${widget.slug}/${widget.callId}',
        },
      });
    } catch (_) {
      // O log tecnico nao pode interromper a chamada.
    }
  }

  Future<Map<String, dynamic>> _permissionSnapshot() async {
    if (Platform.isLinux) {
      return {
        'camera': 'not_requested_on_linux',
        'microphone': 'not_requested_on_linux',
      };
    }

    final camera = await Permission.camera.status;
    final microphone = await Permission.microphone.status;

    return {
      'camera': _permissionStatus(camera),
      'microphone': _permissionStatus(microphone),
    };
  }

  String _permissionStatus(PermissionStatus status) {
    return status.toString().replaceFirst('PermissionStatus.', '');
  }

  Future<Map<String, dynamic>> _deviceInfoSnapshot() async {
    final info = <String, dynamic>{
      'executable': Platform.resolvedExecutable,
      'localeName': Platform.localeName,
      'numberOfProcessors': Platform.numberOfProcessors,
      'dartVersion': Platform.version,
    };

    try {
      info['videoSdkDeviceInfo'] = await sdk.VideoSDK.getDeviceInfo();
    } catch (error) {
      info['videoSdkDeviceInfoError'] = error.toString();
    }

    return info;
  }

  Future<Map<String, dynamic>> _mediaDevicesSnapshot() async {
    final result = <String, dynamic>{};

    try {
      final videoDevices = await sdk.VideoSDK.getVideoDevices();
      final videos = (videoDevices ?? [])
          .map(
            (device) => {
              'kind': device.kind,
              'label': device.label,
              'hasDeviceId': device.deviceId.isNotEmpty,
              'hasGroupId': device.groupId?.isNotEmpty == true,
            },
          )
          .toList();

      result['videoInputs'] = videos.length;
      result['videoDevices'] = videos;
    } catch (error) {
      result['videoError'] = error.toString();
    }

    try {
      final audioDevices = await sdk.VideoSDK.getAudioDevices();
      final audios = (audioDevices ?? [])
          .map(
            (device) => {
              'kind': device.kind,
              'label': device.label,
              'hasDeviceId': device.deviceId.isNotEmpty,
              'hasGroupId': device.groupId?.isNotEmpty == true,
            },
          )
          .toList();

      result['audioInputs'] =
          audios.where((device) => device['kind'] == 'audioinput').length;
      result['audioOutputs'] =
          audios.where((device) => device['kind'] == 'audiooutput').length;
      result['audioDevices'] = audios;
    } catch (error) {
      result['audioError'] = error.toString();
    }

    return result;
  }

  Future<void> _loadMediaDevices() async {
    if (!mounted) return;

    setState(() => _devicesLoading = true);

    try {
      final videoDevices = await sdk.VideoSDK.getVideoDevices();
      final audioDevices = await sdk.VideoSDK.getAudioDevices();
      final videos = (videoDevices ?? [])
          .where((device) => device.deviceId.isNotEmpty)
          .toList();
      final audioInputs = (audioDevices ?? [])
          .where(
            (device) =>
                device.kind == 'audioinput' && device.deviceId.isNotEmpty,
          )
          .toList();
      final audioOutputs = (audioDevices ?? [])
          .where(
            (device) =>
                device.kind == 'audiooutput' && device.deviceId.isNotEmpty,
          )
          .toList();
      final preferences = await _devicePreferences.load(widget.slug);

      if (!mounted) return;
      setState(() {
        _videoDevices = videos;
        _audioInputDevices = audioInputs;
        _audioOutputDevices = audioOutputs;
        _selectedVideoDeviceId = _resolveSelectedDeviceId(
          currentId: _selectedVideoDeviceId ?? preferences.videoDeviceId,
          deviceIds: _videoDevices.map((device) => device.deviceId),
        );
        _selectedAudioInputDeviceId = _resolveSelectedDeviceId(
          currentId:
              _selectedAudioInputDeviceId ?? preferences.audioInputDeviceId,
          deviceIds: _audioInputDevices.map((device) => device.deviceId),
        );
        _selectedAudioOutputDeviceId = _resolveSelectedDeviceId(
          currentId:
              _selectedAudioOutputDeviceId ?? preferences.audioOutputDeviceId,
          deviceIds: _audioOutputDevices.map((device) => device.deviceId),
        );
      });
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Não foi possível carregar os dispositivos: $error'),
        ),
      );
    } finally {
      if (mounted) setState(() => _devicesLoading = false);
    }
  }

  String? _resolveSelectedDeviceId({
    required String? currentId,
    required Iterable<String> deviceIds,
  }) {
    final ids = deviceIds.where((id) => id.isNotEmpty).toList();
    if (currentId != null && ids.contains(currentId)) return currentId;
    return ids.isEmpty ? null : ids.first;
  }

  Future<void> _joinRoom({
    required String meetingId,
    required String token,
    required String displayName,
  }) async {
    _leaveRoom();

    sdk.CustomTrack? cameraTrack;
    sdk.CustomTrack? microphoneTrack;
    var cameraEnabled = _cameraEnabled;
    var microphoneEnabled = _microphoneEnabled;

    if (cameraEnabled) {
      try {
        cameraTrack = await _createCameraTrack();
        cameraEnabled = cameraTrack != null;
      } catch (error) {
        cameraEnabled = false;
        if (mounted) {
          await _warnMediaToggleFailure(
            deviceLabel: 'Câmera',
            reason: error.toString(),
          );
        }
      }
    }

    if (microphoneEnabled) {
      try {
        microphoneTrack = await _createMicrophoneTrack();
        microphoneEnabled = microphoneTrack != null;
      } catch (error) {
        microphoneEnabled = false;
        if (mounted) {
          await _warnMediaToggleFailure(
            deviceLabel: 'Microfone',
            reason: error.toString(),
          );
        }
      }
    }

    if (mounted &&
        (_cameraEnabled != cameraEnabled ||
            _microphoneEnabled != microphoneEnabled)) {
      setState(() {
        _cameraEnabled = cameraEnabled;
        _microphoneEnabled = microphoneEnabled;
      });
    }

    final room = sdk.VideoSDK.createRoom(
      roomId: meetingId,
      token: token,
      displayName: displayName,
      micEnabled: microphoneEnabled,
      camEnabled: cameraEnabled,
      maxResolution: 'hd',
      multiStream: true,
      customCameraVideoTrack: cameraTrack,
      customMicrophoneAudioTrack: microphoneTrack,
      mode: sdk.Mode.SEND_AND_RECV,
      debugMode: false,
      notification: const sdk.NotificationInfo(
        title: 'Gestalk Conecta',
        message: 'Atendimento por vídeo em andamento',
        icon: 'notification_share',
      ),
    );

    _room = room;
    _registerRoomEvents(room);
    room.join();
  }

  void _scheduleLocalMediaWatchdog(String trigger) {
    _localMediaWatchdogTimer?.cancel();
    _localMediaWatchdogTimer = Timer(const Duration(seconds: 5), () {
      if (!mounted) return;
      unawaited(_validateLocalMediaState(trigger));
    });
  }

  Future<void> _validateLocalMediaState(String trigger) async {
    final room = _room;
    final localParticipant = room?.localParticipant;
    if (!_joined || room == null || localParticipant == null) return;

    final videoStream = _findParticipantStream(localParticipant, 'video');
    final audioStream = _findParticipantStream(localParticipant, 'audio');
    final problems = <String>[];
    final details = <String, dynamic>{
      'trigger': trigger,
      'cameraEnabled': _cameraEnabled,
      'microphoneEnabled': _microphoneEnabled,
      'hasVideoStream': videoStream != null,
      'hasAudioStream': audioStream != null,
    };

    if (_cameraEnabled) {
      final renderer = videoStream?.renderer;
      final renderVideo = _readRendererBool(renderer, 'renderVideo');
      final width = _readRendererInt(renderer, 'videoWidth');
      final height = _readRendererInt(renderer, 'videoHeight');

      details.addAll({
        'videoRendererType': renderer?.runtimeType.toString(),
        'videoRenderVideo': renderVideo,
        'videoWidth': width,
        'videoHeight': height,
      });

      if (videoStream == null ||
          renderer == null ||
          renderVideo != true ||
          width <= 0 ||
          height <= 0) {
        problems.add('Câmera');
      }
    }

    if (_microphoneEnabled && audioStream == null) {
      problems.add('Microfone');
    }

    if (problems.isEmpty) return;

    final reasons = {
      for (final label in problems)
        label: label == 'Câmera'
            ? 'A câmera está ativa, mas o vídeo local não renderizou frames.'
            : 'O microfone está ativo, mas a trilha local de áudio não apareceu.',
    };
    final message = _buildDeviceWarningMessage(
      unavailableLabels: problems,
      reasons: reasons,
    );

    await _sendTechnicalLog(
      event: 'media_local_stream_not_rendering',
      error: {
        'message': message,
        'details': details,
        'suspectedConcurrency': true,
      },
      mediaProbe: details,
    );

    if (!mounted) return;
    setState(() => _deviceWarning = message);
    _showDeviceWarning(message);
  }

  sdk.Stream? _findParticipantStream(sdk.Participant participant, String kind) {
    for (final stream in participant.streams.values) {
      if (stream.kind == kind) return stream;
    }
    return null;
  }

  bool? _readRendererBool(dynamic renderer, String property) {
    try {
      if (property == 'renderVideo') return renderer?.renderVideo as bool?;
    } catch (_) {}
    return null;
  }

  int _readRendererInt(dynamic renderer, String property) {
    try {
      final value = switch (property) {
        'videoWidth' => renderer?.videoWidth,
        'videoHeight' => renderer?.videoHeight,
        _ => null,
      };
      if (value is int) return value;
      if (value is num) return value.toInt();
    } catch (_) {}
    return 0;
  }

  void _registerRoomEvents(sdk.Room room) {
    room.on(sdk.Events.roomJoined, () {
      setState(() {
        _joining = false;
        _joined = true;
        _chatOpen = true;
        _unreadChatMessages = 0;
        _roomState = 'Conectado';
        _selectedVideoDeviceId =
            room.selectedCam?.deviceId ?? _selectedVideoDeviceId;
        _selectedAudioInputDeviceId =
            room.selectedMic?.deviceId ?? _selectedAudioInputDeviceId;
        _selectedAudioOutputDeviceId =
            room.selectedSpeaker?.deviceId ?? _selectedAudioOutputDeviceId;
        _remoteParticipants
          ..clear()
          ..addAll(room.participants);
      });
      unawaited(_subscribeChat(room));
      _scheduleLocalMediaWatchdog('room_joined');
    });

    room.on(sdk.Events.roomLeft, (String? errorMessage) {
      setState(() {
        _joined = false;
        _roomState = 'Desconectado';
        if (errorMessage != null && errorMessage.isNotEmpty) {
          _callError = errorMessage;
        }
      });
    });

    room.on(sdk.Events.roomStateChanged, (sdk.RoomState state) {
      setState(() => _roomState = _translateRoomState(state));
    });

    room.on(sdk.Events.participantJoined, (sdk.Participant participant) {
      setState(() => _remoteParticipants[participant.id] = participant);
    });

    room.on(sdk.Events.participantLeft, (dynamic participant) {
      setState(() {
        if (participant is sdk.Participant) {
          _remoteParticipants.remove(participant.id);
        } else {
          _remoteParticipants.remove(participant?.toString());
        }
      });
    });

    room.on(sdk.Events.error, (dynamic error) {
      unawaited(
        _sendTechnicalLog(
          event: 'videosdk_error',
          error: {
            'message': _extractVideoSdkError(error),
            'raw': error.toString(),
          },
        ),
      );
      setState(() {
        _callError = _extractVideoSdkError(error);
        _joining = false;
      });
    });
  }

  Future<void> _subscribeChat(sdk.Room room) async {
    if (_chatSubscribed) return;

    try {
      final history =
          await room.pubSub.subscribe(_chatTopic, _handleChatMessage);

      if (!mounted) return;
      setState(() {
        _chatSubscribed = true;
        for (final message in history.messages) {
          _addChatMessage(message, incrementUnread: false);
        }
      });
    } catch (error) {
      await _sendTechnicalLog(
        event: 'chat_subscribe_error',
        error: {'message': error.toString()},
      );
    }
  }

  void _handleChatMessage(sdk.PubSubMessage message) {
    if (!mounted) return;

    setState(() {
      _addChatMessage(message, incrementUnread: !_chatOpen);
    });
  }

  void _addChatMessage(
    sdk.PubSubMessage message, {
    required bool incrementUnread,
  }) {
    final alreadyExists = message.id.isNotEmpty &&
        _chatMessages.any((current) => current.id == message.id);
    if (alreadyExists) return;

    _chatMessages.add(message);
    _chatMessages.sort((a, b) => a.timestamp.compareTo(b.timestamp));

    if (incrementUnread) {
      _unreadChatMessages += 1;
    }
  }

  Future<void> _sendChatMessage() async {
    final room = _room;
    final text = _chatController.text.trim();
    if (room == null || text.isEmpty) return;

    _chatController.clear();

    try {
      await room.pubSub.publish(
        _chatTopic,
        text,
        const sdk.PubSubPublishOptions(persist: true),
      );
    } catch (error) {
      await _sendTechnicalLog(
        event: 'chat_send_error',
        error: {'message': error.toString()},
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não foi possível enviar a mensagem.')),
      );
    }
  }

  void _toggleChat() {
    setState(() {
      _chatOpen = !_chatOpen;
      if (_chatOpen) _unreadChatMessages = 0;
    });
  }

  Future<void> _toggleMicrophone() async {
    final room = _room;
    if (room == null) return;

    if (_microphoneEnabled) {
      await room.muteMic();
    } else {
      sdk.CustomTrack? track;
      try {
        track = await _createMicrophoneTrack();
      } catch (error) {
        await _warnMediaToggleFailure(
          deviceLabel: 'Microfone',
          reason: error.toString(),
        );
        return;
      }

      if (track == null) {
        await _warnMediaToggleFailure(
          deviceLabel: 'Microfone',
          reason: 'O VideoSDK não conseguiu criar a trilha de áudio.',
        );
        return;
      }

      await room.unmuteMic(track);
    }

    setState(() => _microphoneEnabled = !_microphoneEnabled);
    if (_microphoneEnabled) {
      _scheduleLocalMediaWatchdog('microphone_enabled');
    }
  }

  Future<void> _toggleCamera() async {
    final room = _room;
    if (room == null) return;

    if (_cameraEnabled) {
      await room.disableCam();
    } else {
      sdk.CustomTrack? track;
      try {
        track = await _createCameraTrack();
      } catch (error) {
        await _warnMediaToggleFailure(
          deviceLabel: 'Câmera',
          reason: error.toString(),
        );
        return;
      }

      if (track == null) {
        await _warnMediaToggleFailure(
          deviceLabel: 'Câmera',
          reason: 'O VideoSDK não conseguiu criar a trilha de vídeo.',
        );
        return;
      }

      await room.enableCam(track);
    }

    setState(() => _cameraEnabled = !_cameraEnabled);
    if (_cameraEnabled) {
      _scheduleLocalMediaWatchdog('camera_enabled');
    }
  }

  void _toggleSpeaker() {
    setState(() => _speakerEnabled = !_speakerEnabled);
  }

  Future<void> _changeCamera(String? deviceId) async {
    final room = _room;
    if (deviceId == null || deviceId == _selectedVideoDeviceId) {
      return;
    }

    final device = _findVideoDevice(deviceId);
    if (device == null) return;

    if (room == null || !_joined) {
      setState(() => _selectedVideoDeviceId = device.deviceId);
      await _devicePreferences.saveVideoDeviceId(widget.slug, device.deviceId);
      return;
    }

    await _runDeviceSwitch(
      successState: () {
        _selectedVideoDeviceId = device.deviceId;
        _cameraEnabled = true;
      },
      action: () async {
        await room.changeCam(device);
        await _devicePreferences.saveVideoDeviceId(
          widget.slug,
          device.deviceId,
        );
        _scheduleLocalMediaWatchdog('camera_changed');
      },
      errorLabel: 'câmera',
    );
  }

  Future<void> _changeMicrophone(String? deviceId) async {
    final room = _room;
    if (deviceId == null || deviceId == _selectedAudioInputDeviceId) {
      return;
    }

    final device = _findAudioInputDevice(deviceId);
    if (device == null) return;

    if (room == null || !_joined) {
      setState(() => _selectedAudioInputDeviceId = device.deviceId);
      await _devicePreferences.saveAudioInputDeviceId(
        widget.slug,
        device.deviceId,
      );
      return;
    }

    await _runDeviceSwitch(
      successState: () {
        _selectedAudioInputDeviceId = device.deviceId;
        _microphoneEnabled = true;
      },
      action: () async {
        await room.changeMic(device);
        await _devicePreferences.saveAudioInputDeviceId(
          widget.slug,
          device.deviceId,
        );
        _scheduleLocalMediaWatchdog('microphone_changed');
      },
      errorLabel: 'microfone',
    );
  }

  Future<void> _changeAudioOutput(String? deviceId) async {
    final room = _room;
    if (deviceId == null || deviceId == _selectedAudioOutputDeviceId) {
      return;
    }

    final device = _findAudioOutputDevice(deviceId);
    if (device == null) return;

    if (room == null || !_joined) {
      setState(() => _selectedAudioOutputDeviceId = device.deviceId);
      await _devicePreferences.saveAudioOutputDeviceId(
        widget.slug,
        device.deviceId,
      );
      return;
    }

    await _runDeviceSwitch(
      successState: () {
        _selectedAudioOutputDeviceId = device.deviceId;
        _speakerEnabled = true;
      },
      action: () async {
        await room.switchAudioDevice(device);
        await _devicePreferences.saveAudioOutputDeviceId(
          widget.slug,
          device.deviceId,
        );
      },
      errorLabel: 'saída de áudio',
    );
  }

  Future<void> _runDeviceSwitch({
    required Future<void> Function() action,
    required VoidCallback successState,
    required String errorLabel,
  }) async {
    if (_deviceSwitching) return;

    setState(() => _deviceSwitching = true);
    try {
      await action();
      if (!mounted) return;
      setState(successState);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Não foi possível trocar $errorLabel: $error'),
        ),
      );
    } finally {
      if (mounted) setState(() => _deviceSwitching = false);
    }
  }

  sdk.VideoDeviceInfo? _findVideoDevice(String deviceId) {
    for (final device in _videoDevices) {
      if (device.deviceId == deviceId) return device;
    }
    return null;
  }

  sdk.AudioDeviceInfo? _findAudioInputDevice(String deviceId) {
    for (final device in _audioInputDevices) {
      if (device.deviceId == deviceId) return device;
    }
    return null;
  }

  sdk.AudioDeviceInfo? _findAudioOutputDevice(String deviceId) {
    for (final device in _audioOutputDevices) {
      if (device.deviceId == deviceId) return device;
    }
    return null;
  }

  Future<void> _showDeviceSettings() async {
    if (_videoDevices.isEmpty &&
        _audioInputDevices.isEmpty &&
        _audioOutputDevices.isEmpty) {
      await _loadMediaDevices();
    }

    if (!mounted) return;

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (modalContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            Future<void> refreshDevices() async {
              await _loadMediaDevices();
              if (context.mounted) setModalState(() {});
            }

            Future<void> changeDevice(Future<void> Function() action) async {
              await action();
              if (context.mounted) setModalState(() {});
            }

            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 560),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.settings_input_component_outlined),
                          const SizedBox(width: 10),
                          const Expanded(
                            child: Text(
                              'Dispositivos da chamada',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          IconButton(
                            tooltip: 'Atualizar dispositivos',
                            onPressed: _devicesLoading ? null : refreshDevices,
                            icon: _devicesLoading
                                ? const SizedBox.square(
                                    dimension: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.refresh),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _DeviceDropdown(
                        label: 'Câmera',
                        icon: Icons.videocam_outlined,
                        value: _selectedVideoDeviceId,
                        devices: _videoDevices
                            .map(
                              (device) => _CallDeviceOption(
                                id: device.deviceId,
                                label: device.label,
                              ),
                            )
                            .toList(),
                        enabled: !_deviceSwitching,
                        onChanged: (deviceId) => changeDevice(
                          () => _changeCamera(deviceId),
                        ),
                      ),
                      const SizedBox(height: 12),
                      _DeviceDropdown(
                        label: 'Microfone',
                        icon: Icons.mic_none_outlined,
                        value: _selectedAudioInputDeviceId,
                        devices: _audioInputDevices
                            .map(
                              (device) => _CallDeviceOption(
                                id: device.deviceId,
                                label: device.label,
                              ),
                            )
                            .toList(),
                        enabled: !_deviceSwitching,
                        onChanged: (deviceId) => changeDevice(
                          () => _changeMicrophone(deviceId),
                        ),
                      ),
                      const SizedBox(height: 12),
                      _DeviceDropdown(
                        label: 'Saída de áudio',
                        icon: Icons.volume_up_outlined,
                        value: _selectedAudioOutputDeviceId,
                        devices: _audioOutputDevices
                            .map(
                              (device) => _CallDeviceOption(
                                id: device.deviceId,
                                label: device.label,
                              ),
                            )
                            .toList(),
                        enabled: !_deviceSwitching,
                        onChanged: (deviceId) => changeDevice(
                          () => _changeAudioOutput(deviceId),
                        ),
                      ),
                      if (_deviceSwitching) ...[
                        const SizedBox(height: 14),
                        const LinearProgressIndicator(),
                      ],
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _togglePictureInPicture() async {
    if (_pictureInPicture) {
      await _restoreWindowFromPictureInPicture();
    } else {
      await _enterPictureInPicture();
    }
  }

  Future<void> _enterPictureInPicture() async {
    if (!Platform.isWindows && !Platform.isMacOS && !Platform.isLinux) return;

    try {
      final bounds = await windowManager.getBounds();
      final wasMaximized = await windowManager.isMaximized();

      if (wasMaximized) {
        await windowManager.unmaximize();
      }

      await windowManager.setMinimumSize(const Size(620, 460));
      await windowManager.setSize(const Size(680, 520));
      await windowManager.setAlignment(Alignment.bottomRight);
      await windowManager.setAlwaysOnTop(true);
      await windowManager.focus();

      if (!mounted) return;
      setState(() {
        _pictureInPicture = true;
        _windowBoundsBeforePip = bounds;
        _windowWasMaximized = wasMaximized;
        _chatOpen = false;
      });
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text('Não foi possível ativar o miniplayer: $error'),
        ),
      );
    }
  }

  Future<void> _restoreWindowFromPictureInPicture() async {
    if (!_pictureInPicture &&
        _windowBoundsBeforePip == null &&
        !_windowWasMaximized) {
      return;
    }

    final bounds = _windowBoundsBeforePip;
    final wasMaximized = _windowWasMaximized;

    if (mounted) {
      setState(() {
        _pictureInPicture = false;
        _windowBoundsBeforePip = null;
        _windowWasMaximized = false;
      });
    } else {
      _pictureInPicture = false;
      _windowBoundsBeforePip = null;
      _windowWasMaximized = false;
    }

    if (!Platform.isWindows && !Platform.isMacOS && !Platform.isLinux) return;

    try {
      await windowManager.setAlwaysOnTop(false);
      await windowManager.setMinimumSize(const Size(900, 600));

      if (wasMaximized) {
        await windowManager.maximize();
      } else if (bounds != null) {
        await windowManager.setBounds(bounds);
      } else {
        await windowManager.setSize(const Size(1200, 800));
        await windowManager.center();
      }

      await windowManager.focus();
    } catch (_) {}
  }

  Future<void> _finishCall(BuildContext context) async {
    final controller = context.read<CallController>();

    await _restoreWindowFromPictureInPicture();
    _leaveRoom();

    try {
      await controller.finish(widget.callId);
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            controller.error ??
                'A chamada foi fechada localmente, mas não foi possível encerrar no servidor.',
          ),
        ),
      );
    }

    if (context.mounted) {
      final protocol = controller.currentCall?.protocol ?? '';
      final encodedProtocol = Uri.encodeComponent(protocol);
      context.go(
        '/call-review/${widget.slug}/${widget.callId}?protocol=$encodedProtocol',
      );
    }
  }

  void _leaveRoom() {
    try {
      final room = _room;
      if (room != null && _chatSubscribed) {
        unawaited(room.pubSub.unsubscribe(_chatTopic, _handleChatMessage));
      }
      _room?.leave();
    } catch (_) {}
    _room = null;
    _chatSubscribed = false;
    _remoteParticipants.clear();
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<CallController>();
    final call = controller.currentCall;
    final title = call?.protocol.isNotEmpty == true
        ? 'Atendimento ${call!.protocol}'
        : 'Atendimento';

    return AppShell(
      title: title,
      slug: widget.slug,
      currentRoute: 'call',
      navigationLocked: _joining || _joined || _room != null,
      navigationLockedMessage:
          'Encerre a chamada antes de navegar para outra tela.',
      actions: [
        IconButton(
          tooltip: _pictureInPicture ? 'Sair do miniplayer' : 'Miniplayer',
          onPressed: _room == null || !_joined ? null : _togglePictureInPicture,
          icon: Icon(
            _pictureInPicture
                ? Icons.open_in_full_outlined
                : Icons.picture_in_picture_alt_outlined,
          ),
        ),
        IconButton(
          tooltip: 'Reconectar',
          onPressed: _joining ? null : _startCallFlow,
          icon: const Icon(Icons.refresh),
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!_pictureInPicture) ...[
            _callHeader(controller),
            const SizedBox(height: 12),
          ],
          Expanded(
            child: _pictureInPicture
                ? _stage()
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(child: _stage()),
                      if (_chatOpen) ...[
                        const SizedBox(width: 12),
                        SizedBox(
                          width: 340,
                          child: _chatPanel(),
                        ),
                      ],
                    ],
                  ),
          ),
          SizedBox(height: _pictureInPicture ? 10 : 16),
          _toolbar(controller, compact: _pictureInPicture),
        ],
      ),
    );
  }

  Widget _callHeader(CallController controller) {
    final call = controller.currentCall;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Wrap(
          spacing: 10,
          runSpacing: 10,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            _InfoChip(
              icon: Icons.confirmation_number_outlined,
              label: call?.protocol.isNotEmpty == true
                  ? call!.protocol
                  : widget.callId
                      .substring(0, widget.callId.length.clamp(0, 8)),
            ),
            _InfoChip(
              icon: Icons.person_outline,
              label: call?.caller.isNotEmpty == true ? call!.caller : 'Cliente',
            ),
            _InfoChip(
              icon: Icons.meeting_room_outlined,
              label: call?.meetingId.isNotEmpty == true
                  ? 'Sala ${call!.meetingId}'
                  : 'Sala VideoSDK',
            ),
            _InfoChip(
              icon: _joined ? Icons.wifi : Icons.wifi_off,
              label: _roomState,
            ),
            IconButton.filledTonal(
              tooltip: 'Configurar câmera e microfone',
              onPressed: _devicesLoading ? null : _showDeviceSettings,
              icon: const Icon(Icons.settings_input_component_outlined),
            ),
            if (_joining || controller.loading)
              const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            if (_callError != null || controller.error != null)
              Text(
                _callError ?? controller.error!,
                style: const TextStyle(color: Colors.red),
              ),
            if (_joined)
              ActionChip(
                avatar: Icon(
                  _chatOpen ? Icons.chat : Icons.chat_outlined,
                  size: 18,
                ),
                label: Text(
                  _unreadChatMessages > 0
                      ? 'Chat ($_unreadChatMessages)'
                      : 'Chat',
                ),
                onPressed: _toggleChat,
              ),
          ],
        ),
      ),
    );
  }

  Widget _stage() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: DecoratedBox(
        decoration: const BoxDecoration(color: Color(0xFF101820)),
        child: Stack(
          children: [
            Positioned.fill(child: _participantsView()),
            if (_callError != null)
              Positioned(
                left: 18,
                right: 18,
                top: 18,
                child: _errorBanner(),
              ),
            if (_callError == null && _deviceWarning != null)
              Positioned(
                left: 18,
                right: 18,
                top: 18,
                child: _warningBanner(),
              ),
          ],
        ),
      ),
    );
  }

  Widget _participantsView() {
    final room = _room;
    final localParticipant = room?.localParticipant;
    final participants = _remoteParticipants.values.toList();

    if (_joining) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: Colors.white),
            SizedBox(height: 16),
            Text(
              'Entrando na chamada...',
              style: TextStyle(color: Colors.white, fontSize: 18),
            ),
          ],
        ),
      );
    }

    if (room == null || localParticipant == null) {
      return _emptyStage(
        icon: Icons.video_call_outlined,
        title: 'Chamada não conectada',
        subtitle: 'Clique em reconectar para tentar novamente.',
      );
    }

    if (participants.isEmpty) {
      return Stack(
        children: [
          Positioned.fill(
            child: _emptyStage(
              icon: Icons.person_outline,
              title: 'Aguardando vídeo remoto',
              subtitle: 'Você já entrou na sala aguarde.',
            ),
          ),
          Positioned(
            right: 18,
            bottom: 18,
            width: 260,
            height: 160,
            child: _ParticipantVideoTile(
              participant: localParticipant,
              label: 'Você',
              mirror: true,
            ),
          ),
        ],
      );
    }

    final primaryParticipant = participants.first;

    return Stack(
      children: [
        Positioned.fill(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: _ParticipantVideoTile(
              participant: primaryParticipant,
              label: primaryParticipant.displayName,
            ),
          ),
        ),
        Positioned(
          right: 18,
          bottom: 18,
          width: 260,
          height: 160,
          child: _ParticipantVideoTile(
            participant: localParticipant,
            label: 'Você',
            mirror: true,
          ),
        ),
      ],
    );
  }

  Widget _emptyStage({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 72, color: Colors.white.withValues(alpha: 0.72)),
          const SizedBox(height: 14),
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: TextStyle(color: Colors.white.withValues(alpha: 0.72)),
          ),
        ],
      ),
    );
  }

  Widget _errorBanner() {
    return Card(
      color: Colors.orange.shade50,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.orange),
            const SizedBox(width: 10),
            Expanded(child: Text(_callError!)),
            TextButton.icon(
              onPressed: _startCallFlow,
              icon: const Icon(Icons.refresh),
              label: const Text('Tentar novamente'),
            ),
            if (!Platform.isLinux)
              TextButton.icon(
                onPressed: openAppSettings,
                icon: const Icon(Icons.settings_outlined),
                label: const Text('Permissões'),
              ),
          ],
        ),
      ),
    );
  }

  Widget _warningBanner() {
    return Card(
      color: const Color(0xFFFFF8E1),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            const Icon(Icons.perm_device_information, color: Colors.orange),
            const SizedBox(width: 10),
            Expanded(child: Text(_deviceWarning!)),
            IconButton(
              tooltip: 'Fechar aviso',
              onPressed: () => setState(() => _deviceWarning = null),
              icon: const Icon(Icons.close),
            ),
          ],
        ),
      ),
    );
  }

  Widget _chatPanel() {
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Container(
            height: 52,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            color: const Color(0xFFEAF1F1),
            child: Row(
              children: [
                const Icon(Icons.chat_outlined, color: AppTheme.secondary),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Chat',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
                IconButton(
                  tooltip: 'Fechar chat',
                  onPressed: _toggleChat,
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
          Expanded(
            child: _chatMessages.isEmpty
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(18),
                      child: Text(
                        'Nenhuma mensagem ainda.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: _chatMessages.length,
                    itemBuilder: (context, index) {
                      return _ChatBubble(message: _chatMessages[index]);
                    },
                  ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _chatController,
                    enabled: _joined,
                    minLines: 1,
                    maxLines: 3,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _sendChatMessage(),
                    decoration: const InputDecoration(
                      hintText: 'Digite uma mensagem...',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  tooltip: 'Enviar',
                  onPressed: _joined ? _sendChatMessage : null,
                  icon: const Icon(Icons.send),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _toolbar(CallController controller, {bool compact = false}) {
    return Row(
      mainAxisAlignment:
          compact ? MainAxisAlignment.center : MainAxisAlignment.center,
      children: [
        _RoundCallButton(
          tooltip:
              _microphoneEnabled ? 'Desativar microfone' : 'Ativar microfone',
          icon: _microphoneEnabled ? Icons.mic : Icons.mic_off,
          active: _microphoneEnabled,
          onPressed: _room == null || !_joined ? null : _toggleMicrophone,
        ),
        const SizedBox(width: 12),
        _RoundCallButton(
          tooltip: _cameraEnabled ? 'Desativar câmera' : 'Ativar câmera',
          icon: _cameraEnabled ? Icons.videocam : Icons.videocam_off,
          active: _cameraEnabled,
          onPressed: _room == null || !_joined ? null : _toggleCamera,
        ),
        const SizedBox(width: 12),
        _RoundCallButton(
          tooltip: _speakerEnabled
              ? 'Desativar alto-falante'
              : 'Ativar alto-falante',
          icon: _speakerEnabled ? Icons.volume_up : Icons.volume_off,
          active: _speakerEnabled,
          onPressed: _toggleSpeaker,
        ),
        const SizedBox(width: 12),
        _RoundCallButton(
          tooltip: _chatOpen ? 'Fechar chat' : 'Abrir chat',
          icon: _chatOpen ? Icons.chat : Icons.chat_outlined,
          active: _chatOpen,
          badgeCount: _unreadChatMessages,
          onPressed: _joined ? _toggleChat : null,
        ),
        const SizedBox(width: 12),
        _RoundCallButton(
          tooltip: 'Dispositivos',
          icon: Icons.settings_input_component_outlined,
          active: true,
          onPressed: _room == null || !_joined ? null : _showDeviceSettings,
        ),
        const SizedBox(width: 22),
        FilledButton.icon(
          style: FilledButton.styleFrom(
            backgroundColor: AppTheme.cancel,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
          ),
          onPressed: controller.finishing ? null : () => _finishCall(context),
          icon: controller.finishing
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.call_end),
          label: const Text('Encerrar'),
        ),
      ],
    );
  }

  String _translateRoomState(sdk.RoomState state) {
    return switch (state) {
      sdk.RoomState.connecting => 'Conectando',
      sdk.RoomState.connected => 'Conectado',
      sdk.RoomState.reconnecting => 'Reconectando',
      sdk.RoomState.disconnected => 'Desconectado',
    };
  }

  String _extractVideoSdkError(dynamic error) {
    if (error is Map) {
      final message = error['message'] ?? error['name'] ?? error['code'];
      if (message != null) return message.toString();
    }

    return 'Erro ao conectar no VideoSDK.';
  }
}

String _buildDeviceWarningMessage({
  required List<String> unavailableLabels,
  required Map<String, String> reasons,
}) {
  final devices = unavailableLabels.join(' e ');
  final details = unavailableLabels
      .map((label) => '$label: ${reasons[label] ?? 'indisponível'}')
      .join(' | ');

  return '$devices não está disponível no momento. Pode estar em uso por outro aplicativo, bloqueado pelo sistema ou sem permissão. '
      'Por segurança, o sistema operacional não informa com precisão qual programa está usando o dispositivo. Detalhes: $details';
}

bool _isPossibleDeviceConcurrency(String reason) {
  final normalized = reason.toLowerCase();
  return normalized.contains('busy') ||
      normalized.contains('in use') ||
      normalized.contains('em uso') ||
      normalized.contains('notreadable') ||
      normalized.contains('trackstarterror') ||
      normalized.contains('could not start') ||
      normalized.contains('could not open') ||
      normalized.contains('cannot open') ||
      normalized.contains('unable to open') ||
      normalized.contains('device or resource busy') ||
      normalized.contains('already') ||
      normalized.contains('ocupado') ||
      normalized.contains('resource') ||
      normalized.contains('cannot create') ||
      normalized.contains('failed to allocate') ||
      normalized.contains('capture failed') ||
      normalized.contains('não conseguiu criar') ||
      normalized.contains('nao conseguiu criar') ||
      normalized.contains('failed to create');
}

class _MediaAvailability {
  final _DeviceProbe camera;
  final _DeviceProbe microphone;

  const _MediaAvailability({
    required this.camera,
    required this.microphone,
  });

  bool get cameraAvailable => camera.available;
  bool get microphoneAvailable => microphone.available;

  String get message {
    final unavailable = [
      if (!camera.available) camera.label,
      if (!microphone.available) microphone.label,
    ];
    final reasons = {
      camera.label: camera.reason,
      microphone.label: microphone.reason,
    };

    return _buildDeviceWarningMessage(
      unavailableLabels: unavailable,
      reasons: reasons,
    );
  }

  Map<String, dynamic> toLog() {
    return {
      'camera': camera.toLog(),
      'microphone': microphone.toLog(),
      'message': message,
      'suspectedConcurrency': suspectedConcurrency,
    };
  }

  bool get suspectedConcurrency =>
      !camera.available && camera.suspectedConcurrency ||
      !microphone.available && microphone.suspectedConcurrency;
}

class _DeviceProbe {
  final String label;
  final bool available;
  final String reason;

  const _DeviceProbe.available({required this.label})
      : available = true,
        reason = 'ok';

  const _DeviceProbe.unavailable({
    required this.label,
    required this.reason,
  }) : available = false;

  Map<String, dynamic> toLog() {
    return {
      'label': label,
      'available': available,
      'reason': reason,
      'suspectedConcurrency': suspectedConcurrency,
    };
  }

  bool get suspectedConcurrency => _isPossibleDeviceConcurrency(reason);
}

class _CallDeviceOption {
  final String id;
  final String label;

  const _CallDeviceOption({
    required this.id,
    required this.label,
  });
}

class _DeviceDropdown extends StatelessWidget {
  final String label;
  final IconData icon;
  final String? value;
  final List<_CallDeviceOption> devices;
  final bool enabled;
  final ValueChanged<String?> onChanged;

  const _DeviceDropdown({
    required this.label,
    required this.icon,
    required this.value,
    required this.devices,
    required this.enabled,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final deviceIds = devices.map((device) => device.id).toSet();
    final selectedValue = value != null && deviceIds.contains(value)
        ? value
        : devices.isEmpty
            ? null
            : devices.first.id;

    return DropdownButtonFormField<String>(
      initialValue: selectedValue,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        border: const OutlineInputBorder(),
        isDense: true,
      ),
      items: devices.isEmpty
          ? const []
          : [
              for (var i = 0; i < devices.length; i++)
                DropdownMenuItem(
                  value: devices[i].id,
                  child: Text(
                    devices[i].label.trim().isEmpty
                        ? '$label ${i + 1}'
                        : devices[i].label,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
      hint: Text('Nenhum dispositivo encontrado'),
      onChanged: enabled && devices.isNotEmpty ? onChanged : null,
    );
  }
}

class _ChatBubble extends StatelessWidget {
  final sdk.PubSubMessage message;

  const _ChatBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    final sender =
        message.senderName.trim().isEmpty ? 'Participante' : message.senderName;
    final time = _formatChatTime(message.timestamp);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0xFFF4F8F8),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      sender,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                  Text(
                    time,
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.black.withValues(alpha: 0.52),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(message.message),
            ],
          ),
        ),
      ),
    );
  }
}

String _formatChatTime(DateTime date) {
  final local = date.toLocal();
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}

class _ParticipantVideoTile extends StatefulWidget {
  final sdk.Participant participant;
  final String label;
  final bool mirror;

  const _ParticipantVideoTile({
    required this.participant,
    required this.label,
    this.mirror = false,
  });

  @override
  State<_ParticipantVideoTile> createState() => _ParticipantVideoTileState();
}

class _ParticipantVideoTileState extends State<_ParticipantVideoTile> {
  sdk.Stream? _videoStream;
  sdk.Stream? _audioStream;

  @override
  void initState() {
    super.initState();
    _syncInitialStreams();
    _registerStreamEvents();
  }

  @override
  void didUpdateWidget(covariant _ParticipantVideoTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.participant.id != widget.participant.id) {
      _syncInitialStreams();
      _registerStreamEvents();
    }
  }

  void _syncInitialStreams() {
    _videoStream = null;
    _audioStream = null;

    for (final stream in widget.participant.streams.values) {
      if (stream.kind == 'video') _videoStream = stream;
      if (stream.kind == 'audio') _audioStream = stream;
    }
  }

  void _registerStreamEvents() {
    widget.participant.on(sdk.Events.streamEnabled, (sdk.Stream stream) {
      if (!mounted) return;
      setState(() {
        if (stream.kind == 'video') _videoStream = stream;
        if (stream.kind == 'audio') _audioStream = stream;
      });
    });

    widget.participant.on(sdk.Events.streamDisabled, (sdk.Stream stream) {
      if (!mounted) return;
      setState(() {
        if (stream.kind == 'video' && _videoStream?.id == stream.id) {
          _videoStream = null;
        }
        if (stream.kind == 'audio' && _audioStream?.id == stream.id) {
          _audioStream = null;
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final renderer = _videoStream?.renderer;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white24),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (renderer is sdk.RTCVideoRenderer)
              sdk.RTCVideoView(
                renderer,
                mirror: widget.mirror,
                objectFit:
                    sdk.RTCVideoViewObjectFit.RTCVideoViewObjectFitContain,
              )
            else
              Center(
                child: Icon(
                  Icons.person,
                  color: Colors.white.withValues(alpha: 0.72),
                  size: widget.mirror ? 42 : 92,
                ),
              ),
            Positioned(
              left: 8,
              bottom: 8,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.62),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _audioStream == null ? Icons.mic_off : Icons.mic,
                        color: Colors.white,
                        size: 16,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        widget.label,
                        style: const TextStyle(color: Colors.white),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _InfoChip({
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: Icon(icon, size: 18),
      label: Text(label),
      backgroundColor: const Color(0xFFEFF7F7),
      side: BorderSide(color: AppTheme.primary.withValues(alpha: 0.18)),
    );
  }
}

class _RoundCallButton extends StatelessWidget {
  final String tooltip;
  final IconData icon;
  final bool active;
  final int badgeCount;
  final VoidCallback? onPressed;

  const _RoundCallButton({
    required this.tooltip,
    required this.icon,
    required this.active,
    this.badgeCount = 0,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final background = active ? Colors.white : const Color(0xFFFFE8E8);
    final foreground = active ? AppTheme.secondary : AppTheme.cancel;

    return Tooltip(
      message: tooltip,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          IconButton.filled(
            onPressed: onPressed,
            icon: Icon(icon),
            style: IconButton.styleFrom(
              backgroundColor: background,
              foregroundColor: foreground,
              disabledBackgroundColor: Colors.grey.shade200,
              disabledForegroundColor: Colors.grey,
              fixedSize: const Size(54, 54),
              shape: const CircleBorder(),
            ),
          ),
          if (badgeCount > 0)
            Positioned(
              right: -2,
              top: -2,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppTheme.danger,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: Colors.white, width: 1.5),
                ),
                child: Text(
                  badgeCount > 9 ? '9+' : badgeCount.toString(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
