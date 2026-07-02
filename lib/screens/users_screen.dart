import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../controllers/auth_controller.dart';
import '../controllers/users_controller.dart';
import '../core/config/app_theme.dart';
import '../core/exceptions/api_exception.dart';
import '../models/managed_user.dart';
import '../widgets/app_shell.dart';
import '../widgets/app_overflow_tooltip_text.dart';
import '../widgets/app_pagination_controls.dart';
import '../widgets/shimmer_loading.dart';

class UsersScreen extends StatefulWidget {
  final String slug;
  final String? companyId;

  const UsersScreen({super.key, required this.slug, this.companyId});

  @override
  State<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends State<UsersScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<UsersController>().load(
            slug: widget.slug,
            companyId: widget.companyId,
            resetPage: true,
          );
    });
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<UsersController>();
    final auth = context.watch<AuthController>();
    final isAdmin = auth.user?.isAdmin ?? false;

    return AppShell(
      title: 'Usuários',
      slug: widget.slug,
      currentRoute: 'users',
      actions: [
        IconButton(
          tooltip: 'Atualizar',
          onPressed: controller.loading
              ? null
              : () => controller.refresh(
                    slug: widget.slug,
                    companyId: widget.companyId,
                  ),
          icon: const Icon(Icons.refresh),
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _UsersToolbar(
            controller: controller,
            slug: widget.slug,
            companyId: widget.companyId,
            isAdmin: isAdmin,
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
                  if (controller.users.isEmpty && controller.loading)
                    const TableShimmer(rows: 12, columns: 7)
                  else if (controller.filteredUsers.isEmpty)
                    const Center(child: Text('Nenhum usuário encontrado.'))
                  else
                    _UsersTable(
                      users: controller.filteredUsers,
                      isAdmin: isAdmin,
                      onNotify: _openNotificationDialog,
                      onToggleBlock: _confirmToggleBlock,
                      onEdit: (user) =>
                          context.go('/users/${widget.slug}/${user.id}/edit'),
                      onDelete: _confirmDelete,
                    ),
                  if (controller.loading && controller.users.isNotEmpty)
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
            onFirst: () => controller.firstPage(
              slug: widget.slug,
              companyId: widget.companyId,
            ),
            onPrevious: () => controller.previousPage(
              slug: widget.slug,
              companyId: widget.companyId,
            ),
            onNext: () => controller.nextPage(
              slug: widget.slug,
              companyId: widget.companyId,
            ),
            onLast: () => controller.lastPage(
              slug: widget.slug,
              companyId: widget.companyId,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openNotificationDialog(ManagedUser user) async {
    final messageController = TextEditingController();

    final message = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Enviar notificação'),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Enviar notificação para ${user.name}.'),
                const SizedBox(height: 10),
                _UserSummary(user: user),
                const SizedBox(height: 16),
                TextField(
                  controller: messageController,
                  minLines: 4,
                  maxLines: 6,
                  decoration: const InputDecoration(
                    labelText: 'Mensagem',
                    alignLabelWithHint: true,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancelar'),
            ),
            FilledButton.icon(
              onPressed: () {
                final text = messageController.text.trim();
                if (text.isEmpty) return;
                Navigator.of(dialogContext).pop(text);
              },
              icon: const Icon(Icons.notifications_active_outlined),
              label: const Text('Enviar'),
            ),
          ],
        );
      },
    );

    messageController.dispose();

    if (message == null || message.isEmpty || !mounted) return;

    try {
      await context.read<UsersController>().sendNotification(
            user: user,
            message: message,
          );
      _showSnack('Notificação enviada para ${user.name}.');
    } on ApiException catch (error) {
      _showSnack(error.message, isError: true);
    } catch (_) {
      _showSnack('Erro ao enviar notificação.', isError: true);
    }
  }

  Future<void> _confirmToggleBlock(ManagedUser user) async {
    final action = user.isBlock ? 'desbloquear' : 'bloquear';
    final confirmed = await _confirm(
      title: user.isBlock ? 'Desbloquear usuário?' : 'Bloquear usuário?',
      message: 'Tem certeza que deseja $action ${user.name}?',
      confirmText: user.isBlock ? 'Desbloquear' : 'Bloquear',
    );

    if (!confirmed || !mounted) return;

    try {
      await context.read<UsersController>().toggleBlock(
            slug: widget.slug,
            user: user,
          );
      _showSnack(
        user.isBlock
            ? 'Usuário desbloqueado com sucesso.'
            : 'Usuário bloqueado com sucesso.',
      );
    } on ApiException catch (error) {
      _showSnack(error.message, isError: true);
    } catch (_) {
      _showSnack('Erro ao alterar bloqueio do usuário.', isError: true);
    }
  }

  Future<void> _confirmDelete(ManagedUser user) async {
    final confirmed = await _confirm(
      title: 'Excluir usuário?',
      message: 'Esta ação é irreversível. Deseja excluir ${user.name}?',
      confirmText: 'Excluir',
      danger: true,
    );

    if (!confirmed || !mounted) return;

    try {
      await context.read<UsersController>().deleteUser(
            slug: widget.slug,
            user: user,
          );
      _showSnack('Usuário excluído com sucesso.');
    } on ApiException catch (error) {
      _showSnack(error.message, isError: true);
    } catch (_) {
      _showSnack('Erro ao excluir usuário.', isError: true);
    }
  }

  Future<bool> _confirm({
    required String title,
    required String message,
    required String confirmText,
    bool danger = false,
  }) async {
    return await showDialog<bool>(
          context: context,
          builder: (dialogContext) {
            return AlertDialog(
              title: Text(title),
              content: Text(message),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: const Text('Cancelar'),
                ),
                FilledButton(
                  style: danger
                      ? FilledButton.styleFrom(backgroundColor: AppTheme.danger)
                      : null,
                  onPressed: () => Navigator.of(dialogContext).pop(true),
                  child: Text(confirmText),
                ),
              ],
            );
          },
        ) ??
        false;
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

