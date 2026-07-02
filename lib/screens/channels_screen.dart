import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../controllers/channels_controller.dart';
import '../core/config/app_theme.dart';
import '../models/channel.dart';
import '../widgets/app_overflow_tooltip_text.dart';
import '../widgets/app_pagination_controls.dart';
import '../widgets/app_shell.dart';
import '../widgets/shimmer_loading.dart';

class ChannelsScreen extends StatefulWidget {
  final String slug;
  final String? companyId;

  const ChannelsScreen({super.key, required this.slug, this.companyId});

  @override
  State<ChannelsScreen> createState() => _ChannelsScreenState();
}

class _ChannelsScreenState extends State<ChannelsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ChannelsController>().load(
            companyId: widget.companyId,
            resetPage: true,
          );
    });
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<ChannelsController>();

    return AppShell(
      title: 'Canais',
      slug: widget.slug,
      currentRoute: 'channels',
      actions: [
        IconButton(
          tooltip: 'Atualizar',
          onPressed: controller.loading
              ? null
              : () => controller.refresh(companyId: widget.companyId),
          icon: const Icon(Icons.refresh),
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _ChannelsToolbar(
            controller: controller,
            slug: widget.slug,
            companyId: widget.companyId,
          ),
          const SizedBox(height: 14),
          if (controller.error != null) ...[
            _ErrorBanner(controller.error!),
            const SizedBox(height: 12),
          ],
          Expanded(
            child: Card(
              margin: EdgeInsets.zero,
              clipBehavior: Clip.antiAlias,
              child: Stack(
                children: [
                  if (controller.channels.isEmpty && controller.loading)
                    const TableShimmer(rows: 12, columns: 8)
                  else if (controller.channels.isEmpty)
                    const Center(child: Text('Nenhum canal encontrado.'))
                  else
                    _ChannelsTable(
                      channels: controller.channels,
                      onOpenLink: _openAccessLink,
                      onQrCode: _showQrCodeDialog,
                      onEdit: (channel) => context.go(
                        '/channels/${widget.slug}/${channel.id}/edit',
                      ),
                    ),
                  if (controller.loading && controller.channels.isNotEmpty)
                    Positioned.fill(
                      child: ColoredBox(
                        color: Colors.white.withValues(alpha: 0.62),
                        child: const TableShimmer(rows: 8, columns: 8),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          AppPaginationControls(
            page: controller.page,
            totalPages: controller.totalPages,
            total: controller.total,
            canGoPrevious: controller.canGoPrevious,
            canGoNext: controller.canGoNext,
            onFirst: () => controller.firstPage(companyId: widget.companyId),
            onPrevious: () =>
                controller.previousPage(companyId: widget.companyId),
            onNext: () => controller.nextPage(companyId: widget.companyId),
            onLast: () => controller.lastPage(companyId: widget.companyId),
          ),
        ],
      ),
    );
  }

  Future<void> _openAccessLink(Channel channel) async {
    final uri = Uri.tryParse(channel.accessLink);

    if (uri == null || !uri.hasScheme) {
      _showSnack('Link de acesso inválido.', isError: true);
      return;
    }

    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened) {
      _showSnack('Não foi possível abrir o link.', isError: true);
    }
  }

  Future<void> _showQrCodeDialog(Channel channel) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text('QRCode - ${channel.name}'),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 320,
                  height: 320,
                  padding: const EdgeInsets.all(12),
                  color: Colors.white,
                  child: QrImageView(
                    data: channel.accessLink,
                    version: QrVersions.auto,
                    size: 296,
                    backgroundColor: Colors.white,
                  ),
                ),
                const SizedBox(height: 14),
                AppOverflowTooltipText(
                  channel.accessLink,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Fechar'),
            ),
            FilledButton.icon(
              onPressed: () async {
                try {
                  final file = await _saveQrCode(channel);
                  if (dialogContext.mounted) {
                    Navigator.of(dialogContext).pop();
                  }
                  _showSnack('QRCode salvo em ${file.path}.');
                } catch (_) {
                  _showSnack('Erro ao salvar QRCode.', isError: true);
                }
              },
              icon: const Icon(Icons.download_outlined),
              label: const Text('Baixar PNG'),
            ),
          ],
        );
      },
    );
  }

  Future<File> _saveQrCode(Channel channel) async {
    final painter = QrPainter(
      data: channel.accessLink,
      version: QrVersions.auto,
      gapless: true,
      eyeStyle: const QrEyeStyle(
        color: Colors.black,
        eyeShape: QrEyeShape.square,
      ),
      dataModuleStyle: const QrDataModuleStyle(
        color: Colors.black,
        dataModuleShape: QrDataModuleShape.square,
      ),
    );
    final imageData = await painter.toImageData(
      500,
      format: ui.ImageByteFormat.png,
    );

    if (imageData == null) {
      throw StateError('QRCode inválido.');
    }

    final home = Platform.environment['HOME'] ??
        Platform.environment['USERPROFILE'] ??
        '';
    final downloads =
        home.isEmpty ? Directory.current : Directory('$home/Downloads');
    final directory = await downloads.exists() ? downloads : Directory.current;
    final fileName =
        'qrcode-canal-${_fileSafe(channel.name)}-${_shortId(channel.id)}.png';
    final file = File('${directory.path}/$fileName');

    return file.writeAsBytes(imageData.buffer.asUint8List(), flush: true);
  }

  void _showSnack(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          backgroundColor: isError ? AppTheme.danger : null,
        ),
      );
  }
}

