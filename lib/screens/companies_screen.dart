import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../controllers/companies_controller.dart';
import '../core/config/app_theme.dart';
import '../models/company.dart';
import '../widgets/app_overflow_tooltip_text.dart';
import '../widgets/app_pagination_controls.dart';
import '../widgets/app_shell.dart';
import '../widgets/shimmer_loading.dart';

class CompaniesScreen extends StatefulWidget {
  final String slug;

  const CompaniesScreen({super.key, required this.slug});

  @override
  State<CompaniesScreen> createState() => _CompaniesScreenState();
}

class _CompaniesScreenState extends State<CompaniesScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CompaniesController>().load(
            slug: widget.slug,
            resetPage: true,
          );
    });
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<CompaniesController>();
    final canCreate = widget.slug == 'gestalk';

    return AppShell(
      title: 'Empresas',
      slug: widget.slug,
      currentRoute: 'companies',
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
          _CompaniesToolbar(
            controller: controller,
            slug: widget.slug,
            canCreate: canCreate,
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
                  if (controller.companies.isEmpty && controller.loading)
                    const TableShimmer(rows: 12, columns: 5)
                  else if (controller.companies.isEmpty)
                    const Center(child: Text('Nenhuma empresa encontrada.'))
                  else
                    _CompaniesTable(
                      companies: controller.companies,
                      showPlans: widget.slug == 'gestalk',
                      onPlans: (company) => context.go('/plans/${widget.slug}'),
                      onChannels: (company) => context.go(
                        '/channels/${widget.slug}/company/${company.id}',
                      ),
                      onUsers: (company) => context.go(
                        '/users/${widget.slug}/company/${company.id}',
                      ),
                      onEdit: (company) => context.go(
                        '/companies/${widget.slug}/${company.id}/edit',
                      ),
                    ),
                  if (controller.loading && controller.companies.isNotEmpty)
                    Positioned.fill(
                      child: ColoredBox(
                        color: Colors.white.withValues(alpha: 0.62),
                        child: const TableShimmer(rows: 8, columns: 5),
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

class _CompaniesToolbar extends StatefulWidget {
  final CompaniesController controller;
  final String slug;
  final bool canCreate;

  const _CompaniesToolbar({
    required this.controller,
    required this.slug,
    required this.canCreate,
  });

  @override
  State<_CompaniesToolbar> createState() => _CompaniesToolbarState();
}

class _CompaniesToolbarState extends State<_CompaniesToolbar> {
  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _searchController =
        TextEditingController(text: widget.controller.searchTerm);
  }

  @override
  void didUpdateWidget(covariant _CompaniesToolbar oldWidget) {
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
          '${controller.total} empresa(s)',
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
                enabled: !controller.loading && widget.slug == 'gestalk',
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
                  labelText: 'Pesquisar por nome ou slug',
                ),
              ),
            ),
            if (widget.canCreate)
              FilledButton.icon(
                onPressed: () => context.go('/companies/${widget.slug}/create'),
                icon: const Icon(Icons.add),
                label: const Text('Empresa'),
              ),
          ],
        ),
      ],
    );
  }
}

class _CompaniesTable extends StatefulWidget {
  static const rowHeight = 64.0;
  static const headerHeight = 54.0;
  static const actionsWidth = 178.0;
  static const columns = [
    _ColumnSpec('ID', 100),
    _ColumnSpec('Nome', 260, flexGrow: 1),
    _ColumnSpec('Logo', 90),
    _ColumnSpec('Status', 120),
  ];

  final List<Company> companies;
  final bool showPlans;
  final ValueChanged<Company> onPlans;
  final ValueChanged<Company> onChannels;
  final ValueChanged<Company> onUsers;
  final ValueChanged<Company> onEdit;

  const _CompaniesTable({
    required this.companies,
    required this.showPlans,
    required this.onPlans,
    required this.onChannels,
    required this.onUsers,
    required this.onEdit,
  });

  @override
  State<_CompaniesTable> createState() => _CompaniesTableState();
}

