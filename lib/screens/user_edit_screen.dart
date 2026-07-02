import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../controllers/users_controller.dart';
import '../core/config/app_theme.dart';
import '../core/exceptions/api_exception.dart';
import '../models/app_notification.dart';
import '../models/managed_user.dart';
import '../services/users_service.dart';
import '../widgets/app_shell.dart';
import '../widgets/app_overflow_tooltip_text.dart';

class UserEditScreen extends StatefulWidget {
  final String slug;
  final String userId;
  final String? backLocation;

  const UserEditScreen({
    super.key,
    required this.slug,
    required this.userId,
    this.backLocation,
  });

  @override
  State<UserEditScreen> createState() => _UserEditScreenState();
}

class _UserEditScreenState extends State<UserEditScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _usernameController = TextEditingController();
  final _phoneController = TextEditingController();

  ManagedUser? _user;
  List<UserEditOption> _companies = [];
  List<UserEditOption> _profiles = [];
  List<AppNotification> _notifications = [];
  String _selectedCompanyId = '';
  String _selectedProfileId = '';
  String _notificationTypeFilter = 'ALL';
  String _notificationStatusFilter = 'ALL';
  bool _loading = true;
  bool _notificationsLoading = false;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadUser());
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _usernameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _loadUser() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final usersController = context.read<UsersController>();
      final cachedUser = _findCachedUser(usersController.users);
      final user = cachedUser ??
          await usersController.usersService.fetchUserById(widget.userId);
      final companies = await _loadCompanies(user);
      final profiles = await _loadProfiles(user);
      final notifications = await usersController.usersService
          .fetchUserNotifications(userId: widget.userId);

      _fillForm(user);
      setState(() {
        _user = user;
        _companies = companies;
        _profiles = profiles;
        _notifications = notifications.notifications;
        _selectedCompanyId = user.companyId;
        _selectedProfileId = user.profileId;
      });
    } on ApiException catch (error) {
      setState(() => _error = error.message);
    } catch (_) {
      setState(() => _error = 'Erro ao carregar usuário.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _fillForm(ManagedUser user) {
    _nameController.text = user.name;
    _emailController.text = user.email;
    _usernameController.text = user.username;
    _phoneController.text = user.phoneNumber;
  }

  Future<List<UserEditOption>> _loadCompanies(ManagedUser user) async {
    try {
      return _withFallbackOption(
        await context.read<UsersController>().usersService.fetchCompanies(),
        UserEditOption(
          id: user.companyId,
          name: _fallback(user.companyName, fallback: user.companyId),
        ),
      );
    } catch (_) {
      return _withFallbackOption(
        const [],
        UserEditOption(
          id: user.companyId,
          name: _fallback(user.companyName, fallback: user.companyId),
        ),
      );
    }
  }

  Future<List<UserEditOption>> _loadProfiles(ManagedUser user) async {
    try {
      return _withFallbackOption(
        await context.read<UsersController>().usersService.fetchProfiles(),
        UserEditOption(
          id: user.profileId,
          name: _fallback(user.profileName, fallback: user.profileId),
        ),
      );
    } catch (_) {
      return _withFallbackOption(
        const [],
        UserEditOption(
          id: user.profileId,
          name: _fallback(user.profileName, fallback: user.profileId),
        ),
      );
    }
  }

  List<UserEditOption> _withFallbackOption(
    List<UserEditOption> options,
    UserEditOption fallback,
  ) {
    if (fallback.id.isEmpty) return options;
    if (options.any((option) => option.id == fallback.id)) return options;

    return [fallback, ...options];
  }

  ManagedUser? _findCachedUser(List<ManagedUser> users) {
    for (final user in users) {
      if (user.id == widget.userId) return user;
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    return AppShell(
      title: 'Editar usuário',
      slug: widget.slug,
      currentRoute: 'users',
      actions: [
        IconButton(
          tooltip: 'Atualizar',
          onPressed: _loading || _saving ? null : _loadUser,
          icon: const Icon(Icons.refresh),
        ),
      ],
      child: Card(
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? _ErrorState(message: _error!, onRetry: _loadUser)
                : DefaultTabController(
                    length: 2,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _Header(
                          user: _user,
                          onBack: () => context.go(
                            widget.backLocation ?? '/users/${widget.slug}',
                          ),
                        ),
                        const TabBar(
                          isScrollable: true,
                          labelColor: Colors.blue,
                          unselectedLabelColor: Colors.grey,
                          indicatorColor: Colors.blue,
                          tabs: [
                            Tab(
                              icon: Icon(Icons.person_outline),
                              text: 'DADOS DO USUÁRIO',
                            ),
                            Tab(
                              icon: Icon(Icons.notifications_none),
                              text: 'NOTIFICAÇÕES',
                            ),
                          ],
                        ),
                        Expanded(
                          child: TabBarView(
                            children: [
                              _buildDataTab(),
                              _buildNotificationsTab(),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
      ),
    );
  }

  Widget _buildDataTab() {
    final user = _user;
    if (user == null) return const SizedBox.shrink();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < 760;
                final fields = [
                  DropdownButtonFormField<String>(
                    initialValue:
                        _selectedCompanyId.isEmpty ? null : _selectedCompanyId,
                    decoration: const InputDecoration(labelText: 'Empresa'),
                    items: _companies
                        .map((company) => DropdownMenuItem(
                              value: company.id,
                              child: Text(company.name),
                            ))
                        .toList(),
                    onChanged: _saving
                        ? null
                        : (value) {
                            if (value == null) return;
                            setState(() => _selectedCompanyId = value);
                          },
                    validator: _required('Informe a empresa.'),
                  ),
                  DropdownButtonFormField<String>(
                    initialValue:
                        _selectedProfileId.isEmpty ? null : _selectedProfileId,
                    decoration: const InputDecoration(labelText: 'Função'),
                    items: _profiles
                        .map((profile) => DropdownMenuItem(
                              value: profile.id,
                              child: Text(profile.name),
                            ))
                        .toList(),
                    onChanged: _saving
                        ? null
                        : (value) {
                            if (value == null) return;
                            setState(() => _selectedProfileId = value);
                          },
                    validator: _required('Informe a função.'),
                  ),
                  TextFormField(
                    controller: _nameController,
                    enabled: !_saving,
                    decoration: const InputDecoration(
                      labelText: 'Nome do usuário',
                    ),
                    validator: _required('Informe o nome.'),
                  ),
                  TextFormField(
                    controller: _emailController,
                    enabled: !_saving,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(labelText: 'E-mail'),
                    validator: _emailValidator,
                  ),
                  TextFormField(
                    controller: _usernameController,
                    enabled: !_saving,
                    decoration: const InputDecoration(
                      labelText: 'Apelido (login)',
                    ),
                    validator: _required('Informe o apelido.'),
                  ),
                  TextFormField(
                    controller: _phoneController,
                    enabled: !_saving,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'Número de Telefone (Intérprete)',
                      helperText:
                          'Necessário para realizar chamadas telefônicas. Formato: +55DDD9XXXXXXXX',
                    ),
                  ),
                ];

                if (compact) {
                  return Column(
                    children: [
                      for (final field in fields) ...[
                        field,
                        const SizedBox(height: 16),
                      ],
                    ],
                  );
                }

                return Column(
                  children: [
                    for (var i = 0; i < fields.length; i += 2) ...[
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: fields[i]),
                          const SizedBox(width: 20),
                          Expanded(child: fields[i + 1]),
                        ],
                      ),
                      const SizedBox(height: 18),
                    ],
                  ],
                );
              },
            ),
            const Text(
              'A senha poderá ser alterada pela tela de perfil do próprio usuário.',
              style: TextStyle(color: Colors.black54),
            ),
            const SizedBox(height: 28),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.success,
                  foregroundColor: Colors.white,
                ),
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save_outlined),
                label: const Text('SALVAR'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationsTab() {
    final user = _user;
    if (user == null) return const SizedBox.shrink();

    final filteredNotifications = _notifications.where((notification) {
      final typeMatches = _notificationTypeFilter == 'ALL' ||
          notification.type == _notificationTypeFilter;
      final statusMatches = _notificationStatusFilter == 'ALL' ||
          notification.status == _notificationStatusFilter;
      return typeMatches && statusMatches;
    }).toList();

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.start,
            runSpacing: 16,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Notificações de ${user.name}',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Histórico completo de notificações',
                    style: TextStyle(color: Colors.black54),
                  ),
                ],
              ),
              IconButton.filledTonal(
                tooltip: 'Atualizar notificações',
                onPressed: _notificationsLoading ? null : _loadNotifications,
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.end,
            runSpacing: 16,
            spacing: 16,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Filtrar por Tipo:',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _FilterChipButton(
                        label: 'Todos',
                        selected: _notificationTypeFilter == 'ALL',
                        onPressed: () {
                          setState(() => _notificationTypeFilter = 'ALL');
                        },
                      ),
                      for (final type in _notificationTypeLabels.entries)
                        _FilterChipButton(
                          label: type.value,
                          selected: _notificationTypeFilter == type.key,
                          onPressed: () {
                            setState(() => _notificationTypeFilter = type.key);
                          },
                        ),
                    ],
                  ),
                ],
              ),
              SizedBox(
                width: 220,
                child: DropdownButtonFormField<String>(
                  initialValue: _notificationStatusFilter,
                  decoration: const InputDecoration(
                    labelText: 'Filtrar por Status:',
                    filled: true,
                    fillColor: Color(0xFFF4F6F8),
                  ),
                  items: [
                    const DropdownMenuItem(value: 'ALL', child: Text('Todos')),
                    for (final status in _notificationStatusLabels.entries)
                      DropdownMenuItem(
                        value: status.key,
                        child: Text(status.value),
                      ),
                  ],
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() => _notificationStatusFilter = value);
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: _notificationsLoading
                ? const Center(child: CircularProgressIndicator())
                : _NotificationsTable(
                    notifications: filteredNotifications,
                    onMessage: _openNotificationMessage,
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _loadNotifications() async {
    setState(() => _notificationsLoading = true);

    try {
      final result = await context
          .read<UsersController>()
          .usersService
          .fetchUserNotifications(userId: widget.userId);

      setState(() => _notifications = result.notifications);
    } on ApiException catch (error) {
      _showSnack(error.message, isError: true);
    } catch (_) {
      _showSnack('Erro ao buscar notificações.', isError: true);
    } finally {
      if (mounted) setState(() => _notificationsLoading = false);
    }
  }

  Future<void> _openNotificationMessage(AppNotification notification) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(notification.title),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(notification.message.isEmpty ? '-' : notification.message),
                if (notification.videoUrl?.isNotEmpty == true) ...[
                  const SizedBox(height: 12),
                  SelectableText('Vídeo: ${notification.videoUrl}'),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Fechar'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _save() async {
    final form = _formKey.currentState;
    final user = _user;
    if (form == null || user == null || !form.validate()) return;

    setState(() => _saving = true);

    try {
      final edited = user.copyWith(
        name: _nameController.text.trim(),
        username: _usernameController.text.trim(),
        email: _emailController.text.trim(),
        companyId: _selectedCompanyId,
        profileId: _selectedProfileId,
        companyName: _optionName(_companies, _selectedCompanyId),
        profileName: _optionName(_profiles, _selectedProfileId),
        phoneNumber: _phoneController.text.trim(),
      );

      await context.read<UsersController>().updateUser(
            slug: widget.slug,
            user: edited,
          );

      if (!mounted) return;
      setState(() => _user = edited);
      _showSnack('Usuário atualizado com sucesso.');
    } on ApiException catch (error) {
      _showSnack(error.message, isError: true);
    } catch (_) {
      _showSnack('Erro ao atualizar usuário.', isError: true);
    } finally {
      if (mounted) setState(() => _saving = false);
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

String _optionName(List<UserEditOption> options, String id) {
  for (final option in options) {
    if (option.id == id) return option.name;
  }

  return id;
}

class _Header extends StatelessWidget {
  final ManagedUser? user;
  final VoidCallback onBack;

  const _Header({
    required this.user,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFF7F8FA),
      padding: const EdgeInsets.fromLTRB(24, 22, 24, 22),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        runSpacing: 12,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Editar usuário',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
              if (user != null) ...[
                const SizedBox(height: 4),
                Text(
                  '${user!.name} | ${_fallback(user!.email)}',
                  style: const TextStyle(color: Colors.black54),
                ),
              ],
            ],
          ),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.secondary,
              foregroundColor: Colors.white,
            ),
            onPressed: onBack,
            icon: const Icon(Icons.arrow_back),
            label: const Text('VOLTAR'),
          ),
        ],
      ),
    );
  }
}

