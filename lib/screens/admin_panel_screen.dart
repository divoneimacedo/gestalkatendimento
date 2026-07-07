import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../controllers/companies_controller.dart';
import '../core/config/app_theme.dart';
import '../core/exceptions/api_exception.dart';
import '../models/admin_dashboard_stats.dart';
import '../models/admin_profile_type.dart';
import '../models/company.dart';
import '../models/managed_user.dart';
import '../models/service_type.dart';
import '../services/admin_service.dart';
import '../services/companies_service.dart';
import '../services/users_service.dart';
import '../widgets/app_overflow_tooltip_text.dart';
import '../widgets/app_pagination_controls.dart';
import '../widgets/app_shell.dart';
import '../widgets/shimmer_loading.dart';

class AdminPanelScreen extends StatefulWidget {
  final String slug;
  final String initialTab;

  const AdminPanelScreen({
    super.key,
    required this.slug,
    required this.initialTab,
  });

  @override
  State<AdminPanelScreen> createState() => _AdminPanelScreenState();
}

class _AdminPanelScreenState extends State<AdminPanelScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  late final AdminService _adminService;
  late final UsersService _usersService;
  late final CompaniesService _companiesService;

  AdminDashboardStats? _stats;
  List<ManagedUser> _users = [];
  List<AdminProfileType> _profiles = [];
  List<ServiceType> _serviceTypes = [];
  List<Company> _companies = [];
  Map<String, String> _companyNames = {};

  bool _loadingDashboard = true;
  bool _loadingUsers = true;
  bool _loadingProfiles = true;
  bool _loadingQueues = true;
  String? _dashboardError;
  String? _usersError;
  String? _profilesError;
  String? _queuesError;

  int _usersPage = 1;
  int _usersTotal = 0;
  int _usersTotalPages = 1;
  int _queuesPage = 1;
  int _queuesTotal = 0;
  int _queuesTotalPages = 1;
  static const _limit = 20;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 4,
      vsync: this,
      initialIndex: _tabIndex(widget.initialTab),
    );
    _tabController.addListener(_updateQueryTab);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _adminService = context.read<AdminService>();
      _usersService = context.read<UsersService>();
      _companiesService = context.read<CompaniesController>().companiesService;
      _loadCurrentTab();
    });
  }

  @override
  void didUpdateWidget(covariant AdminPanelScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    final nextIndex = _tabIndex(widget.initialTab);
    if (nextIndex != _tabController.index) {
      _tabController.index = nextIndex;
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadCurrentTab());
    }
  }

  @override
  void dispose() {
    _tabController.removeListener(_updateQueryTab);
    _tabController.dispose();
    super.dispose();
  }

  int _tabIndex(String tab) {
    return switch (tab) {
      'users' => 1,
      'profiles' => 2,
      'queues' => 3,
      _ => 0,
    };
  }

  String _tabName(int index) {
    return switch (index) {
      1 => 'users',
      2 => 'profiles',
      3 => 'queues',
      _ => 'dashboard',
    };
  }

  void _updateQueryTab() {
    if (_tabController.indexIsChanging) return;
    final tab = _tabName(_tabController.index);
    final location = '/admin/${widget.slug}?tab=$tab';
    if (GoRouterState.of(context).uri.toString() != location) {
      context.go(location);
    }
    _loadCurrentTab();
  }

  void _loadCurrentTab() {
    switch (_tabController.index) {
      case 1:
        _loadUsers();
      case 2:
        _loadProfiles();
      case 3:
        _loadQueues();
      default:
        _loadDashboard();
    }
  }

  Future<void> _loadDashboard() async {
    setState(() {
      _loadingDashboard = true;
      _dashboardError = null;
    });
    try {
      final stats = await _adminService.fetchDashboardStats();
      if (mounted) setState(() => _stats = stats);
    } on ApiException catch (error) {
      if (mounted) setState(() => _dashboardError = error.message);
    } catch (_) {
      if (mounted) setState(() => _dashboardError = 'Erro ao carregar painel.');
    } finally {
      if (mounted) setState(() => _loadingDashboard = false);
    }
  }

  Future<void> _loadUsers() async {
    setState(() {
      _loadingUsers = true;
      _usersError = null;
      _users = [];
    });
    try {
      final result = await _usersService.fetchUsers(
        slug: widget.slug,
        blockedOnly: false,
        page: _usersPage,
        limit: _limit,
        search: '',
      );
      if (mounted) {
        setState(() {
          _users = result.users;
          _usersTotal = result.total;
          _usersPage = result.page;
          _usersTotalPages = result.totalPages == 0 ? 1 : result.totalPages;
        });
      }
    } on ApiException catch (error) {
      if (mounted) setState(() => _usersError = error.message);
    } catch (_) {
      if (mounted) setState(() => _usersError = 'Erro ao carregar usuários.');
    } finally {
      if (mounted) setState(() => _loadingUsers = false);
    }
  }

  Future<void> _loadProfiles() async {
    setState(() {
      _loadingProfiles = true;
      _profilesError = null;
      _profiles = [];
    });
    try {
      final profiles = await _adminService.fetchProfiles();
      if (mounted) setState(() => _profiles = profiles);
    } on ApiException catch (error) {
      if (mounted) setState(() => _profilesError = error.message);
    } catch (_) {
      if (mounted) setState(() => _profilesError = 'Erro ao carregar perfis.');
    } finally {
      if (mounted) setState(() => _loadingProfiles = false);
    }
  }

  Future<void> _loadQueues() async {
    setState(() {
      _loadingQueues = true;
      _queuesError = null;
      _serviceTypes = [];
    });
    try {
      final companiesResult = _companies.isEmpty
          ? await _companiesService.fetchCompanies(
              slug: widget.slug,
              page: 1,
              limit: 500,
              search: '',
            )
          : null;
      final result = await _adminService.fetchServiceTypes(
        page: _queuesPage,
        limit: _limit,
      );
      final companies = companiesResult?.companies ?? _companies;
      final companyNames = {
        for (final company in companies) company.id: company.name,
      };
      if (mounted) {
        setState(() {
          _companies = companies;
          _companyNames = companyNames;
          _serviceTypes = result.serviceTypes;
          _queuesTotal = result.total;
          _queuesPage = result.page;
          _queuesTotalPages = result.totalPages == 0 ? 1 : result.totalPages;
        });
      }
    } on ApiException catch (error) {
      if (mounted) setState(() => _queuesError = error.message);
    } catch (_) {
      if (mounted) setState(() => _queuesError = 'Erro ao carregar filas.');
    } finally {
      if (mounted) setState(() => _loadingQueues = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppShell(
      title: 'Painel Admin',
      slug: widget.slug,
      currentRoute: 'admin',
      actions: [
        IconButton(
          tooltip: 'Atualizar',
          onPressed: _loadCurrentTab,
          icon: const Icon(Icons.refresh),
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _AdminTabs(controller: _tabController),
          const SizedBox(height: 16),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _dashboardTab(),
                _usersTab(),
                _profilesTab(),
                _queuesTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _dashboardTab() {
    if (_loadingDashboard && _stats == null) {
      return const _AdminCard(child: TableShimmer(rows: 6, columns: 3));
    }
    if (_dashboardError != null) {
      return _ErrorState(message: _dashboardError!, onRetry: _loadDashboard);
    }

    final stats = _stats ??
        const AdminDashboardStats(
          totalCalls: 0,
          callsInProgress: 0,
          callsWaiting: 0,
          totalCompanies: 0,
          totalUsers: 0,
          totalChannels: 0,
        );

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Dashboard',
            style: Theme.of(context)
                .textTheme
                .headlineSmall
                ?.copyWith(color: Colors.white, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 18,
            runSpacing: 18,
            children: [
              _MetricCard(
                title: 'Total de Atendimentos',
                value: stats.totalCalls.toString(),
                icon: Icons.call_outlined,
                color: Colors.blue,
              ),
              _MetricCard(
                title: 'Em Andamento',
                value: stats.callsInProgress.toString(),
                icon: Icons.monitor_heart_outlined,
                color: Colors.green,
              ),
              _MetricCard(
                title: 'Aguardando',
                value: stats.callsWaiting.toString(),
                icon: Icons.schedule_outlined,
                color: Colors.amber.shade700,
              ),
              _MetricCard(
                title: 'Empresas Ativas',
                value: stats.totalCompanies.toString(),
                icon: Icons.business_outlined,
                color: Colors.purple,
              ),
              _MetricCard(
                title: 'Usuários Ativos',
                value: stats.totalUsers.toString(),
                icon: Icons.people_outline,
                color: Colors.indigo,
              ),
              _MetricCard(
                title: 'Canais/Filas Ativos',
                value: stats.totalChannels.toString(),
                icon: Icons.list_alt_outlined,
                color: Colors.pink,
              ),
            ],
          ),
          const SizedBox(height: 20),
          const _AdminCard(
            child: Text('Atualização automática a cada 20 segundos'),
          ),
        ],
      ),
    );
  }

  Widget _usersTab() {
    final back = Uri.encodeComponent('/admin/${widget.slug}?tab=users');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionHeader(
          title: 'Usuários',
          buttonLabel: 'Novo Usuário',
          icon: Icons.add,
          onPressed: () =>
              context.go('/users/${widget.slug}/create?back=$back'),
        ),
        const SizedBox(height: 18),
        Expanded(
          child: _AdminCard(
            padding: EdgeInsets.zero,
            child: Stack(
              children: [
                if (_loadingUsers && _users.isEmpty)
                  const TableShimmer(rows: 12, columns: 5)
                else if (_usersError != null)
                  _ErrorState(message: _usersError!, onRetry: _loadUsers)
                else
                  _UsersAdminTable(
                    users: _users,
                    onEdit: (user) => context.go(
                      '/users/${widget.slug}/${user.id}/edit?back=$back',
                    ),
                    onDelete: _deleteUser,
                  ),
                if (_loadingUsers && _users.isNotEmpty)
                  ColoredBox(
                    color: Colors.white.withValues(alpha: 0.58),
                    child: const TableShimmer(rows: 8, columns: 5),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        AppPaginationControls(
          page: _usersPage,
          totalPages: _usersTotalPages,
          total: _usersTotal,
          canGoPrevious: _usersPage > 1 && !_loadingUsers,
          canGoNext: _usersPage < _usersTotalPages && !_loadingUsers,
          onFirst: () {
            _usersPage = 1;
            _loadUsers();
          },
          onPrevious: () {
            _usersPage -= 1;
            _loadUsers();
          },
          onNext: () {
            _usersPage += 1;
            _loadUsers();
          },
          onLast: () {
            _usersPage = _usersTotalPages;
            _loadUsers();
          },
        ),
      ],
    );
  }

  Widget _profilesTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionHeader(
          title: 'Perfis e Permissões',
          buttonLabel: 'Novo Perfil',
          icon: Icons.add,
          onPressed: () => _openProfileForm(),
        ),
        const SizedBox(height: 18),
        Expanded(
          child: _loadingProfiles && _profiles.isEmpty
              ? const _AdminCard(child: TableShimmer(rows: 5, columns: 3))
              : _profilesError != null
                  ? _ErrorState(
                      message: _profilesError!, onRetry: _loadProfiles)
                  : SingleChildScrollView(
                      child: Wrap(
                        spacing: 18,
                        runSpacing: 18,
                        children: _profiles
                            .map(
                              (profile) => _ProfileCard(
                                profile: profile,
                                onEdit: () => _openProfileForm(profile),
                                onDelete: () => _deleteProfile(profile),
                              ),
                            )
                            .toList(),
                      ),
                    ),
        ),
      ],
    );
  }

  Widget _queuesTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionHeader(
          title: 'Tipos de Serviço (Filas)',
          buttonLabel: 'Nova Fila',
          icon: Icons.add,
          onPressed: () => _openQueueForm(),
        ),
        const SizedBox(height: 18),
        Expanded(
          child: _AdminCard(
            padding: EdgeInsets.zero,
            child: Stack(
              children: [
                if (_loadingQueues && _serviceTypes.isEmpty)
                  const TableShimmer(rows: 8, columns: 3)
                else if (_queuesError != null)
                  _ErrorState(message: _queuesError!, onRetry: _loadQueues)
                else
                  _QueuesTable(
                    serviceTypes: _serviceTypes,
                    companyNames: _companyNames,
                    onEdit: _openQueueForm,
                    onDelete: _deleteQueue,
                  ),
                if (_loadingQueues && _serviceTypes.isNotEmpty)
                  ColoredBox(
                    color: Colors.white.withValues(alpha: 0.58),
                    child: const TableShimmer(rows: 7, columns: 3),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        AppPaginationControls(
          page: _queuesPage,
          totalPages: _queuesTotalPages,
          total: _queuesTotal,
          canGoPrevious: _queuesPage > 1 && !_loadingQueues,
          canGoNext: _queuesPage < _queuesTotalPages && !_loadingQueues,
          onFirst: () {
            _queuesPage = 1;
            _loadQueues();
          },
          onPrevious: () {
            _queuesPage -= 1;
            _loadQueues();
          },
          onNext: () {
            _queuesPage += 1;
            _loadQueues();
          },
          onLast: () {
            _queuesPage = _queuesTotalPages;
            _loadQueues();
          },
        ),
      ],
    );
  }

  Future<void> _deleteUser(ManagedUser user) async {
    final confirmed = await _confirm('Excluir usuário ${user.name}?');
    if (!confirmed) return;
    await _usersService.deleteUser(user.id);
    await _loadUsers();
  }

  Future<void> _deleteProfile(AdminProfileType profile) async {
    final confirmed = await _confirm('Excluir perfil ${profile.name}?');
    if (!confirmed) return;
    await _adminService.deleteProfile(profile.id);
    await _loadProfiles();
  }

  Future<void> _deleteQueue(ServiceType serviceType) async {
    final confirmed = await _confirm('Excluir fila ${serviceType.name}?');
    if (!confirmed) return;
    await _adminService.deleteServiceType(serviceType.id);
    await _loadQueues();
  }

  Future<bool> _confirm(String message) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar ação'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );
    return result == true;
  }

  Future<void> _openProfileForm([AdminProfileType? profile]) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => _ProfileFormDialog(
        profile: profile,
        onSave: (name, permissions) => _adminService.saveProfile(
          id: profile?.id,
          name: name,
          accessModules: permissions,
        ),
      ),
    );
    if (saved == true) await _loadProfiles();
  }

  Future<void> _openQueueForm([ServiceType? serviceType]) async {
    if (_companies.isEmpty) await _loadQueues();
    if (!mounted) return;

    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => _QueueFormDialog(
        serviceType: serviceType,
        companies: _companies,
        onSave: (name, companyId, priority) => _adminService.saveServiceType(
          id: serviceType?.id,
          name: name,
          priority: priority,
          companyId: companyId,
        ),
      ),
    );
    if (saved == true) await _loadQueues();
  }
}

