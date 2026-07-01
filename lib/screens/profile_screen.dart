import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../controllers/auth_controller.dart';
import '../core/config/app_theme.dart';
import '../core/exceptions/api_exception.dart';
import '../models/user.dart';
import '../services/profile_service.dart';
import '../widgets/app_shell.dart';

class ProfileScreen extends StatefulWidget {
  final String slug;

  const ProfileScreen({super.key, required this.slug});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _usernameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _currentPasswordController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _loading = true;
  bool _saving = false;
  bool _showCurrentPassword = false;
  bool _showNewPassword = false;
  bool _showConfirmPassword = false;
  User? _profile;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadProfile());
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _usernameController.dispose();
    _phoneController.dispose();
    _currentPasswordController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final profile = await context.read<ProfileService>().getMyProfile();
      _fillForm(profile);

      if (!mounted) return;
      setState(() => _profile = profile);
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() => _error = error.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Erro ao carregar perfil.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _fillForm(User profile) {
    _nameController.text = profile.name;
    _emailController.text = profile.email ?? '';
    _usernameController.text = profile.username;
    _phoneController.text = profile.phoneNumber ?? '';
    _currentPasswordController.clear();
    _passwordController.clear();
    _confirmPasswordController.clear();
  }

  @override
  Widget build(BuildContext context) {
    return AppShell(
      title: 'Meu Perfil',
      slug: widget.slug,
      currentRoute: 'profile',
      actions: [
        IconButton(
          tooltip: 'Atualizar',
          onPressed: _loading || _saving ? null : _loadProfile,
          icon: const Icon(Icons.refresh),
        ),
      ],
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 980),
          child: Card(
            clipBehavior: Clip.antiAlias,
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? _ErrorState(message: _error!, onRetry: _loadProfile)
                    : SingleChildScrollView(
                        padding: const EdgeInsets.all(28),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _Header(profile: _profile),
                              const SizedBox(height: 28),
                              LayoutBuilder(
                                builder: (context, constraints) {
                                  final compact = constraints.maxWidth < 720;
                                  final fields = [
                                    _field(
                                      controller: _nameController,
                                      label: 'Nome do usuário',
                                      icon: Icons.person_outline,
                                      validator: _required('Informe o nome.'),
                                    ),
                                    _field(
                                      controller: _emailController,
                                      label: 'E-mail',
                                      icon: Icons.mail_outline,
                                      keyboardType: TextInputType.emailAddress,
                                      validator: _emailValidator,
                                    ),
                                    _field(
                                      controller: _usernameController,
                                      label: 'Apelido (login)',
                                      icon: Icons.badge_outlined,
                                      enabled: false,
                                    ),
                                    _field(
                                      controller: _phoneController,
                                      label: 'Número de telefone',
                                      icon: Icons.phone_outlined,
                                      keyboardType: TextInputType.phone,
                                    ),
                                    _field(
                                      controller: _currentPasswordController,
                                      label: 'Senha atual',
                                      icon: Icons.lock_clock_outlined,
                                      obscureText: !_showCurrentPassword,
                                      onToggleVisibility: () {
                                        setState(
                                          () => _showCurrentPassword =
                                              !_showCurrentPassword,
                                        );
                                      },
                                      validator: _currentPasswordValidator,
                                    ),
                                    _field(
                                      controller: _passwordController,
                                      label: 'Nova senha',
                                      icon: Icons.lock_outline,
                                      obscureText: !_showNewPassword,
                                      onToggleVisibility: () {
                                        setState(
                                          () => _showNewPassword =
                                              !_showNewPassword,
                                        );
                                      },
                                      validator: _passwordValidator,
                                    ),
                                    _field(
                                      controller: _confirmPasswordController,
                                      label: 'Confirmar nova senha',
                                      icon: Icons.lock_reset_outlined,
                                      obscureText: !_showConfirmPassword,
                                      onToggleVisibility: () {
                                        setState(
                                          () => _showConfirmPassword =
                                              !_showConfirmPassword,
                                        );
                                      },
                                      validator: _confirmPasswordValidator,
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

                                  return Wrap(
                                    spacing: 18,
                                    runSpacing: 18,
                                    children: [
                                      for (final field in fields)
                                        SizedBox(
                                          width:
                                              (constraints.maxWidth - 18) / 2,
                                          child: field,
                                        ),
                                    ],
                                  );
                                },
                              ),
                              const SizedBox(height: 26),
                              Align(
                                alignment: Alignment.centerRight,
                                child: FilledButton.icon(
                                  onPressed: _saving ? null : _save,
                                  icon: _saving
                                      ? const SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white,
                                          ),
                                        )
                                      : const Icon(Icons.save_outlined),
                                  label: Text(
                                    _saving ? 'Salvando...' : 'Salvar',
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
          ),
        ),
      ),
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    bool obscureText = false,
    bool enabled = true,
    VoidCallback? onToggleVisibility,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      enabled: enabled && !_saving,
      keyboardType: keyboardType,
      obscureText: obscureText,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        suffixIcon: onToggleVisibility == null
            ? null
            : IconButton(
                tooltip: obscureText ? 'Mostrar senha' : 'Ocultar senha',
                onPressed: _saving ? null : onToggleVisibility,
                icon: Icon(
                  obscureText
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                ),
              ),
        helperText: label == 'Nova senha'
            ? 'Preencha somente se quiser alterar a senha.'
            : null,
      ),
    );
  }

  Future<void> _save() async {
    final form = _formKey.currentState;
    if (form == null || !form.validate()) return;

    setState(() => _saving = true);

    try {
      final profileService = context.read<ProfileService>();
      final authController = context.read<AuthController>();
      final newPassword = _passwordController.text.trim();
      await profileService.updateMyProfile(
        name: _nameController.text.trim(),
        email: _emailController.text.trim(),
        phoneNumber: _phoneController.text.trim(),
        currentPassword: _currentPasswordController.text,
        newPassword: newPassword.isEmpty ? null : newPassword,
      );

      final updatedProfile = await profileService.getMyProfile();
      final currentUser = authController.user;
      final nextUser = (currentUser ?? updatedProfile).copyWith(
        id: updatedProfile.id.isNotEmpty ? updatedProfile.id : currentUser?.id,
        name: updatedProfile.name,
        username: updatedProfile.username,
        email: updatedProfile.email,
        phoneNumber: updatedProfile.phoneNumber,
        companyId: updatedProfile.companyId.isNotEmpty
            ? updatedProfile.companyId
            : currentUser?.companyId,
        profile: updatedProfile.profile.isNotEmpty
            ? updatedProfile.profile
            : currentUser?.profile,
        permissions: updatedProfile.permissions.isNotEmpty
            ? updatedProfile.permissions
            : currentUser?.permissions,
      );
      await authController.updateStoredUser(nextUser);

      _fillForm(nextUser);

      if (!mounted) return;
      setState(() => _profile = nextUser);
      _showMessage('Perfil atualizado com sucesso.');
    } on ApiException catch (error) {
      if (!mounted) return;
      _showMessage(error.message, isError: true);
    } catch (_) {
      if (!mounted) return;
      _showMessage('Erro ao atualizar perfil.', isError: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
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

  String? _passwordValidator(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return null;
    if (text.length < 6) return 'A nova senha deve ter ao menos 6 caracteres.';
    return null;
  }

  String? _currentPasswordValidator(String? value) {
    final newPassword = _passwordController.text.trim();
    final currentPassword = value ?? '';

    if (newPassword.isNotEmpty && currentPassword.isEmpty) {
      return 'Informe a senha atual para alterar a senha.';
    }

    return null;
  }

  String? _confirmPasswordValidator(String? value) {
    final password = _passwordController.text.trim();
    final confirmation = value?.trim() ?? '';

    if (password.isEmpty && confirmation.isEmpty) return null;
    if (password.isEmpty && confirmation.isNotEmpty) {
      return 'Informe a nova senha.';
    }
    if (confirmation.isEmpty) return 'Confirme a nova senha.';
    if (confirmation != password) return 'As senhas não coincidem.';

    return null;
  }

  void _showMessage(String message, {bool isError = false}) {
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

class _Header extends StatelessWidget {
  final User? profile;

  const _Header({required this.profile});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        CircleAvatar(
          radius: 34,
          backgroundColor: AppTheme.primary.withValues(alpha: 0.12),
          foregroundColor: AppTheme.primary,
          child: const Icon(Icons.person_outline, size: 36),
        ),
        const SizedBox(width: 18),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                profile?.name.isNotEmpty == true ? profile!.name : 'Meu Perfil',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                profile?.profile.isNotEmpty == true
                    ? profile!.profile
                    : 'Atendimento',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.black54,
                    ),
              ),
            ],
          ),
        ),
      ],
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
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: AppTheme.danger, size: 42),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 18),
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
