import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../controllers/interpreters_controller.dart';
import '../core/config/app_theme.dart';
import '../models/interpreter.dart';
import '../widgets/app_overflow_tooltip_text.dart';
import '../widgets/app_pagination_controls.dart';
import '../widgets/app_shell.dart';
import '../widgets/shimmer_loading.dart';

class InterpretersScreen extends StatefulWidget {
  final String slug;

  const InterpretersScreen({super.key, required this.slug});

  @override
  State<InterpretersScreen> createState() => _InterpretersScreenState();
}

class _InterpretersScreenState extends State<InterpretersScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<InterpretersController>().load(resetPage: true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<InterpretersController>();

    return AppShell(
      title: 'Intérpretes',
      slug: widget.slug,
      currentRoute: 'interpreters',
      actions: [
        IconButton(
          tooltip: 'Atualizar',
          onPressed: controller.loading ? null : controller.refresh,
          icon: const Icon(Icons.refresh),
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _InterpretersToolbar(controller: controller),
          const SizedBox(height: 16),
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
                  if (controller.interpreters.isEmpty && controller.loading)
                    const TableShimmer(rows: 10, columns: 7)
                  else if (controller.interpreters.isEmpty)
                    const Center(child: Text('Nenhum intérprete encontrado.'))
                  else
                    _InterpretersTable(interpreters: controller.interpreters),
                  if (controller.loading && controller.interpreters.isNotEmpty)
                    Positioned.fill(
                      child: ColoredBox(
                        color: Colors.white.withValues(alpha: 0.62),
                        child: const TableShimmer(rows: 8, columns: 7),
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
            onFirst: controller.firstPage,
            onPrevious: controller.previousPage,
            onNext: controller.nextPage,
            onLast: controller.lastPage,
          ),
        ],
      ),
    );
  }
}

class _InterpretersToolbar extends StatefulWidget {
  final InterpretersController controller;

  const _InterpretersToolbar({required this.controller});

  @override
  State<_InterpretersToolbar> createState() => _InterpretersToolbarState();
}

