import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:file_selector/file_selector.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../controllers/call_controller.dart';
import '../core/config/app_theme.dart';
import '../models/call_details.dart';
import '../widgets/app_overflow_tooltip_text.dart';
import '../widgets/app_shell.dart';
import '../widgets/shimmer_loading.dart';

class CallDetailsScreen extends StatefulWidget {
  final String slug;
  final String callId;

  const CallDetailsScreen({
    super.key,
    required this.slug,
    required this.callId,
  });

  @override
  State<CallDetailsScreen> createState() => _CallDetailsScreenState();
}

class _CallDetailsScreenState extends State<CallDetailsScreen> {
  CallDetails? _details;
  List<CallRecording> _recordings = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final service = context.read<CallController>().callService;
      final details = await service.getById(widget.callId);
      final recordings = await service.getRecordings(widget.callId);

      if (!mounted) return;
      setState(() {
        _details = details;
        _recordings = recordings;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = 'Não foi possível carregar os detalhes do atendimento.';
      });
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppShell(
      title: 'Detalhes do atendimento',
      slug: widget.slug,
      currentRoute: 'attendances',
      actions: [
        IconButton(
          tooltip: 'Atualizar',
          onPressed: _load,
          icon: const Icon(Icons.refresh),
        ),
      ],
      child: Card(
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        child: _buildContent(context),
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    if (_loading && _details == null) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: TableShimmer(rows: 8, columns: 2),
      );
    }

    if (_error != null && _details == null) {
      return _ErrorState(message: _error!, onRetry: _load);
    }

    final details = _details;
    if (details == null) {
      return _ErrorState(
        message: 'Atendimento não encontrado.',
        onRetry: _load,
      );
    }

    return Column(
      children: [
        _Header(
          details: details,
          onBack: () => _goBack(context),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _load,
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _InlineError(message: _error!),
                  ),
                _InfoSection(details: details),
                const SizedBox(height: 20),
                _RecordingsSection(recordings: _recordings),
                const SizedBox(height: 20),
                _ReviewsSection(reviews: details.reviews),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _goBack(BuildContext context) {
    if (context.canPop()) {
      context.pop();
      return;
    }

    context.go('/attendances/${widget.slug}');
  }
}

class _Header extends StatelessWidget {
  final CallDetails details;
  final VoidCallback onBack;

  const _Header({
    required this.details,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    final shortId =
        details.id.length <= 5 ? details.id : details.id.substring(0, 5);
    final protocol = details.protocol.isEmpty ? '-' : details.protocol;

    return Container(
      color: const Color(0xFFF7F9FA),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Informações do atendimento $shortId - Protocolo #$protocol',
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          FilledButton.icon(
            onPressed: onBack,
            icon: const Icon(Icons.arrow_back, size: 18),
            label: const Text('Voltar'),
            style: FilledButton.styleFrom(backgroundColor: AppTheme.secondary),
          ),
        ],
      ),
    );
  }
}

class _InfoSection extends StatelessWidget {
  final CallDetails details;

  const _InfoSection({required this.details});

