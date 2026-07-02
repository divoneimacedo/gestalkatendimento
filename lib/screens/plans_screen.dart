import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../controllers/plans_controller.dart';
import '../core/config/app_theme.dart';
import '../models/plan.dart';
import '../widgets/app_overflow_tooltip_text.dart';
import '../widgets/app_pagination_controls.dart';
import '../widgets/app_shell.dart';
import '../widgets/shimmer_loading.dart';

class PlansScreen extends StatefulWidget {
  final String slug;

  const PlansScreen({super.key, required this.slug});

  @override
  State<PlansScreen> createState() => _PlansScreenState();
}

class _PlansScreenState extends State<PlansScreen> {
  bool get _canManage => widget.slug == 'gestalk';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<PlansController>().load(
            slug: widget.slug,
            resetPage: true,
          );
    });
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<PlansController>();

    return AppShell(
      title: 'Planos',
      slug: widget.slug,
      currentRoute: 'plans',
      actions: [
        IconButton(
          tooltip: 'Atualizar',
          onPressed: controller.loading
              ? null
              : () => controller.refresh(slug: widget.slug),
          icon: const Icon(Icons.refresh),
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _PlansToolbar(
            controller: controller,
            slug: widget.slug,
            canManage: _canManage,
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
                  if (controller.plans.isEmpty && controller.loading)
                    const TableShimmer(rows: 12, columns: 6)
                  else if (controller.plans.isEmpty)
                    const Center(child: Text('Nenhum plano encontrado.'))
                  else
                    _PlansTable(
                      plans: controller.plans,
                      showActions: _canManage,
                      onEdit: (plan) => context.go(
                        '/plans/${widget.slug}/${plan.id}/edit',
                      ),
                      onDelete: _confirmDelete,
                    ),
                  if (controller.loading && controller.plans.isNotEmpty)
                    Positioned.fill(
                      child: ColoredBox(
                        color: Colors.white.withValues(alpha: 0.62),
                        child: const TableShimmer(rows: 8, columns: 6),
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

  Future<void> _confirmDelete(Plan plan) async {
    final approved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Excluir plano'),
          content: Text('Deseja realmente excluir o plano "${plan.name}"?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.danger,
              ),
              child: const Text('Excluir'),
            ),
          ],
        );
      },
    );

    if (approved != true || !mounted) return;

    try {
      await context.read<PlansController>().deletePlan(plan.id);
      if (!mounted) return;
      _showSnack('Plano excluído.');
      await context.read<PlansController>().load(slug: widget.slug);
    } catch (_) {
      if (!mounted) return;
      _showSnack('Erro ao excluir plano.', isError: true);
    }
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

class _PlansToolbar extends StatelessWidget {
  final PlansController controller;
  final String slug;
  final bool canManage;

  const _PlansToolbar({
    required this.controller,
    required this.slug,
    required this.canManage,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      runSpacing: 12,
      spacing: 12,
      children: [
        Text(
          '${controller.total} plano(s)',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
        if (canManage)
          FilledButton.icon(
            onPressed: () => context.go('/plans/$slug/create'),
            icon: const Icon(Icons.add),
            label: const Text('Plano'),
          ),
      ],
    );
  }
}

class _PlansTable extends StatefulWidget {
  static const rowHeight = 64.0;
  static const headerHeight = 54.0;
  static const actionsWidth = 108.0;
  static const columns = [
    _ColumnSpec('ID', 100),
    _ColumnSpec('Nome', 180, flexGrow: 0.6),
    _ColumnSpec('Valor', 90),
    _ColumnSpec('Duração (min)', 110),
    _ColumnSpec('Status', 120),
  ];

  final List<Plan> plans;
  final bool showActions;
  final ValueChanged<Plan> onEdit;
  final ValueChanged<Plan> onDelete;

  const _PlansTable({
    required this.plans,
    required this.showActions,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  State<_PlansTable> createState() => _PlansTableState();
}

class _PlansTableState extends State<_PlansTable> {
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
        final actionsWidth = widget.showActions ? _PlansTable.actionsWidth : 0;
        final leftViewportWidth =
            (constraints.maxWidth - actionsWidth).clamp(280.0, 9999.0);
        final resolvedColumns = _resolveColumns(leftViewportWidth);
        final tableWidth = resolvedColumns.fold<double>(
          0,
          (sum, column) => sum + column.width,
        );

        return Column(
          children: [
            Row(
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
                if (widget.showActions)
                  const SizedBox(
                    width: _PlansTable.actionsWidth,
                    child: _ActionHeader(),
                  ),
              ],
            ),
            Expanded(
              child: Row(
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
                          itemCount: widget.plans.length,
                          itemBuilder: (context, index) {
                            return _DataRow(
                              plan: widget.plans[index],
                              index: index,
                              columns: resolvedColumns,
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                  if (widget.showActions)
                    SizedBox(
                      width: _PlansTable.actionsWidth,
                      child: ListView.builder(
                        controller: _actionsVerticalController,
                        itemCount: widget.plans.length,
                        itemBuilder: (context, index) {
                          final plan = widget.plans[index];
                          return _ActionRow(
                            plan: plan,
                            index: index,
                            onEdit: widget.onEdit,
                            onDelete: widget.onDelete,
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
    final baseWidth = _PlansTable.columns.fold<double>(
      0,
      (sum, column) => sum + column.width,
    );
    final extraWidth =
        viewportWidth > baseWidth ? viewportWidth - baseWidth : 0;
    final totalFlex = _PlansTable.columns.fold<double>(
      0,
      (sum, column) => sum + column.flexGrow,
    );

    return _PlansTable.columns
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
      height: _PlansTable.headerHeight,
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
      height: _PlansTable.headerHeight,
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
  final Plan plan;
  final int index;
  final List<_ColumnSpec> columns;

  const _DataRow({
    required this.plan,
    required this.index,
    required this.columns,
  });

  @override
  Widget build(BuildContext context) {
    final values = [
      plan.id,
      _fallback(plan.name),
      _formatValue(plan.value),
      plan.duration.toString(),
      plan.isInative ? 'Desativado' : 'Ativo',
    ];

    return Container(
      height: _PlansTable.rowHeight,
      color: index.isEven ? const Color(0xFFF7FAFA) : Colors.white,
      child: Row(
        children: [
          for (var i = 0; i < columns.length; i++)
            _Cell(
              width: columns[i].width,
              child: switch (i) {
                4 => _StatusBadge(inactive: plan.isInative),
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
  final Plan plan;
  final int index;
  final ValueChanged<Plan> onEdit;
  final ValueChanged<Plan> onDelete;

  const _ActionRow({
    required this.plan,
    required this.index,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: _PlansTable.rowHeight,
      color: index.isEven ? const Color(0xFFF7FAFA) : Colors.white,
      alignment: Alignment.center,
      child: Wrap(
        spacing: 6,
        children: [
          Tooltip(
            message: 'Editar',
            child: IconButton.filled(
              onPressed: () => onEdit(plan),
              icon: const Icon(Icons.edit_outlined, size: 18),
              style: IconButton.styleFrom(
                backgroundColor: const Color(0xFF0F5592),
                foregroundColor: Colors.white,
                fixedSize: const Size(38, 38),
                padding: EdgeInsets.zero,
              ),
            ),
          ),
          Tooltip(
            message: 'Excluir',
            child: IconButton.filled(
              onPressed: () => onDelete(plan),
              icon: const Icon(Icons.close, size: 18),
              style: IconButton.styleFrom(
                backgroundColor: AppTheme.danger,
                foregroundColor: Colors.white,
                fixedSize: const Size(38, 38),
                padding: EdgeInsets.zero,
              ),
            ),
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

class _StatusBadge extends StatelessWidget {
  final bool inactive;

  const _StatusBadge({required this.inactive});

  @override
  Widget build(BuildContext context) {
    final color = inactive ? AppTheme.danger : AppTheme.success;
    return Chip(
      label: Text(inactive ? 'Desativado' : 'Ativo'),
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

String _formatValue(num value) {
  if (value % 1 == 0) return value.toInt().toString();
  return value.toStringAsFixed(2);
}
