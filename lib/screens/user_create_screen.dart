import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../core/exceptions/api_exception.dart';
import '../services/users_service.dart';
import '../widgets/app_shell.dart';

class UserCreateScreen extends StatefulWidget {
  final String slug;
  final String? backLocation;

  const UserCreateScreen({
    super.key,
    required this.slug,
    this.backLocation,
  });

  @override
  State<UserCreateScreen> createState() => _UserCreateScreenState();
}

class _UserCreateScreenState extends State<UserCreateScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _usernameController = TextEditingController();
  final _phoneController = TextEditingController();
  List<UserEditOption> _companies = [];
  List<UserEditOption> _profiles = [];
  String _companyId = '';
  String _profileId = '';
  bool _loading = true;
  bool _saving = false;
  String? _error;

  String get _backLocation => widget.backLocation ?? '/users/${widget.slug}';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadOptions());
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _usernameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _loadOptions() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final service = context.read<UsersService>();
      final companies = await service.fetchCompanies();
      final profiles = await service.fetchProfiles();
      setState(() {
        _companies = companies;
        _profiles = profiles;
        _companyId = companies.isNotEmpty ? companies.first.id : '';
        _profileId = profiles.isNotEmpty ? profiles.first.id : '';
      });
    } on ApiException catch (error) {
      setState(() => _error = error.message);
    } catch (_) {
      setState(() => _error = 'Erro ao carregar dados do cadastro.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppShell(
      title: 'Criar usuário',
      slug: widget.slug,
      currentRoute: 'admin',
      actions: [
        IconButton(
          tooltip: 'Atualizar',
          onPressed: _loading ? null : _loadOptions,
          icon: const Icon(Icons.refresh),
        ),
      ],
      child: Card(
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? _ErrorState(message: _error!, onRetry: _loadOptions)
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        color: Colors.grey.shade100,
                        padding: const EdgeInsets.all(20),
                        child: Row(
                          children: [
                            const Expanded(
                              child: Text(
                                'Criar novo usuário',
                                style: TextStyle(fontWeight: FontWeight.w800),
                              ),
                            ),
                            FilledButton(
                              style: FilledButton.styleFrom(
                                backgroundColor: Colors.blue.shade800,
                              ),
                              onPressed: () => context.go(_backLocation),
                              child: const Text('VOLTAR'),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.all(20),
                          child: Form(
                            key: _formKey,
                            child: LayoutBuilder(
                              builder: (context, constraints) {
                                final compact = constraints.maxWidth < 760;
                                final fields = [
                                  DropdownButtonFormField<String>(
                                    initialValue:
                                        _companyId.isEmpty ? null : _companyId,
                                    decoration: const InputDecoration(
                                      labelText: 'Empresa',
                                    ),
                                    items: _companies
                                        .map(
                                          (company) => DropdownMenuItem(
                                            value: company.id,
                                            child: Text(company.name),
                                          ),
                                        )
                                        .toList(),
                                    validator: (value) =>
                                        value == null || value.isEmpty
                                            ? 'Selecione a empresa'
                                            : null,
                                    onChanged: (value) => setState(
                                      () => _companyId = value ?? '',
                                    ),
                                  ),
                                  DropdownButtonFormField<String>(
                                    initialValue:
                                        _profileId.isEmpty ? null : _profileId,
                                    decoration: const InputDecoration(
                                      labelText: 'Função',
                                    ),
                                    items: _profiles
                                        .map(
                                          (profile) => DropdownMenuItem(
                                            value: profile.id,
                                            child: Text(profile.name),
                                          ),
                                        )
                                        .toList(),
                                    validator: (value) =>
                                        value == null || value.isEmpty
                                            ? 'Selecione a função'
                                            : null,
                                    onChanged: (value) => setState(
                                      () => _profileId = value ?? '',
                                    ),
                                  ),
                                  TextFormField(
                                    controller: _nameController,
                                    decoration: const InputDecoration(
                                      labelText: 'Nome do usuário',
                                    ),
                                    validator: _required,
                                  ),
                                  TextFormField(
                                    controller: _emailController,
                                    decoration: const InputDecoration(
                                      labelText: 'E-mail',
                                    ),
                                    validator: _required,
                                  ),
                                  TextFormField(
                                    controller: _usernameController,
                                    decoration: const InputDecoration(
                                      labelText: 'Apelido (login)',
                                    ),
                                    validator: _required,
                                  ),
                                  TextFormField(
                                    controller: _phoneController,
                                    decoration: const InputDecoration(
                                      labelText: 'Número de Telefone',
                                      helperText: 'Formato: +55DDD9XXXXXXXX',
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
                                      _saveButton(),
                                    ],
                                  );
                                }

                                return Column(
                                  children: [
                                    for (var i = 0; i < fields.length; i += 2)
                                      Padding(
                                        padding:
                                            const EdgeInsets.only(bottom: 18),
                                        child: Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Expanded(child: fields[i]),
                                            const SizedBox(width: 20),
                                            Expanded(
                                              child: i + 1 < fields.length
                                                  ? fields[i + 1]
                                                  : const SizedBox.shrink(),
                                            ),
                                          ],
                                        ),
                                      ),
                                    const Text(
                                      'A senha será gerada automaticamente durante o cadastro e exibida após salvar.',
                                    ),
                                    const SizedBox(height: 26),
                                    Align(
                                      alignment: Alignment.centerRight,
                                      child: _saveButton(),
                                    ),
                                  ],
                                );
                              },
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
      ),
    );
  }

  Widget _saveButton() {
    return FilledButton(
      style: FilledButton.styleFrom(backgroundColor: Colors.green),
      onPressed: _saving ? null : _save,
      child: _saving
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Text('SALVAR'),
    );
  }

  String? _required(String? value) {
    return value == null || value.trim().isEmpty ? 'Campo obrigatório' : null;
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    try {
      final password = await context.read<UsersService>().createUser(
            name: _nameController.text.trim(),
            email: _emailController.text.trim(),
            username: _usernameController.text.trim(),
            companyId: _companyId,
            profileId: _profileId,
            phoneNumber: _phoneController.text,
          );
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Usuário criado'),
          content: SelectableText(
            password.isEmpty
                ? 'Usuário criado com sucesso.'
                : 'Senha gerada: $password',
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      if (mounted) context.go(_backLocation);
    } on ApiException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.message)),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorState({required this.message, required this.onRetry});

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
