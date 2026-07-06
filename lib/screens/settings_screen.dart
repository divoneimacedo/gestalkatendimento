import 'package:flutter/material.dart';
import 'package:videosdk/videosdk.dart' as sdk;

import '../services/call_device_preferences.dart';
import '../widgets/app_shell.dart';

class SettingsScreen extends StatefulWidget {
  final String slug;

  const SettingsScreen({super.key, required this.slug});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _preferences = const CallDevicePreferences();

  bool _loading = true;
  bool _saving = false;
  String? _error;
  List<_DeviceOption> _videoDevices = const [];
  List<_DeviceOption> _audioInputDevices = const [];
  List<_DeviceOption> _audioOutputDevices = const [];
  String? _selectedVideoDeviceId;
  String? _selectedAudioInputDeviceId;
  String? _selectedAudioOutputDeviceId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadDevices());
  }

  Future<void> _loadDevices() async {
    if (!mounted) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final preferences = await _preferences.load(widget.slug);
      final videoDevices = await sdk.VideoSDK.getVideoDevices();
      final audioDevices = await sdk.VideoSDK.getAudioDevices();
      final videos = (videoDevices ?? [])
          .where((device) => device.deviceId.isNotEmpty)
          .map(
            (device) => _DeviceOption(
              id: device.deviceId,
              label: device.label,
            ),
          )
          .toList();
      final audioInputs = (audioDevices ?? [])
          .where(
            (device) =>
                device.kind == 'audioinput' && device.deviceId.isNotEmpty,
          )
          .map(
            (device) => _DeviceOption(
              id: device.deviceId,
              label: device.label,
            ),
          )
          .toList();
      final audioOutputs = (audioDevices ?? [])
          .where(
            (device) =>
                device.kind == 'audiooutput' && device.deviceId.isNotEmpty,
          )
          .map(
            (device) => _DeviceOption(
              id: device.deviceId,
              label: device.label,
            ),
          )
          .toList();

      if (!mounted) return;
      setState(() {
        _videoDevices = videos;
        _audioInputDevices = audioInputs;
        _audioOutputDevices = audioOutputs;
        _selectedVideoDeviceId = _resolveSelectedDeviceId(
          currentId: preferences.videoDeviceId,
          devices: videos,
        );
        _selectedAudioInputDeviceId = _resolveSelectedDeviceId(
          currentId: preferences.audioInputDeviceId,
          devices: audioInputs,
        );
        _selectedAudioOutputDeviceId = _resolveSelectedDeviceId(
          currentId: preferences.audioOutputDeviceId,
          devices: audioOutputs,
        );
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = 'Não foi possível carregar dispositivos: $error');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String? _resolveSelectedDeviceId({
    required String? currentId,
    required List<_DeviceOption> devices,
  }) {
    if (devices.isEmpty) return null;
    if (currentId != null && devices.any((device) => device.id == currentId)) {
      return currentId;
    }
    return devices.first.id;
  }

  Future<void> _save() async {
    if (_saving) return;

    setState(() => _saving = true);
    try {
      final videoId = _selectedVideoDeviceId;
      final audioInputId = _selectedAudioInputDeviceId;
      final audioOutputId = _selectedAudioOutputDeviceId;

      if (videoId != null) {
        await _preferences.saveVideoDeviceId(widget.slug, videoId);
      }
      if (audioInputId != null) {
        await _preferences.saveAudioInputDeviceId(widget.slug, audioInputId);
      }
      if (audioOutputId != null) {
        await _preferences.saveAudioOutputDeviceId(widget.slug, audioOutputId);
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            behavior: SnackBarBehavior.floating,
            content: Text('Preferências de chamada salvas.'),
          ),
        );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            content: Text('Não foi possível salvar: $error'),
          ),
        );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppShell(
      title: 'Configurações',
      slug: widget.slug,
      currentRoute: 'settings',
      actions: [
        IconButton(
          tooltip: 'Atualizar dispositivos',
          onPressed: _loading || _saving ? null : _loadDevices,
          icon: const Icon(Icons.refresh),
        ),
      ],
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: Card(
            clipBehavior: Clip.antiAlias,
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: _body(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _body() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, size: 48, color: Colors.orange),
          const SizedBox(height: 12),
          Text(_error!, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _loadDevices,
            icon: const Icon(Icons.refresh),
            label: const Text('Tentar novamente'),
          ),
        ],
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Icon(Icons.settings_input_component_outlined),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Dispositivos padrão da chamada',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        _DeviceDropdown(
          label: 'Câmera',
          icon: Icons.videocam_outlined,
          value: _selectedVideoDeviceId,
          devices: _videoDevices,
          onChanged: (value) => setState(() => _selectedVideoDeviceId = value),
        ),
        const SizedBox(height: 14),
        _DeviceDropdown(
          label: 'Microfone',
          icon: Icons.mic_none_outlined,
          value: _selectedAudioInputDeviceId,
          devices: _audioInputDevices,
          onChanged: (value) =>
              setState(() => _selectedAudioInputDeviceId = value),
        ),
        const SizedBox(height: 14),
        _DeviceDropdown(
          label: 'Saída de áudio',
          icon: Icons.volume_up_outlined,
          value: _selectedAudioOutputDeviceId,
          devices: _audioOutputDevices,
          onChanged: (value) =>
              setState(() => _selectedAudioOutputDeviceId = value),
        ),
        const SizedBox(height: 22),
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton.icon(
            onPressed: _saving ? null : _save,
            icon: _saving
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save_outlined),
            label: const Text('Salvar'),
          ),
        ),
      ],
    );
  }
}

class _DeviceOption {
  final String id;
  final String label;

  const _DeviceOption({
    required this.id,
    required this.label,
  });
}

class _DeviceDropdown extends StatelessWidget {
  final String label;
  final IconData icon;
  final String? value;
  final List<_DeviceOption> devices;
  final ValueChanged<String?> onChanged;

  const _DeviceDropdown({
    required this.label,
    required this.icon,
    required this.value,
    required this.devices,
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
      hint: const Text('Nenhum dispositivo encontrado'),
      onChanged: devices.isEmpty ? null : onChanged,
    );
  }
}