class _UsersToolbar extends StatefulWidget {
  final UsersController controller;
  final String slug;
  final String? companyId;
  final bool isAdmin;

  const _UsersToolbar({
    required this.controller,
    required this.slug,
    required this.companyId,
    required this.isAdmin,
  });

  @override
  State<_UsersToolbar> createState() => _UsersToolbarState();
}

class _UsersToolbarState extends State<_UsersToolbar> {
  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _searchController =
        TextEditingController(text: widget.controller.searchTerm);
  }

  @override
  void didUpdateWidget(covariant _UsersToolbar oldWidget) {
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
      runSpacing: 10,
      children: [
        Text(
          '${controller.total} usuário(s)',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
        SizedBox(
          width: 360,
          child: TextField(
            controller: _searchController,
            enabled: !controller.loading && !isCompanyMode,
            onChanged: (value) => controller.setSearchTerm(
              slug: widget.slug,
              value: value,
              companyId: widget.companyId,
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
                          companyId: widget.companyId,
                        );
                      },
                      icon: const Icon(Icons.close),
                    ),
              labelText: 'Buscar por nome, e-mail ou perfil',
            ),
          ),
        ),
        if (widget.isAdmin)
          FilterChip(
            selected: controller.showBlockedOnly,
            label: const Text('Apenas bloqueados/desativados'),
            avatar: const Icon(Icons.lock_outline, size: 18),
            onSelected: controller.loading || isCompanyMode
                ? null
                : (value) => controller.setBlockedOnly(
                      slug: widget.slug,
                      value: value,
                      companyId: widget.companyId,
                    ),
          ),
        if (isCompanyMode)
          OutlinedButton.icon(
            onPressed: () => context.go('/companies/${widget.slug}'),
            icon: const Icon(Icons.arrow_back),
            label: const Text('Voltar'),
          ),
      ],
    );
  }
}

class _UsersTable extends StatefulWidget {
  static const rowHeight = 58.0;
  static const headerHeight = 48.0;
  static const actionsWidth = 180.0;
  static const columns = [
    _ColumnSpec('ID', 80),
    _ColumnSpec('Empresa', 130, flexGrow: 0.2),
    _ColumnSpec('Nome', 140, flexGrow: 0.25),
    _ColumnSpec('Apelido', 100, flexGrow: 0.1),
    _ColumnSpec('E-mail', 180, flexGrow: 0.3),
    _ColumnSpec('Perfil', 100, flexGrow: 0.15),
    _ColumnSpec('Status', 130),
  ];

  final List<ManagedUser> users;
  final bool isAdmin;
  final ValueChanged<ManagedUser> onNotify;
  final ValueChanged<ManagedUser> onToggleBlock;
  final ValueChanged<ManagedUser> onEdit;
  final ValueChanged<ManagedUser> onDelete;