class _CompaniesTableState extends State<_CompaniesTable> {
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
            (constraints.maxWidth - _CompaniesTable.actionsWidth)
                .clamp(280.0, 9999.0);
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
                const SizedBox(
                  width: _CompaniesTable.actionsWidth,
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
                          itemCount: widget.companies.length,
                          itemBuilder: (context, index) {
                            return _DataRow(
                              company: widget.companies[index],
                              index: index,
                              columns: resolvedColumns,
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: _CompaniesTable.actionsWidth,
                    child: ListView.builder(
                      controller: _actionsVerticalController,
                      itemCount: widget.companies.length,
                      itemBuilder: (context, index) {
                        final company = widget.companies[index];
                        return _ActionRow(
                          company: company,
                          index: index,
                          showPlans: widget.showPlans,
                          onPlans: widget.onPlans,
                          onChannels: widget.onChannels,
                          onUsers: widget.onUsers,
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
    final baseWidth = _CompaniesTable.columns.fold<double>(
      0,
      (sum, column) => sum + column.width,
    );
    final extraWidth =
        viewportWidth > baseWidth ? viewportWidth - baseWidth : 0;

    return _CompaniesTable.columns
        .map(
          (column) => column.copyWith(
            width: column.width + (extraWidth * column.flexGrow),
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
      height: _CompaniesTable.headerHeight,
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
      height: _CompaniesTable.headerHeight,
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
  final Company company;
  final int index;
  final List<_ColumnSpec> columns;

  const _DataRow({
    required this.company,
    required this.index,
    required this.columns,
  });

  @override
  Widget build(BuildContext context) {
    final values = [
      company.id,
      _fallback(company.name),
      company.logo,
      company.isInative ? 'Desativado' : 'Ativo',
    ];

    return Container(
      height: _CompaniesTable.rowHeight,
      color: index.isEven ? const Color(0xFFF7FAFA) : Colors.white,
      child: Row(
        children: [
          for (var i = 0; i < columns.length; i++)
            _Cell(
              width: columns[i].width,
              child: switch (i) {
                2 => _LogoCell(url: company.logo),
                3 => _StatusBadge(inactive: company.isInative),
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

class _LogoCell extends StatelessWidget {
  final String url;

  const _LogoCell({required this.url});

  @override
  Widget build(BuildContext context) {
    if (url.isEmpty) {
      return const Text('-');
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: Image.network(
        url,
        width: 42,
        height: 42,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => const Text('-'),
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  final Company company;
  final int index;
  final bool showPlans;
  final ValueChanged<Company> onPlans;
  final ValueChanged<Company> onChannels;
  final ValueChanged<Company> onUsers;
  final ValueChanged<Company> onEdit;

  const _ActionRow({
    required this.company,
    required this.index,
    required this.showPlans,
    required this.onPlans,
    required this.onChannels,
    required this.onUsers,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: _CompaniesTable.rowHeight,
      color: index.isEven ? const Color(0xFFF7FAFA) : Colors.white,
      alignment: Alignment.center,
      child: Wrap(
        spacing: 5,
        children: [
          if (showPlans)
            _ActionIcon(
              tooltip: 'Planos',
              icon: Icons.dashboard_outlined,
              onPressed: () => onPlans(company),
            ),
          _ActionIcon(
            tooltip: 'Canais',
            icon: Icons.inbox_outlined,
            onPressed: () => onChannels(company),
          ),
          _ActionIcon(
            tooltip: 'Usuários',
            icon: Icons.group_outlined,
            onPressed: () => onUsers(company),
          ),
          _ActionIcon(
            tooltip: 'Editar',
            icon: Icons.edit_outlined,
            onPressed: () => onEdit(company),
          ),
        ],
      ),
    );
  }
}

class _ActionIcon extends StatelessWidget {
  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;

  const _ActionIcon({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: IconButton.filled(
        onPressed: onPressed,
        icon: Icon(icon, size: 18),
        style: IconButton.styleFrom(
          backgroundColor: const Color(0xFF0F5592),
          foregroundColor: Colors.white,
          fixedSize: const Size(38, 38),
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