class _AdminTabs extends StatelessWidget {
  final TabController controller;

  const _AdminTabs({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: TabBar(
            controller: controller,
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            indicatorSize: TabBarIndicatorSize.tab,
            indicator: BoxDecoration(
              color: const Color(0xFF20A3A8),
              borderRadius: BorderRadius.circular(10),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x33000000),
                  blurRadius: 6,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            labelStyle: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 16,
            ),
            unselectedLabelStyle: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 15,
            ),
            dividerColor: Colors.transparent,
            padding: EdgeInsets.zero,
            labelPadding: const EdgeInsets.symmetric(horizontal: 18),
            tabs: const [
              Tab(text: 'Dashboard'),
              Tab(text: 'Usuários'),
              Tab(text: 'Perfis'),
              Tab(text: 'Filas'),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final String buttonLabel;
  final IconData icon;
  final VoidCallback onPressed;

  const _SectionHeader({
    required this.title,
    required this.buttonLabel,
    required this.icon,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ),
        FilledButton.icon(
          style: FilledButton.styleFrom(backgroundColor: Colors.green),
          onPressed: onPressed,
          icon: Icon(icon),
          label: Text(buttonLabel),
        ),
      ],
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _MetricCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 360,
      child: _AdminCard(
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: Colors.grey.shade700,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    value,
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: Colors.black,
                        ),
                  ),
                ],
              ),
            ),
            CircleAvatar(
              radius: 28,
              backgroundColor: color,
              child: Icon(icon, color: Colors.white, size: 28),
            ),
          ],
        ),
      ),
    );
  }
}