class _InterpretersToolbarState extends State<_InterpretersToolbar> {
  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _searchController =
        TextEditingController(text: widget.controller.searchTerm);
  }

  @override
  void didUpdateWidget(covariant _InterpretersToolbar oldWidget) {
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
      runSpacing: 12,
      spacing: 12,
      children: [
        Text(
          '${controller.total} intérprete(s)',
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
            _FilterButton(
              label: 'Todos',
              selected: controller.statusFilter == 'all',
              onPressed: controller.loading
                  ? null
                  : () => controller.setStatusFilter('all'),
            ),
            _FilterButton(
              label: 'Disponível',
              selected: controller.statusFilter == 'available',
              onPressed: controller.loading
                  ? null
                  : () => controller.setStatusFilter('available'),
            ),
            _FilterButton(
              label: 'Em chamada',
              selected: controller.statusFilter == 'in_call',
              onPressed: controller.loading
                  ? null
                  : () => controller.setStatusFilter('in_call'),
            ),
            _FilterButton(
              label: 'Offline',
              selected: controller.statusFilter == 'offline',
              onPressed: controller.loading
                  ? null
                  : () => controller.setStatusFilter('offline'),
            ),
            SizedBox(
              width: 300,
              child: TextField(
                controller: _searchController,
                enabled: !controller.loading,
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
                  labelText: 'Buscar por nome',
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _FilterButton extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback? onPressed;

  const _FilterButton({
    required this.label,
    required this.selected,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: selected ? AppTheme.primary : const Color(0xFFE3E7EC),
        foregroundColor: selected ? Colors.white : const Color(0xFF44525F),
      ),
      child: Text(label),
    );
  }
}

class _InterpretersTable extends StatefulWidget {
  static const rowHeight = 66.0;
  static const headerHeight = 54.0;
  static const columns = [
    _ColumnSpec('Nome completo', 160, flexGrow: 0.2),
    _ColumnSpec('Username', 140, flexGrow: 0.15),
    _ColumnSpec('Horário de conexão', 110),
    _ColumnSpec('Status', 130),
    _ColumnSpec('Chamada atual', 220, flexGrow: 0.45),
    _ColumnSpec('Chamadas atendidas', 110),
    _ColumnSpec('Tempo médio', 90),
  ];

  final List<InterpreterListItem> interpreters;

  const _InterpretersTable({required this.interpreters});

  @override
  State<_InterpretersTable> createState() => _InterpretersTableState();
}

class _InterpretersTableState extends State<_InterpretersTable> {
  final _headerHorizontalController = ScrollController();
  final _bodyHorizontalController = ScrollController();
  final _bodyVerticalController = ScrollController();
  bool _syncingHorizontal = false;

  @override
  void initState() {
    super.initState();
    _headerHorizontalController.addListener(_syncHeaderToBody);
    _bodyHorizontalController.addListener(_syncBodyToHeader);
  }

  @override
  void dispose() {
    _headerHorizontalController.dispose();
    _bodyHorizontalController.dispose();
    _bodyVerticalController.dispose();
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

  double _safeOffset(double offset, ScrollController controller) {
    if (!controller.hasClients) return 0;
    return offset.clamp(0.0, controller.position.maxScrollExtent);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final viewportWidth = constraints.maxWidth.clamp(320.0, 9999.0);
        final resolvedColumns = _resolveColumns(viewportWidth);
        final tableWidth = resolvedColumns.fold<double>(
          0,
          (sum, column) => sum + column.width,
        );

        return Column(
          children: [
            SingleChildScrollView(
              controller: _headerHorizontalController,
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                width: tableWidth,
                child: _HeaderRow(columns: resolvedColumns),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                controller: _bodyHorizontalController,
                scrollDirection: Axis.horizontal,
                child: SizedBox(
                  width: tableWidth,
                  child: ListView.builder(
                    controller: _bodyVerticalController,
                    itemCount: widget.interpreters.length,
                    itemBuilder: (context, index) {
                      return _DataRow(
                        item: widget.interpreters[index],
                        index: index,
                        columns: resolvedColumns,
                      );
                    },
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  List<_ColumnSpec> _resolveColumns(double viewportWidth) {
    final baseWidth = _InterpretersTable.columns.fold<double>(
      0,
      (sum, column) => sum + column.width,
    );
    final extraWidth =
        viewportWidth > baseWidth ? viewportWidth - baseWidth : 0;
    final totalFlex = _InterpretersTable.columns.fold<double>(
      0,
      (sum, column) => sum + column.flexGrow,
    );

    return _InterpretersTable.columns
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
    return _ColumnSpec(title, width ?? this.width, flexGrow: flexGrow);
  }
}

class _HeaderRow extends StatelessWidget {
  final List<_ColumnSpec> columns;

  const _HeaderRow({required this.columns});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: _InterpretersTable.headerHeight,
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

class _DataRow extends StatelessWidget {
  final InterpreterListItem item;
  final int index;
  final List<_ColumnSpec> columns;

  const _DataRow({
    required this.item,
    required this.index,
    required this.columns,
  });

  @override
  Widget build(BuildContext context) {
    final values = [
      item.name,
      _username(item.username),
      _timeOfDay(item.connectionTime),
      item.status,
      _currentCall(item.currentCall),
      item.callsAttended.toString(),
      _duration(item.averageTime),
    ];

    return Container(
      height: _InterpretersTable.rowHeight,
      color: index.isEven ? const Color(0xFFF7FAFA) : Colors.white,
      child: Row(
        children: [
          for (var i = 0; i < columns.length; i++)
            _Cell(
              width: columns[i].width,
              child: switch (i) {
                3 => _StatusCell(status: item.status),
                _ => AppOverflowTooltipText(values[i], maxLines: 2),
              },
            ),
        ],
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

class _StatusCell extends StatelessWidget {
  final String status;

  const _StatusCell({required this.status});

  @override
  Widget build(BuildContext context) {
    final config = switch (status) {
      'available' => (label: 'Disponível', color: AppTheme.success),
      'in_call' => (label: 'Em chamada', color: AppTheme.danger),
      _ => (label: 'Offline', color: Colors.black38),
    };

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.circle, size: 12, color: config.color),
        const SizedBox(width: 6),
        Text(config.label),
      ],
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

String _username(String username) {
  final value = username.trim();
  if (value.isEmpty) return '-';
  return value.startsWith('@') ? value : '@$value';
}

String _timeOfDay(DateTime? value) {
  if (value == null) return '-';
  final hh = value.hour.toString().padLeft(2, '0');
  final mm = value.minute.toString().padLeft(2, '0');
  return '$hh:$mm';
}

String _duration(int seconds) {
  final safe = seconds < 0 ? 0 : seconds;
  final mm = (safe ~/ 60).toString().padLeft(2, '0');
  final ss = (safe % 60).toString().padLeft(2, '0');
  return '$mm:$ss';
}

String _currentCall(InterpreterCurrentCall? call) {
  if (call == null) return '-';
  final id = call.id.isEmpty ? '-' : call.id;
  final company = call.company.isEmpty ? 'N/A' : call.company;
  return '$id | $company | ${_duration(call.duration)}';
}