class _ChannelsToolbar extends StatefulWidget {
  final ChannelsController controller;
  final String slug;
  final String? companyId;

  const _ChannelsToolbar({
    required this.controller,
    required this.slug,
    required this.companyId,
  });

  @override
  State<_ChannelsToolbar> createState() => _ChannelsToolbarState();
}

class _ChannelsToolbarState extends State<_ChannelsToolbar> {
  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _searchController =
        TextEditingController(text: widget.controller.searchTerm);
  }

  @override
  void didUpdateWidget(covariant _ChannelsToolbar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_searchController.text != widget.controller.searchTerm) {
      _searchController.text = widget.controller.searchTerm;
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final isCompanyMode =
        widget.companyId != null && widget.companyId!.isNotEmpty;
    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      runSpacing: 12,
      spacing: 12,
      children: [
        Text(
          '${controller.total} canal(is)',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SizedBox(
              width: 340,
              child: TextField(
                controller: _searchController,
                enabled: !controller.loading && !isCompanyMode,
                onChanged: controller.setSearchTerm,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.white,
                  isDense: true,
                  prefixIcon: const Icon(Icons.search),
                  labelStyle: const TextStyle(color: Color(0xFF263238)),
                  floatingLabelStyle: const TextStyle(
                    color: AppTheme.primary,
                    fontWeight: FontWeight.w800,
                  ),
                  focusedBorder: const OutlineInputBorder(
                    borderSide: BorderSide(color: AppTheme.primary, width: 2),
                  ),
                  suffixIcon: controller.searchTerm.isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'Limpar busca',
                          onPressed: () {
                            _searchController.clear();
                            controller.setSearchTerm('');
                          },
                          icon: const Icon(Icons.close),
                        ),
                  labelText: 'Pesquisar por nome ou empresa',
                ),
              ),
            ),
            SizedBox(
              width: 210,
              child: DropdownButtonFormField<String>(
                initialValue: controller.statusFilter,
                decoration: const InputDecoration(
                  filled: true,
                  fillColor: Colors.white,
                  isDense: true,
                  labelText: 'Status',
                  labelStyle: TextStyle(color: Color(0xFF263238)),
                  floatingLabelStyle: TextStyle(
                    color: AppTheme.primary,
                    fontWeight: FontWeight.w800,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: AppTheme.primary, width: 2),
                  ),
                ),
                items: const [
                  DropdownMenuItem(value: 'active', child: Text('Ativos')),
                  DropdownMenuItem(value: 'inactive', child: Text('Inativos')),
                  DropdownMenuItem(value: 'all', child: Text('Todos')),
                ],
                onChanged: controller.loading || isCompanyMode
                    ? null
                    : (value) {
                        if (value == null) return;
                        controller.setStatusFilter(
                          value,
                          companyId: widget.companyId,
                        );
                      },
              ),
            ),
            if (isCompanyMode)
              OutlinedButton.icon(
                onPressed: () => context.go('/companies/${widget.slug}'),
                icon: const Icon(Icons.arrow_back),
                label: const Text('Voltar'),
              ),
            FilledButton.icon(
              onPressed: () => context.go('/channels/${widget.slug}/create'),
              icon: const Icon(Icons.add),
              label: const Text('Canal'),
            ),
          ],
        ),
      ],
    );
  }
}

class _ChannelsTable extends StatefulWidget {
  static const rowHeight = 64.0;
  static const headerHeight = 54.0;
  static const actionsWidth = 72.0;
  static const columns = [
    _ColumnSpec('ID', 100),
    _ColumnSpec('Empresa', 100, flexGrow: 0.35),
    _ColumnSpec('Nome', 100, flexGrow: 0.65),
    _ColumnSpec('Status', 100),
    _ColumnSpec('É privado?', 110),
    _ColumnSpec('Link de acesso', 140),
    _ColumnSpec('QRCode', 120),
  ];

  final List<Channel> channels;
  final ValueChanged<Channel> onOpenLink;
  final ValueChanged<Channel> onQrCode;
  final ValueChanged<Channel> onEdit;