  @override
  Widget build(BuildContext context) {
    final items = [
      _DetailItem('Origem', 'T Channel', Icons.hub_outlined),
      _DetailItem('IP', _fallback(details.ip), Icons.language_outlined),
      _DetailItem(
        'Dispositivo',
        _fallback(details.device),
        Icons.devices_outlined,
      ),
      _DetailItem(
        'Hora de entrada',
        _formatDateTime(details.createdAt),
        Icons.login_outlined,
      ),
      _DetailItem(
        'Hora de encerramento',
        _formatDateTime(details.endedAt),
        Icons.logout_outlined,
      ),
      _DetailItem(
        'Duração do atendimento',
        _formatDuration(details.duration),
        Icons.timer_outlined,
      ),
      _DetailItem(
        'Consentimento de gravação',
        details.recordingConsentAccepted ? 'Aceito' : 'Não aceito',
        details.recordingConsentAccepted
            ? Icons.verified_user_outlined
            : Icons.gpp_bad_outlined,
      ),
      _DetailItem(
        'Data do consentimento',
        _formatDateTime(details.recordingConsentAcceptedAt),
        Icons.event_available_outlined,
      ),
    ];

    return _SectionCard(
      title: 'Dados do atendimento',
      icon: Icons.info_outline,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final columns = constraints.maxWidth >= 900 ? 2 : 1;
          final spacing = 12.0;
          final width =
              (constraints.maxWidth - (spacing * (columns - 1))) / columns;

          return Wrap(
            spacing: spacing,
            runSpacing: spacing,
            children: [
              for (final item in items)
                SizedBox(
                  width: width,
                  child: _DetailTile(item: item),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _RecordingsSection extends StatelessWidget {
  final List<CallRecording> recordings;

  const _RecordingsSection({required this.recordings});

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Gravações da chamada',
      icon: Icons.video_library_outlined,
      child: recordings.isEmpty
          ? const _EmptyMessage(
              icon: Icons.videocam_off_outlined,
              message: 'Nenhuma gravação disponível para este atendimento.',
            )
          : Column(
              children: [
                for (var i = 0; i < recordings.length; i++) ...[
                  if (i > 0) const SizedBox(height: 12),
                  _RecordingCard(recording: recordings[i]),
                ],
              ],
            ),
    );
  }
}

class _RecordingCard extends StatelessWidget {
  final CallRecording recording;

  const _RecordingCard({required this.recording});

  @override
  Widget build(BuildContext context) {
    final file = recording.file;
    final fileUrl = file?.fileUrl ?? '';
    final hasFile = fileUrl.isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFA),
        border: Border.all(color: Colors.black.withValues(alpha: 0.08)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 16,
            runSpacing: 8,
            children: [
              _CompactInfo(
                label: 'Data da gravação',
                value: _formatDateTime(recording.createdAt),
              ),
              _CompactInfo(
                label: 'Duração',
                value: _formatSeconds(file?.durationSeconds ?? 0),
              ),
              _CompactInfo(
                label: 'Origem',
                value: (file?.type ?? '').isEmpty ? 'VideoSDK' : file!.type,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerLeft,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: hasFile
                  ? _RecordingVideoPlayer(url: fileUrl)
                  : const _RecordingPlaceholder(),
            ),
          ),
          const SizedBox(height: 12),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                FilledButton.icon(
                  onPressed: hasFile ? () => _openUrl(context, fileUrl) : null,
                  icon: const Icon(Icons.open_in_new, size: 18),
                  label: const Text('Abrir vídeo'),
                ),
                if (hasFile)
                  _DownloadVideoButton(
                    url: fileUrl,
                    suggestedName: _recordingFileName(recording),
                    durationText: _formatSeconds(file?.durationSeconds ?? 0),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openUrl(BuildContext context, String url) async {
    final uri = Uri.tryParse(url);

    if (uri == null) {
      _showMessage(context, 'Link da gravação inválido.');
      return;
    }

    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && context.mounted) {
      _showMessage(context, 'Não foi possível abrir a gravação.');
    }
  }
}

class _DownloadVideoButton extends StatefulWidget {
  final String url;
  final String suggestedName;
  final String durationText;

  const _DownloadVideoButton({
    required this.url,
    required this.suggestedName,
    required this.durationText,
  });

  @override
  State<_DownloadVideoButton> createState() => _DownloadVideoButtonState();
}

class _DownloadVideoButtonState extends State<_DownloadVideoButton> {
  final Dio _dio = Dio();
  bool _downloading = false;
  double _progress = 0;

  @override
  Widget build(BuildContext context) {
    return FilledButton.tonalIcon(
      onPressed: _downloading ? null : _download,
      icon: _downloading
          ? SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                value: _progress > 0 && _progress < 1 ? _progress : null,
              ),
            )
          : const Icon(Icons.download, size: 18),
      label: Text(
        _downloading
            ? 'Baixando ${(_progress * 100).clamp(0, 100).round()}%'
            : 'Baixar vídeo (${widget.durationText})',
      ),
    );
  }

  Future<void> _download() async {
    final location = await getSaveLocation(
      suggestedName: widget.suggestedName,
      acceptedTypeGroups: const [
        XTypeGroup(
          label: 'Vídeo MP4',
          extensions: ['mp4'],
          mimeTypes: ['video/mp4'],
        ),
      ],
    );

    if (location == null) return;

    setState(() {
      _downloading = true;
      _progress = 0;
    });

    try {
      await _dio.download(
        widget.url,
        location.path,
        options: Options(responseType: ResponseType.bytes),
        onReceiveProgress: (received, total) {
          if (!mounted || total <= 0) return;
          setState(() => _progress = received / total);
        },
      );

      if (!mounted) return;
      _showMessage(context, 'Vídeo salvo em: ${location.path}');
    } catch (_) {
      if (!mounted) return;
      _showMessage(context, 'Não foi possível baixar o vídeo.');
    } finally {
      if (mounted) {
        setState(() {
          _downloading = false;
          _progress = 0;
        });
      }
    }
  }
}

class _RecordingVideoPlayer extends StatefulWidget {
  final String url;

  const _RecordingVideoPlayer({required this.url});

  @override
  State<_RecordingVideoPlayer> createState() => _RecordingVideoPlayerState();
}

class _RecordingVideoPlayerState extends State<_RecordingVideoPlayer> {
  late final Player _player;
  late final VideoController _controller;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _player = Player();
    _controller = VideoController(_player);
    _open();
  }

  @override
  void didUpdateWidget(covariant _RecordingVideoPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) {
      _open();
    }
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Future<void> _open() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await _player.open(Media(widget.url), play: false);
      if (mounted) {
        setState(() => _loading = false);
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Não foi possível carregar o vídeo no player.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: ColoredBox(
          color: const Color(0xFF1F2130),
          child: Stack(
            alignment: Alignment.center,
            children: [
              if (_error == null) Video(controller: _controller),
              if (_loading)
                const Center(
                  child: CircularProgressIndicator(color: Colors.white),
                ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.videocam_off_outlined,
                        color: Colors.white.withValues(alpha: 0.82),
                        size: 46,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        _error!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white),
                      ),
                      const SizedBox(height: 12),
                      FilledButton.tonalIcon(
                        onPressed: _open,
                        icon: const Icon(Icons.refresh, size: 18),
                        label: const Text('Tentar novamente'),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RecordingPlaceholder extends StatelessWidget {
  const _RecordingPlaceholder();

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF1F2130),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Center(
          child: Icon(
            Icons.videocam_off_outlined,
            color: Colors.white.withValues(alpha: 0.82),
            size: 54,
          ),
        ),
      ),
    );
  }
}

class _ReviewsSection extends StatelessWidget {
  final List<CallReview> reviews;

  const _ReviewsSection({required this.reviews});

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Avaliações',
      icon: Icons.star_outline,
      child: reviews.isEmpty
          ? const _EmptyMessage(
              icon: Icons.rate_review_outlined,
              message: 'Nenhuma avaliação registrada para este atendimento.',
            )
          : Column(
              children: [
                for (var i = 0; i < reviews.length; i++) ...[
                  if (i > 0) const SizedBox(height: 10),
                  _ReviewCard(review: reviews[i]),
                ],
              ],
            ),
    );
  }
}

class _ReviewCard extends StatelessWidget {
  final CallReview review;