class _AdminCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;

  const _AdminCard({
    required this.child,
    this.padding = const EdgeInsets.all(20),
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: padding,
        child: child,
      ),
    );
  }
}

class _UsersAdminTable extends StatelessWidget {
  final List<ManagedUser> users;
  final ValueChanged<ManagedUser> onEdit;
  final ValueChanged<ManagedUser> onDelete;

  const _UsersAdminTable({
    required this.users,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    if (users.isEmpty) {
      return const Center(child: Text('Nenhum usuário encontrado.'));
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SingleChildScrollView(
        child: DataTable(
          columns: const [
            DataColumn(label: Text('NOME')),
            DataColumn(label: Text('EMAIL')),
            DataColumn(label: Text('USERNAME')),
            DataColumn(label: Text('EMPRESA')),
            DataColumn(label: Text('AÇÕES')),
          ],
          rows: users
              .map(
                (user) => DataRow(
                  cells: [
                    DataCell(SizedBox(
                      width: 260,
                      child: AppOverflowTooltipText(user.name),
                    )),
                    DataCell(SizedBox(
                      width: 300,
                      child: AppOverflowTooltipText(user.email),
                    )),
                    DataCell(SizedBox(
                      width: 260,
                      child: AppOverflowTooltipText(user.username),
                    )),
                    DataCell(SizedBox(
                      width: 260,
                      child: AppOverflowTooltipText(user.companyName),
                    )),
                    DataCell(Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          tooltip: 'Editar',
                          onPressed: () => onEdit(user),
                          icon: const Icon(Icons.edit_outlined),
                          color: Colors.blue,
                        ),
                        IconButton(
                          tooltip: 'Excluir',
                          onPressed: () => onDelete(user),
                          icon: const Icon(Icons.delete_outline),
                          color: AppTheme.danger,
                        ),
                      ],
                    )),
                  ],
                ),
              )
              .toList(),
        ),
      ),
    );
  }
}