  const _ChannelsTable({
    required this.channels,
    required this.onOpenLink,
    required this.onQrCode,
    required this.onEdit,
  });

  @override
  State<_ChannelsTable> createState() => _ChannelsTableState();
}

class _ChannelsTableState extends State<_ChannelsTable> {
  final _headerHorizontalController = ScrollController();
  final _bodyHorizontalController = ScrollController();
  final _bodyVerticalController = ScrollController();
  final _actionsVerticalController = ScrollController();
  bool _syncingHorizontal = false;
  bool _syncingVertical = false;

  @override
  void initState() {
    super.initState();
    _headerHorizontalController.addListener(_syncHeaderToBody);
    _bodyHorizontalController.addListener(_syncBodyToHeader);
    _bodyVerticalController.addListener(_syncBodyToActions);
    _actionsVerticalController.addListener(_syncActionsToBody);
  }

  @override
  void dispose() {
    _headerHorizontalController.dispose();
    _bodyHorizontalController.dispose();
    _bodyVerticalController.dispose();
    _actionsVerticalController.dispose();
    super.dispose();
  }

  void _syncHeaderToBody() {
    if (_syncingHorizontal || !_bodyHorizontalController.hasClients) return;
    _syncingHorizontal = true;
    _bodyHorizontalController.jumpTo(_safeOffset(
      _headerHorizontalController.offset,
      _bodyHorizontalController,
    ));
    _syncingHorizontal = false;
  }

  void _syncBodyToHeader() {
    if (_syncingHorizontal || !_headerHorizontalController.hasClients) return;
    _syncingHorizontal = true;
    _headerHorizontalController.jumpTo(_safeOffset(
      _bodyHorizontalController.offset,
      _headerHorizontalController,
    ));
    _syncingHorizontal = false;
  }

  void _syncBodyToActions() {
    if (_syncingVertical || !_actionsVerticalController.hasClients) return;
    _syncingVertical = true;
    _actionsVerticalController.jumpTo(_safeOffset(
      _bodyVerticalController.offset,
      _actionsVerticalController,
    ));
    _syncingVertical = false;
  }

  void _syncActionsToBody() {
    if (_syncingVertical || !_bodyVerticalController.hasClients) return;
    _syncingVertical = true;
    _bodyVerticalController.jumpTo(_safeOffset(
      _actionsVerticalController.offset,
      _bodyVerticalController,
    ));
    _syncingVertical = false;
  }