class _FilterChipButton extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onPressed;

  const _FilterChipButton({
    required this.label,
    required this.selected,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      label: Text(label),
      onPressed: onPressed,
      backgroundColor: selected ? Colors.blue : const Color(0xFFE5E7EB),
      labelStyle: TextStyle(
        color: selected ? Colors.white : const Color(0xFF374151),
        fontWeight: FontWeight.w800,
      ),
      side: BorderSide.none,
    );
  }
}

class _NotificationsTable extends StatelessWidget {
  final List<AppNotification> notifications;
  final ValueChanged<AppNotification> onMessage;

  const _NotificationsTable({
    required this.notifications,
    required this.onMessage,
  });

  @override
  Widget build(BuildContext context) {
    if (notifications.isEmpty) {
      return Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0xFFD1D5DB)),
        ),
        child: const Text('Nenhuma notificação encontrada'),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SizedBox(
        width: 1120,
        child: Column(
          children: [
            const _NotificationHeaderRow(),
            Expanded(
              child: ListView.builder(
                itemCount: notifications.length,
                itemBuilder: (context, index) {
                  return _NotificationRow(
                    notification: notifications[index],
                    index: index,
                    onMessage: onMessage,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NotificationHeaderRow extends StatelessWidget {
  const _NotificationHeaderRow();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      color: const Color(0xFFF3F4F6),
      child: const Row(
        children: [
          _NotificationCell(width: 140, child: _HeaderText('Tipo')),
          _NotificationCell(width: 170, child: _HeaderText('Título')),
          _NotificationCell(width: 360, child: _HeaderText('Mensagem')),
          _NotificationCell(width: 140, child: _HeaderText('Status')),
          _NotificationCell(width: 210, child: _HeaderText('Data/Hora')),
          _NotificationCell(width: 100, child: _HeaderText('Ações')),
        ],
      ),
    );
  }
}

class _NotificationRow extends StatelessWidget {
  final AppNotification notification;
  final int index;
  final ValueChanged<AppNotification> onMessage;

  const _NotificationRow({
    required this.notification,
    required this.index,
    required this.onMessage,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 58,
      color: index.isEven ? const Color(0xFFF9FAFB) : Colors.white,
      child: Row(
        children: [
          _NotificationCell(
            width: 140,
            child: Row(
              children: [
                Icon(_notificationIcon(notification.type), size: 18),
                const SizedBox(width: 8),
                Text(_notificationTypeLabel(notification.type)),
              ],
            ),
          ),
          _NotificationCell(
            width: 170,
            child: AppOverflowTooltipText(
              _fallback(notification.title),
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
          _NotificationCell(
            width: 360,
            child: AppOverflowTooltipText(
              notification.message.isEmpty ? '-' : notification.message,
              style: const TextStyle(color: Colors.black54),
            ),
          ),
          _NotificationCell(
            width: 140,
            child: _NotificationStatusBadge(status: notification.status),
          ),
          _NotificationCell(
            width: 210,
            child: Text(_formatDate(notification.createdAt)),
          ),
          _NotificationCell(
            width: 100,
            child: IconButton.filledTonal(
              tooltip: 'Ver mensagem completa',
              onPressed: () => onMessage(notification),
              icon: const Icon(Icons.chat_bubble_outline, size: 18),
              color: Colors.blueGrey,
            ),
          ),
        ],
      ),
    );
  }
}

class _NotificationCell extends StatelessWidget {
  final double width;
  final Widget child;

  const _NotificationCell({
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

class _HeaderText extends StatelessWidget {
  final String text;

  const _HeaderText(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(text, style: const TextStyle(fontWeight: FontWeight.w800));
  }
}

class _NotificationStatusBadge extends StatelessWidget {
  final String status;

  const _NotificationStatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final color = _notificationStatusColor(status);

    return Chip(
      label: Text(_notificationStatusLabel(status)),
      backgroundColor: color.withValues(alpha: 0.14),
      labelStyle: TextStyle(color: color, fontWeight: FontWeight.w800),
      side: BorderSide.none,
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
            const Icon(Icons.error_outline, color: AppTheme.danger, size: 42),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppTheme.danger),
            ),
            const SizedBox(height: 16),
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

const _notificationTypeLabels = {
  'PUSH': 'Push',
  'CALL_INVITE': 'Convite de Chamada',
  'VOICEMAIL': 'Caixa Postal',
};

const _notificationStatusLabels = {
  'SENT': 'Enviado',
  'DELIVERED': 'Entregue',
  'READ': 'Lido',
  'FAILED': 'Falhou',
};

IconData _notificationIcon(String type) {
  return switch (type) {
    'CALL_INVITE' => Icons.phone_outlined,
    'VOICEMAIL' => Icons.voicemail_outlined,
    _ => Icons.notifications_none,
  };
}

String _notificationTypeLabel(String type) {
  return _notificationTypeLabels[type] ?? (type.isEmpty ? '-' : type);
}

String _notificationStatusLabel(String status) {
  return _notificationStatusLabels[status] ?? (status.isEmpty ? '-' : status);
}

Color _notificationStatusColor(String status) {
  return switch (status) {
    'READ' => AppTheme.success,
    'DELIVERED' => Colors.orange.shade700,
    'FAILED' => AppTheme.danger,
    _ => Colors.blue,
  };
}

String _formatDate(DateTime? date) {
  if (date == null) return '-';
  return DateFormat('dd/MM/yyyy HH:mm').format(date.toLocal());
}

String? Function(String?) _required(String message) {
  return (value) {
    if (value == null || value.trim().isEmpty) return message;
    return null;
  };
}

String? _emailValidator(String? value) {
  final text = value?.trim() ?? '';
  if (text.isEmpty) return 'Informe o e-mail.';
  final valid = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(text);
  if (!valid) return 'Informe um e-mail válido.';
  return null;
}

String _fallback(String? value, {String fallback = '-'}) {
  final text = value?.trim() ?? '';
  return text.isEmpty ? fallback : text;
}