class _ProfileCard extends StatelessWidget {
  final AdminProfileType profile;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _ProfileCard({
    required this.profile,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 360,
      child: _AdminCard(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    profile.name,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                ),
                IconButton(
                  tooltip: 'Editar',
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_outlined),
                  color: Colors.blue,
                ),
                IconButton(
                  tooltip: 'Excluir',
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline),
                  color: AppTheme.danger,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Permissões:',
              style: TextStyle(
                color: Colors.grey.shade700,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            if (profile.accessModules.isEmpty)
              const Text(
                'Sem permissões cadastradas.',
                style: TextStyle(color: Colors.black54),
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: profile.accessModules
                    .map((permission) => Chip(label: Text(permission)))
                    .toList(),
              ),
          ],
        ),
      ),
    );
  }
}

class _QueuesTable extends StatelessWidget {
  final List<ServiceType> serviceTypes;
  final Map<String, String> companyNames;
  final ValueChanged<ServiceType> onEdit;
  final ValueChanged<ServiceType> onDelete;

  const _QueuesTable({
    required this.serviceTypes,
    required this.companyNames,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    if (serviceTypes.isEmpty) {
      return const Center(child: Text('Nenhuma fila encontrada.'));
    }

    return SingleChildScrollView(
      child: DataTable(
        columns: const [
          DataColumn(label: Text('NOME')),
          DataColumn(label: Text('EMPRESA')),
          DataColumn(label: Text('PRIORIDADE')),
          DataColumn(label: Text('AÇÕES')),
        ],
        rows: serviceTypes
            .map(
              (item) => DataRow(
                cells: [
                  DataCell(SizedBox(
                    width: 420,
                    child: AppOverflowTooltipText(item.name),
                  )),
                  DataCell(SizedBox(
                    width: 360,
                    child: AppOverflowTooltipText(
                      companyNames[item.companyId] ?? item.companyId,
                    ),
                  )),
                  DataCell(Chip(label: Text(item.priority.toString()))),
                  DataCell(Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: 'Editar',
                        onPressed: () => onEdit(item),
                        icon: const Icon(Icons.edit_outlined),
                        color: Colors.blue,
                      ),
                      IconButton(
                        tooltip: 'Excluir',
                        onPressed: () => onDelete(item),
                        icon: const Icon(Icons.delete_outline),
                        color: AppTheme.danger,
                      ),
                    ],
                  )),
                ],
              ),
            )
            .toList(),
      ),
    );
  }
}