  const _UsersTable({
    required this.users,
    required this.isAdmin,
    required this.onNotify,
    required this.onToggleBlock,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  State<_UsersTable> createState() => _UsersTableState();
}

class _UsersTableState extends State<_UsersTable> {
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

  List<_ColumnSpec> _resolveColumns(double viewportWidth) {
    final baseWidth = _UsersTable.columns.fold<double>(
      0,
      (sum, column) => sum + column.width,
    );
    final extraWidth =
        viewportWidth > baseWidth ? viewportWidth - baseWidth : 0;
    final totalFlex = _UsersTable.columns.fold<double>(
      0,
      (sum, column) => sum + column.flexGrow,
    );

    return _UsersTable.columns
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

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final reservedActionsWidth =
            widget.isAdmin ? _UsersTable.actionsWidth : 0.0;
        final leftViewportWidth =
            (constraints.maxWidth - reservedActionsWidth).clamp(280.0, 9999.0);
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
                if (widget.isAdmin)
                  SizedBox(
                    width: _UsersTable.actionsWidth,
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
                          itemCount: widget.users.length,
                          itemBuilder: (context, index) {
                            return _DataRow(
                              user: widget.users[index],
                              index: index,
                              columns: resolvedColumns,
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                  if (widget.isAdmin)
                    SizedBox(
                      width: _UsersTable.actionsWidth,
                      child: ListView.builder(
                        controller: _actionsVerticalController,
                        itemCount: widget.users.length,
                        itemBuilder: (context, index) {
                          return _ActionRow(
                            user: widget.users[index],
                            index: index,
                            onNotify: widget.onNotify,
                            onToggleBlock: widget.onToggleBlock,
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
      height: _UsersTable.headerHeight,
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
  @override
  Widget build(BuildContext context) {
    return Container(
      height: _UsersTable.headerHeight,
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
  final ManagedUser user;
  final int index;
  final List<_ColumnSpec> columns;

  const _DataRow({
    required this.user,
    required this.index,
    required this.columns,
  });

  @override
  Widget build(BuildContext context) {
    final values = [
      _shortId(user.id),
      _fallback(user.companyName),
      _fallback(user.name),
      _fallback(user.username),
      _fallback(user.email),
      _fallback(user.profileName),
      user.isBlock || user.isInative ? 'Bloqueado' : 'Ativo',
    ];

    return Container(
      height: _UsersTable.rowHeight,
      color: index.isEven ? const Color(0xFFF7FAFA) : Colors.white,
      child: Row(
        children: [
          for (var i = 0; i < columns.length; i++)
            _Cell(
              width: columns[i].width,
              child: i == 6
                  ? _StatusBadge(blocked: user.isBlock || user.isInative)
                  : AppOverflowTooltipText(
                      values[i],
                      tooltip: i == 0 ? user.id : values[i],
                    ),
            ),
        ],
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  final ManagedUser user;
  final int index;
  final ValueChanged<ManagedUser> onNotify;
  final ValueChanged<ManagedUser> onToggleBlock;
  final ValueChanged<ManagedUser> onEdit;
  final ValueChanged<ManagedUser> onDelete;

  const _ActionRow({
    required this.user,
    required this.index,
    required this.onNotify,
    required this.onToggleBlock,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: _UsersTable.rowHeight,
      color: index.isEven ? const Color(0xFFF7FAFA) : Colors.white,
      alignment: Alignment.center,
      child: Wrap(
        spacing: 4,
        children: [
          _ActionIcon(
            tooltip: 'Notificar',
            icon: Icons.notifications_active_outlined,
            color: AppTheme.success,
            onPressed: () => onNotify(user),
          ),
          _ActionIcon(
            tooltip: user.isBlock ? 'Desbloquear' : 'Bloquear',
            icon: user.isBlock ? Icons.lock_open_outlined : Icons.lock_outline,
            color: user.isBlock ? Colors.blue : Colors.orange.shade700,
            onPressed: () => onToggleBlock(user),
          ),
          _ActionIcon(
            tooltip: 'Editar',
            icon: Icons.edit_outlined,
            color: AppTheme.primary,
            onPressed: () => onEdit(user),
          ),
          _ActionIcon(
            tooltip: 'Excluir',
            icon: Icons.delete_outline,
            color: AppTheme.danger,
            onPressed: () => onDelete(user),
          ),
        ],
      ),
    );
  }
}

class _ActionIcon extends StatelessWidget {
  final String tooltip;
  final IconData icon;
  final Color color;
  final VoidCallback onPressed;

  const _ActionIcon({
    required this.tooltip,
    required this.icon,
    required this.color,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: IconButton.filledTonal(
        onPressed: onPressed,
        icon: Icon(icon, size: 18),
        color: color,
        constraints: const BoxConstraints.tightFor(width: 38, height: 38),
        padding: EdgeInsets.zero,
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
  final bool blocked;

  const _StatusBadge({required this.blocked});

  @override
  Widget build(BuildContext context) {
    final color = blocked ? AppTheme.danger : AppTheme.success;
    return Chip(
      label: Text(blocked ? 'Bloqueado' : 'Ativo'),
      backgroundColor: color.withValues(alpha: 0.12),
      labelStyle: TextStyle(color: color, fontWeight: FontWeight.w700),
      side: BorderSide(color: color.withValues(alpha: 0.2)),
    );
  }
}

class _UserSummary extends StatelessWidget {
  final ManagedUser user;

  const _UserSummary({required this.user});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Empresa: ${_fallback(user.companyName)}'),
          Text('Perfil: ${_fallback(user.profileName)}'),
          Text('E-mail: ${_fallback(user.email)}'),
        ],
      ),
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
