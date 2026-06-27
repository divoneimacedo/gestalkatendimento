import 'dart:io';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:videosdk/videosdk.dart' as sdk;

import '../controllers/auth_controller.dart';
import '../controllers/call_controller.dart';
import '../core/config/app_theme.dart';
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
  sdk.Room? _room;
  final Map<String, sdk.Participant> _remoteParticipants = {};

  bool _joining = true;
  bool _joined = false;
  bool _cameraEnabled = true;
  bool _microphoneEnabled = true;
  bool _speakerEnabled = true;
  String? _callError;
  String _roomState = 'Conectando';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _startCallFlow());
  }

  @override
  void dispose() {
    _leaveRoom();
    super.dispose();
  }

  Future<void> _startCallFlow() async {
    setState(() {
      _joining = true;
      _callError = null;
    });

    final controller = context.read<CallController>();
    final auth = context.read<AuthController>();

    try {
      final granted = await _requestMediaPermissions();
      if (!granted) {
        setState(() {
          _joining = false;
          _callError =
              'Permissão de câmera ou microfone não concedida. Libere o acesso nas configurações do sistema.';
        });
        return;
      }

      await controller.load(widget.callId);

      final call = controller.currentCall;
      final token = controller.videoSdkToken;

      if (call == null || call.meetingId.isEmpty) {
        setState(() {
          _joining = false;
          _callError = 'A chamada não possui sala VideoSDK vinculada.';
        });
        return;
      }

      if (token == null || token.isEmpty) {
        setState(() {
          _joining = false;
          _callError = 'Não foi possível obter o token temporário do VideoSDK.';
        });
        return;
      }

      _joinRoom(
        meetingId: call.meetingId,
        token: token,
        displayName:
            auth.user?.name.isNotEmpty == true ? auth.user!.name : 'Atendente',
      );
    } catch (_) {
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

  void _joinRoom({
    required String meetingId,
    required String token,
    required String displayName,
  }) {
    _leaveRoom();

    final room = sdk.VideoSDK.createRoom(
      roomId: meetingId,
      token: token,
      displayName: displayName,
      micEnabled: _microphoneEnabled,
      camEnabled: _cameraEnabled,
      maxResolution: 'hd',
      multiStream: true,
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

  void _registerRoomEvents(sdk.Room room) {
    room.on(sdk.Events.roomJoined, () {
      setState(() {
        _joining = false;
        _joined = true;
        _roomState = 'Conectado';
        _remoteParticipants
          ..clear()
          ..addAll(room.participants);
      });
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
      setState(() {
        _callError = _extractVideoSdkError(error);
        _joining = false;
      });
    });
  }

  Future<void> _toggleMicrophone() async {
    final room = _room;
    if (room == null) return;

    if (_microphoneEnabled) {
      await room.muteMic();
    } else {
      await room.unmuteMic();
    }

    setState(() => _microphoneEnabled = !_microphoneEnabled);
  }

  Future<void> _toggleCamera() async {
    final room = _room;
    if (room == null) return;

    if (_cameraEnabled) {
      await room.disableCam();
    } else {
      await room.enableCam();
    }

    setState(() => _cameraEnabled = !_cameraEnabled);
  }

  void _toggleSpeaker() {
    setState(() => _speakerEnabled = !_speakerEnabled);
  }

  Future<void> _finishCall(BuildContext context) async {
    final controller = context.read<CallController>();

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
      context.go('/queue/${widget.slug}');
    }
  }

  void _leaveRoom() {
    try {
      _room?.leave();
    } catch (_) {}
    _room = null;
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
      actions: [
        IconButton(
          tooltip: 'Reconectar',
          onPressed: _joining ? null : _startCallFlow,
          icon: const Icon(Icons.refresh),
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _callHeader(controller),
          const SizedBox(height: 12),
          Expanded(child: _stage()),
          const SizedBox(height: 16),
          _toolbar(controller),
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
              subtitle: 'Você já entrou na sala VideoSDK.',
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

  Widget _toolbar(CallController controller) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
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
                objectFit: sdk.RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
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
  final VoidCallback? onPressed;

  const _RoundCallButton({
    required this.tooltip,
    required this.icon,
    required this.active,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final background = active ? Colors.white : const Color(0xFFFFE8E8);
    final foreground = active ? AppTheme.secondary : AppTheme.cancel;

    return Tooltip(
      message: tooltip,
      child: IconButton.filled(
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
    );
  }
}