class _ProfileFormDialog extends StatefulWidget {
  final AdminProfileType? profile;
  final Future<void> Function(String name, List<String> permissions) onSave;

  const _ProfileFormDialog({
    required this.profile,
    required this.onSave,
  });

  @override
  State<_ProfileFormDialog> createState() => _ProfileFormDialogState();
}

class _ProfileFormDialogState extends State<_ProfileFormDialog> {
  static const _availablePermissions = [
    'companies',
    'plans',
    'users',
    'call',
    'reviews',
    'channels',
    'reports',
  ];
  final _nameController = TextEditingController();
  final _selected = <String>{};
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _nameController.text = widget.profile?.name ?? '';
    _selected.addAll(widget.profile?.accessModules ?? const []);
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.profile == null ? 'Criar Perfil' : 'Editar Perfil'),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _nameController,
                decoration:
                    const InputDecoration(labelText: 'Nome do Perfil *'),
              ),
              const SizedBox(height: 16),
              const Text('Permissões *'),
              const SizedBox(height: 8),
              ..._availablePermissions.map(
                (permission) => CheckboxListTile(
                  value: _selected.contains(permission),
                  title: Text(permission),
                  contentPadding: EdgeInsets.zero,
                  onChanged: (value) {
                    setState(() {
                      if (value == true) {
                        _selected.add(permission);
                      } else {
                        _selected.remove(permission);
                      }
                    });
                  },
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Salvar'),
        ),
      ],
    );
  }

  Future<void> _save() async {
    if (_nameController.text.trim().isEmpty || _selected.isEmpty) return;
    setState(() => _saving = true);
    try {
      await widget.onSave(_nameController.text.trim(), _selected.toList());
      if (mounted) Navigator.of(context).pop(true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

class _QueueFormDialog extends StatefulWidget {
  final ServiceType? serviceType;
  final List<Company> companies;
  final Future<void> Function(String name, String companyId, int priority)
      onSave;

  const _QueueFormDialog({
    required this.serviceType,
    required this.companies,
    required this.onSave,
  });

  @override
  State<_QueueFormDialog> createState() => _QueueFormDialogState();
}

class _QueueFormDialogState extends State<_QueueFormDialog> {
  final _nameController = TextEditingController();
  final _priorityController = TextEditingController(text: '0');
  String _companyId = '';
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _nameController.text = widget.serviceType?.name ?? '';
    _priorityController.text = (widget.serviceType?.priority ?? 0).toString();
    _companyId = widget.serviceType?.companyId ??
        (widget.companies.isNotEmpty ? widget.companies.first.id : '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _priorityController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        widget.serviceType == null
            ? 'Criar Novo Tipo de Serviço'
            : 'Editar Tipo de Serviço',
      ),
      content: SizedBox(
        width: 620,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Nome do Tipo de Serviço *',
                hintText: 'Ex: Bombeiros, Polícia, Emergência',
              ),
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<String>(
              initialValue: _companyId.isEmpty ? null : _companyId,
              decoration: const InputDecoration(labelText: 'Empresa *'),
              items: widget.companies
                  .map(
                    (company) => DropdownMenuItem(
                      value: company.id,
                      child: Text(company.name),
                    ),
                  )
                  .toList(),
              onChanged: (value) => setState(() => _companyId = value ?? ''),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _priorityController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Prioridade * (quanto maior, mais prioritário)',
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: const Text('Salvar'),
        ),
      ],
    );
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    final priority = int.tryParse(_priorityController.text.trim()) ?? 0;
    if (name.isEmpty || _companyId.isEmpty) return;
    setState(() => _saving = true);
    try {
      await widget.onSave(name, _companyId, priority);
      if (mounted) Navigator.of(context).pop(true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
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
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(message, style: const TextStyle(color: Colors.red)),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('Tentar novamente'),
          ),
        ],
      ),
    );
  }
}
