import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../controllers/attendances_controller.dart';
import '../controllers/auth_controller.dart';
import '../core/config/app_theme.dart';
import '../models/attendance_call.dart';
import '../widgets/app_shell.dart';
import '../widgets/app_overflow_tooltip_text.dart';
import '../widgets/app_pagination_controls.dart';
import '../widgets/shimmer_loading.dart';

class AttendancesScreen extends StatefulWidget {
  final String slug;

  const AttendancesScreen({super.key, required this.slug});

  @override
  State<AttendancesScreen> createState() => _AttendancesScreenState();
}

class _AttendancesScreenState extends State<AttendancesScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AttendancesController>().load(slug: widget.slug);
    });
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<AttendancesController>();
    final isAdmin = context.watch<AuthController>().user?.isAdmin ?? false;

    return AppShell(
      title: 'Atendimentos',
      slug: widget.slug,
      currentRoute: 'attendances',
      actions: [
        IconButton(
          tooltip: 'Atualizar',
          onPressed: () => controller.refresh(slug: widget.slug),
          icon: const Icon(Icons.refresh),
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (controller.error != null)
            Card(
              color: Colors.red.shade50,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  controller.error!,
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            ),
          _AttendancesToolbar(
            controller: controller,
            slug: widget.slug,
          ),
          const SizedBox(height: 16),
          Expanded(
            child: Card(
              margin: EdgeInsets.zero,
              child: Stack(
                children: [
                  if (controller.calls.isEmpty && controller.loading)
                    TableShimmer(rows: 12, columns: isAdmin ? 7 : 6)
                  else if (controller.calls.isEmpty)
                    const Center(child: Text('Nenhum atendimento encontrado.'))
                  else
                    _AttendancesTable(
                      calls: controller.calls,
                      isAdmin: isAdmin,
                      onOpen: (call) =>
                          context.go('/call-details/${widget.slug}/${call.id}'),
                    ),
                  if (controller.loading && controller.calls.isNotEmpty)
                    Positioned.fill(
                      child: ColoredBox(
                        color: Colors.white.withValues(alpha: 0.55),
                        child: TableShimmer(rows: 8, columns: isAdmin ? 7 : 6),
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
            onFirst: () => controller.firstPage(slug: widget.slug),
            onPrevious: () => controller.previousPage(slug: widget.slug),
            onNext: () => controller.nextPage(slug: widget.slug),
            onLast: () => controller.lastPage(slug: widget.slug),
          ),
        ],
      ),
    );
  }
}

class _AttendancesToolbar extends StatefulWidget {
  final AttendancesController controller;
  final String slug;

  const _AttendancesToolbar({
    required this.controller,
    required this.slug,
  });

  @override
  State<_AttendancesToolbar> createState() => _AttendancesToolbarState();
}

class _AttendancesToolbarState extends State<_AttendancesToolbar> {
  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _searchController =
        TextEditingController(text: widget.controller.searchTerm);
  }

  @override
  void didUpdateWidget(covariant _AttendancesToolbar oldWidget) {
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

    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      runSpacing: 10,
      spacing: 12,
      children: [
        Text(
          '${controller.total} atendimento(s)',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
        Wrap(
          spacing: 12,
          runSpacing: 10,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SizedBox(
              width: 340,
              child: TextField(
                controller: _searchController,
                enabled: !controller.loading,
                onChanged: (value) => controller.setSearchTerm(
                  slug: widget.slug,
                  value: value,
                ),
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
                            controller.setSearchTerm(
                              slug: widget.slug,
                              value: '',
                            );
                          },
                          icon: const Icon(Icons.close),
                        ),
                  labelText: 'Buscar por canal ou protocolo',
                ),
              ),
            ),
            SizedBox(
              width: 230,
              child: DropdownButtonFormField<String>(
                initialValue: controller.status,
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
                  DropdownMenuItem(value: 'ALL', child: Text('Todos')),
                  DropdownMenuItem(
                    value: 'WAITING_FOR_RESPONSE',
                    child: Text('Aguardando'),
                  ),
                  DropdownMenuItem(
                    value: 'IN_PROGRESS',
                    child: Text('Em atendimento'),
                  ),
                  DropdownMenuItem(
                      value: 'FINISHED', child: Text('Finalizado')),
                  DropdownMenuItem(value: 'CANCELED', child: Text('Cancelado')),
                ],
                onChanged: controller.loading
                    ? null
                    : (value) {
                        if (value == null) return;
                        controller.setStatus(
                          slug: widget.slug,
                          value: value,
                        );
                      },
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _AttendancesTable extends StatefulWidget {
  static const rowHeight = 58.0;
  static const headerHeight = 48.0;
  static const actionsWidth = 104.0;
  static const columns = [
    _ColumnSpec('ID', 190),
    _ColumnSpec('Protocolo', 100),
    _ColumnSpec('Status', 100),
    _ColumnSpec('Canal', 220),
    _ColumnSpec('Hora de entrada', 170),
    _ColumnSpec('Encerramento', 170),
  ];

  final List<AttendanceCall> calls;
  final bool isAdmin;
  final ValueChanged<AttendanceCall> onOpen;

  const _AttendancesTable({
    required this.calls,
    required this.isAdmin,
    required this.onOpen,
  });

  @override
  State<_AttendancesTable> createState() => _AttendancesTableState();
}

class _AttendancesTableState extends State<_AttendancesTable> {
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
    final max = controller.position.maxScrollExtent;
    return offset.clamp(0.0, max);
  }

  List<_ColumnSpec> _expandedColumns(
    List<_ColumnSpec> columns,
    double availableExtra,
  ) {
    if (availableExtra <= 0) return columns;

    const weights = {
      'Protocolo': 0.6,
      'Status': 0.6,
      'Canal': 1.5,
      'Hora de entrada': 1.2,
      'Encerramento': 1.2,
    };
    final totalWeight = weights.values.fold<double>(
      0,
      (sum, weight) => sum + weight,
    );

    return [
      for (final column in columns)
        _ColumnSpec(
          column.title,
          column.width +
              (availableExtra * (weights[column.title] ?? 0) / totalWeight),
        ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final leftMinWidth = _AttendancesTable.columns.fold<double>(
          0,
          (sum, column) => sum + column.width,
        );
        final reservedActionsWidth =
            widget.isAdmin ? _AttendancesTable.actionsWidth : 0.0;
        final leftViewportWidth =
            (constraints.maxWidth - reservedActionsWidth).clamp(280.0, 9999.0);
        final columns = _expandedColumns(
          _AttendancesTable.columns,
          leftViewportWidth - leftMinWidth,
        );
        final leftContentWidth = columns.fold<double>(
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
                      width: leftContentWidth,
                      child: _HeaderRow(columns: columns),
                    ),
                  ),
                ),
                if (widget.isAdmin)
                  SizedBox(
                    width: _AttendancesTable.actionsWidth,
                    child: const _ActionHeader(),
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
                        width: leftContentWidth,
                        child: ListView.builder(
                          controller: _bodyVerticalController,
                          itemCount: widget.calls.length,
                          itemBuilder: (context, index) {
                            return _CallDataRow(
                              call: widget.calls[index],
                              index: index,
                              columns: columns,
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                  if (widget.isAdmin)
                    SizedBox(
                      width: _AttendancesTable.actionsWidth,
                      child: ListView.builder(
                        controller: _actionsVerticalController,
                        itemCount: widget.calls.length,
                        itemBuilder: (context, index) {
                          return _CallActionRow(
                            call: widget.calls[index],
                            index: index,
                            onOpen: widget.onOpen,
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
}

class _ColumnSpec {
  final String title;
  final double width;

  const _ColumnSpec(this.title, this.width);
}

class _HeaderRow extends StatelessWidget {
  final List<_ColumnSpec> columns;

  const _HeaderRow({required this.columns});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: _AttendancesTable.headerHeight,
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
      height: _AttendancesTable.headerHeight,
      color: const Color(0xFFEAF1F1),
      alignment: Alignment.center,
      child: const Text(
        'Ações',
        style: TextStyle(fontWeight: FontWeight.w800),
      ),
    );
  }
}

class _CallDataRow extends StatelessWidget {
  final AttendanceCall call;
  final int index;
  final List<_ColumnSpec> columns;

  const _CallDataRow({
    required this.call,
    required this.index,
    required this.columns,
  });

  @override
  Widget build(BuildContext context) {
    final values = [
      _shortId(call.id),
      _fallback(call.protocol),
      _translateStatus(call.status),
      _fallback(call.channelName),
      _formatDate(call.createdAt),
      _formatDate(call.endedAt),
    ];

    return Container(
      height: _AttendancesTable.rowHeight,
      color: index.isEven ? const Color(0xFFF7FAFA) : Colors.white,
      child: Row(
        children: [
          for (var i = 0; i < columns.length; i++)
            _Cell(
              width: columns[i].width,
              child: i == 2
                  ? _StatusBadge(status: call.status)
                  : AppOverflowTooltipText(
                      values[i],
                      tooltip: i == 0 ? call.id : values[i],
                    ),
            ),
        ],
      ),
    );
  }
}

class _CallActionRow extends StatelessWidget {
  final AttendanceCall call;
  final int index;
  final ValueChanged<AttendanceCall> onOpen;

  const _CallActionRow({
    required this.call,
    required this.index,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: _AttendancesTable.rowHeight,
      color: index.isEven ? const Color(0xFFF7FAFA) : Colors.white,
      alignment: Alignment.center,
      child: Tooltip(
        message: 'Ver detalhes',
        child: IconButton.filledTonal(
          onPressed: () => onOpen(call),
          icon: const Icon(Icons.open_in_new, size: 18),
          color: AppTheme.primary,
          constraints: const BoxConstraints.tightFor(width: 38, height: 38),
          padding: EdgeInsets.zero,
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
  final String status;

  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(status);

    return Chip(
      label: Text(_translateStatus(status)),
      backgroundColor: color.withValues(alpha: 0.12),
      labelStyle: TextStyle(color: color, fontWeight: FontWeight.w700),
      side: BorderSide(color: color.withValues(alpha: 0.2)),
    );
  }
}

Color _statusColor(String status) {
  return switch (status) {
    'FINISHED' => AppTheme.success,
    'CANCELED' => AppTheme.danger,
    'IN_PROGRESS' => Colors.blue,
    'WAITING_FOR_RESPONSE' => Colors.orange,
    _ => Colors.grey,
  };
}

String _shortId(String id) {
  if (id.length <= 8) return id;
  return id.substring(0, 8);
}

String _formatDate(DateTime? date) {
  if (date == null) return '-';
  return DateFormat('dd/MM/yyyy HH:mm').format(date.toLocal());
}

String _translateStatus(String status) {
  return switch (status) {
    'FINISHED' => 'Finalizado',
    'CANCELED' => 'Cancelado',
    'IN_PROGRESS' => 'Em atendimento',
    'WAITING_FOR_RESPONSE' => 'Aguardando',
    _ => status.isEmpty ? '-' : status,
  };
}

String _fallback(String? value) {
  final text = value?.trim();
  if (text == null || text.isEmpty) return '-';
  return text;
}