  double _safeOffset(double offset, ScrollController controller) {
    if (!controller.hasClients) return 0;
    return offset.clamp(0.0, controller.position.maxScrollExtent);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final leftViewportWidth =
            (constraints.maxWidth - _ChannelsTable.actionsWidth)
                .clamp(280.0, 9999.0);
        final resolvedColumns = _resolveColumns(leftViewportWidth);
        final tableWidth = resolvedColumns.fold<double>(
          0,
          (sum, column) => sum + column.width,
        );

        return Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: leftViewportWidth,
                  child: SingleChildScrollView(
                    controller: _headerHorizontalController,
                    scrollDirection: Axis.horizontal,
                    child: SizedBox(
                      width: tableWidth,
                      child: _HeaderRow(columns: resolvedColumns),
                    ),
                  ),
                ),
                const SizedBox(
                  width: _ChannelsTable.actionsWidth,
                  child: _ActionHeader(),
                ),
              ],
            ),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: leftViewportWidth,
                    child: SingleChildScrollView(
                      controller: _bodyHorizontalController,
                      scrollDirection: Axis.horizontal,
                      child: SizedBox(
                        width: tableWidth,
                        child: ListView.builder(
                          controller: _bodyVerticalController,
                          itemCount: widget.channels.length,
                          itemBuilder: (context, index) {
                            return _DataRow(
                              channel: widget.channels[index],
                              index: index,
                              columns: resolvedColumns,
                              onOpenLink: widget.onOpenLink,
                              onQrCode: widget.onQrCode,
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: _ChannelsTable.actionsWidth,
                    child: ListView.builder(
                      controller: _actionsVerticalController,
                      itemCount: widget.channels.length,
                      itemBuilder: (context, index) {
                        return _ActionRow(
                          channel: widget.channels[index],
                          index: index,
                          onEdit: widget.onEdit,
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  List<_ColumnSpec> _resolveColumns(double viewportWidth) {
    final baseWidth = _ChannelsTable.columns.fold<double>(
      0,
      (sum, column) => sum + column.width,
    );
    final extraWidth =
        viewportWidth > baseWidth ? viewportWidth - baseWidth : 0;
    final totalFlex = _ChannelsTable.columns.fold<double>(
      0,
      (sum, column) => sum + column.flexGrow,
    );

    return _ChannelsTable.columns
        .map(
          (column) => column.copyWith(
            width: column.width +
                (totalFlex > 0
                    ? extraWidth * (column.flexGrow / totalFlex)
                    : 0),
          ),
        )
        .toList();
  }
}

class _ColumnSpec {
  final String title;
  final double width;
  final double flexGrow;

  const _ColumnSpec(this.title, this.width, {this.flexGrow = 0});

  _ColumnSpec copyWith({double? width}) {
    return _ColumnSpec(
      title,
      width ?? this.width,
      flexGrow: flexGrow,
    );
  }
}

class _HeaderRow extends StatelessWidget {
  final List<_ColumnSpec> columns;

  const _HeaderRow({required this.columns});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: _ChannelsTable.headerHeight,
      color: const Color(0xFFEAF1F1),
      child: Row(
        children: [
          for (final column in columns)
            _Cell(
              width: column.width,
              child: Text(
                column.title,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
        ],
      ),
    );
  }
}

class _ActionHeader extends StatelessWidget {
  const _ActionHeader();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: _ChannelsTable.headerHeight,
      color: const Color(0xFFEAF1F1),
      alignment: Alignment.center,
      child: const Text(
        'Ações',
        style: TextStyle(fontWeight: FontWeight.w800),
      ),
    );
  }
}

class _DataRow extends StatelessWidget {
  final Channel channel;
  final int index;
  final List<_ColumnSpec> columns;
  final ValueChanged<Channel> onOpenLink;
  final ValueChanged<Channel> onQrCode;

  const _DataRow({
    required this.channel,
    required this.index,
    required this.columns,
    required this.onOpenLink,
    required this.onQrCode,
  });

  @override
  Widget build(BuildContext context) {
    final values = [
      channel.id,
      _fallback(channel.companyName),
      _fallback(channel.name),
      channel.isInative ? 'Inativo' : 'Ativo',
      channel.isPrivated ? 'Sim' : 'Não',
      'Acessar',
      'QRCode',
    ];

    return Container(
      height: _ChannelsTable.rowHeight,
      color: index.isEven ? const Color(0xFFF7FAFA) : Colors.white,
      child: Row(
        children: [
          for (var i = 0; i < columns.length; i++)
            _Cell(
              width: columns[i].width,
              child: switch (i) {
                3 => _StatusBadge(inactive: channel.isInative),
                5 => TextButton(
                    onPressed: () => onOpenLink(channel),
                    child: const Text(
                      'Acessar',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                6 => TextButton(
                    onPressed: () => onQrCode(channel),
                    child: const Text(
                      'QRCode',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                _ => AppOverflowTooltipText(
                    i == 0 ? _shortId(values[i]) : values[i],
                    tooltip: values[i],
                    maxLines: 2,
                  ),
              },
            ),
        ],
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  final Channel channel;
  final int index;
  final ValueChanged<Channel> onEdit;

  const _ActionRow({
    required this.channel,
    required this.index,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: _ChannelsTable.rowHeight,
      color: index.isEven ? const Color(0xFFF7FAFA) : Colors.white,
      alignment: Alignment.center,
      child: Tooltip(
        message: 'Editar',
        child: IconButton.filled(
          onPressed: () => onEdit(channel),
          icon: const Icon(Icons.edit_outlined, size: 18),
          style: IconButton.styleFrom(
            backgroundColor: const Color(0xFF0F5592),
            foregroundColor: Colors.white,
            fixedSize: const Size(38, 38),
            padding: EdgeInsets.zero,
          ),
        ),
      ),
    );
  }
}

class _Cell extends StatelessWidget {
  final double width;
  final Widget child;

  const _Cell({
    required this.width,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: double.infinity,
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        border: Border(
          right: BorderSide(color: Colors.black.withValues(alpha: 0.08)),
          bottom: BorderSide(color: Colors.black.withValues(alpha: 0.08)),
        ),
      ),
      child: child,
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final bool inactive;

  const _StatusBadge({required this.inactive});

  @override
  Widget build(BuildContext context) {
    final color = inactive ? AppTheme.danger : AppTheme.success;
    return Chip(
      label: Text(inactive ? 'Inativo' : 'Ativo'),
      backgroundColor: color.withValues(alpha: 0.12),
      labelStyle: TextStyle(color: color, fontWeight: FontWeight.w700),
      side: BorderSide(color: color.withValues(alpha: 0.2)),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final String message;

  const _ErrorBanner(this.message);

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.red.shade50,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Text(message, style: const TextStyle(color: AppTheme.danger)),
      ),
    );
  }
}

String _shortId(String id) {
  if (id.length <= 8) return id;
  return id.substring(0, 8);
}

String _fallback(String value) => value.isEmpty ? '-' : value;

String _fileSafe(String value) {
  final sanitized = value
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');
  return sanitized.isEmpty ? 'canal' : sanitized;
}