  const _ReviewCard({required this.review});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.black.withValues(alpha: 0.08)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Estrelas',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              for (var i = 1; i <= 5; i++)
                Icon(
                  i <= review.rating ? Icons.star : Icons.star_border,
                  color: const Color(0xFFFFB300),
                  size: 22,
                ),
            ],
          ),
          const SizedBox(height: 10),
          const Text(
            'Comentário',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(
            review.description.trim().isEmpty ? '-' : review.description,
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;

  const _SectionCard({
    required this.title,
    required this.icon,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.black.withValues(alpha: 0.08)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppTheme.primary),
              const SizedBox(width: 10),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

class _DetailTile extends StatelessWidget {
  final _DetailItem item;

  const _DetailTile({required this.item});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFA),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(item.icon, color: AppTheme.secondary, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.label,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF2F3A3A),
                  ),
                ),
                const SizedBox(height: 4),
                AppOverflowTooltipText(
                  item.value,
                  maxLines: 3,
                  style: const TextStyle(color: Color(0xFF2F3A3A)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CompactInfo extends StatelessWidget {
  final String label;
  final String value;

  const _CompactInfo({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 220,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          AppOverflowTooltipText(value),
        ],
      ),
    );
  }
}

class _EmptyMessage extends StatelessWidget {
  final IconData icon;
  final String message;

  const _EmptyMessage({
    required this.icon,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFA),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.black54),
          const SizedBox(width: 10),
          Expanded(child: Text(message)),
        ],
      ),
    );
  }
}

class _InlineError extends StatelessWidget {
  final String message;

  const _InlineError({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(message, style: const TextStyle(color: Colors.red)),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorState({
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 46, color: AppTheme.danger),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Tentar novamente'),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailItem {
  final String label;
  final String value;
  final IconData icon;

  const _DetailItem(this.label, this.value, this.icon);
}

String _fallback(String value) {
  return value.trim().isEmpty ? '-' : value;
}

String _formatDateTime(DateTime? date) {
  if (date == null) return '-';
  return DateFormat('dd/MM/yyyy - HH:mm:ss').format(date.toLocal());
}

String _formatDuration(Duration? duration) {
  if (duration == null || duration.isNegative) return '-';
  return _formatSeconds(duration.inSeconds);
}

String _formatSeconds(int seconds) {
  if (seconds <= 0) return 'N/A';
  final minutes = seconds ~/ 60;
  final remainingSeconds = seconds % 60;

  if (minutes <= 0) return '${remainingSeconds}s';
  if (remainingSeconds == 0) return '${minutes}m';

  return '${minutes}m ${remainingSeconds}s';
}

String _recordingFileName(CallRecording recording) {
  final date = recording.createdAt;
  final suffix = date == null
      ? DateTime.now().millisecondsSinceEpoch.toString()
      : DateFormat('yyyyMMdd_HHmmss').format(date.toLocal());
  final id = recording.id.isEmpty ? 'gravacao' : recording.id;

  return 'atendimento_${id}_$suffix.mp4';
}

void _showMessage(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(message)),
  );
}
