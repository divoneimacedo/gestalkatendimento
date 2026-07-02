import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../controllers/auth_controller.dart';
import '../core/config/app_config.dart';
import '../core/config/app_theme.dart';
import '../core/router/app_router.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _userName = TextEditingController();
  final _password = TextEditingController();
  final _slug = TextEditingController(text: AppConfig.defaultSlug);

  @override
  void dispose() {
    _userName.dispose();
    _password.dispose();
    _slug.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AuthController>().loadLoginCompanies();
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();

    return Scaffold(
      backgroundColor: AppTheme.secondary,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 900;

            return Center(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(
                  horizontal: isWide ? 80 : 24,
                  vertical: 32,
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1180),
                  child: isWide
                      ? Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Expanded(
                              flex: 5,
                              child: _LoginHero(isWide: isWide),
                            ),
                            const SizedBox(width: 64),
                            Expanded(
                              flex: 4,
                              child: _LoginCard(
                                formKey: _formKey,
                                slugController: _slug,
                                userNameController: _userName,
                                passwordController: _password,
                                auth: auth,
                              ),
                            ),
                          ],
                        )
                      : Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _LoginHero(isWide: isWide),
                            const SizedBox(height: 32),
                            _LoginCard(
                              formKey: _formKey,
                              slugController: _slug,
                              userNameController: _userName,
                              passwordController: _password,
                              auth: auth,
                            ),
                          ],
                        ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _LoginHero extends StatelessWidget {
  const _LoginHero({required this.isWide});

  final bool isWide;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isWide ? Alignment.centerLeft : Alignment.center,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680),
        child: Column(
          crossAxisAlignment:
              isWide ? CrossAxisAlignment.start : CrossAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              'assets/images/logo.png',
              width: isWide ? 220 : 180,
              fit: BoxFit.contain,
            ),
            const SizedBox(height: 44),
            Text(
              'Gestalk Conecta',
              textAlign: isWide ? TextAlign.left : TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 38,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 22),
            Text(
              'Somos a conexão que faltava entre você e os surdos.',
              textAlign: isWide ? TextAlign.left : TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                height: 1.35,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LoginCard extends StatefulWidget {
  const _LoginCard({
    required this.formKey,
    required this.slugController,
    required this.userNameController,
    required this.passwordController,
    required this.auth,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController slugController;
  final TextEditingController userNameController;
  final TextEditingController passwordController;
  final AuthController auth;

  @override
  State<_LoginCard> createState() => _LoginCardState();
}

class _LoginCardState extends State<_LoginCard> {
  bool _showPassword = false;

  @override
  void didUpdateWidget(covariant _LoginCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    _ensureSelectedCompany();
  }

  void _ensureSelectedCompany() {
    final options = widget.auth.loginCompanies;
    if (options.isEmpty) return;

    final currentSlug = widget.slugController.text;
    final hasCurrent = options.any((company) => company.slug == currentSlug);
    if (hasCurrent) return;

    final defaultMatch = options.where(
      (company) => company.slug == AppConfig.defaultSlug,
    );
    final nextSlug =
        defaultMatch.isNotEmpty ? defaultMatch.first.slug : options.first.slug;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      widget.slugController.text = nextSlug;
    });
  }

  @override
  Widget build(BuildContext context) {
    _ensureSelectedCompany();

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 420),
      child: Card(
        elevation: 8,
        color: Colors.white,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: widget.formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Gestalk Atendimento',
                  style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 24),
                _companyField(),
                const SizedBox(height: 12),
                TextFormField(
                  controller: widget.userNameController,
                  decoration: const InputDecoration(labelText: 'Usuário'),
                  validator: (v) =>
                      v == null || v.isEmpty ? 'Informe o usuário' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: widget.passwordController,
                  obscureText: !_showPassword,
                  decoration: InputDecoration(
                    labelText: 'Senha',
                    suffixIcon: IconButton(
                      tooltip:
                          _showPassword ? 'Ocultar senha' : 'Mostrar senha',
                      onPressed: () {
                        setState(() => _showPassword = !_showPassword);
                      },
                      icon: Icon(
                        _showPassword
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                      ),
                    ),
                  ),
                  validator: (v) =>
                      v == null || v.isEmpty ? 'Informe a senha' : null,
                ),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: widget.auth.loading
                      ? null
                      : () async {
                          if (!widget.formKey.currentState!.validate()) return;

                          await widget.auth.signIn(
                            userName: widget.userNameController.text,
                            password: widget.passwordController.text,
                            slug: widget.slugController.text,
                          );

                          if (!context.mounted) return;

                          if (widget.auth.isAuthenticated) {
                            context.go(
                              AppRouter.defaultLocationForUser(
                                widget.auth.user,
                                widget.slugController.text,
                              ),
                            );
                            return;
                          }

                          final error = widget.auth.error;
                          if (error != null && error.isNotEmpty) {
                            _showLoginError(error);
                          }
                        },
                  child: widget.auth.loading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Entrar'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showLoginError(String message) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white),
                const SizedBox(width: 10),
                Expanded(child: Text(message)),
              ],
            ),
            behavior: SnackBarBehavior.floating,
            backgroundColor: AppTheme.danger,
            duration: const Duration(seconds: 5),
          ),
        );
    });
  }

  Widget _companyField() {
    final auth = widget.auth;
    final companies = auth.loginCompanies;
    final currentSlug = widget.slugController.text;
    final hasCurrent = companies.any((company) => company.slug == currentSlug);
    final defaultMatch = companies.where(
      (company) => company.slug == AppConfig.defaultSlug,
    );
    final selectedSlug = hasCurrent
        ? currentSlug
        : defaultMatch.isNotEmpty
            ? defaultMatch.first.slug
            : companies.isNotEmpty
                ? companies.first.slug
                : null;

    if (selectedSlug != null && widget.slugController.text != selectedSlug) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        widget.slugController.text = selectedSlug;
      });
    }

    if (auth.loadingCompanies) {
      return const InputDecorator(
        decoration: InputDecoration(labelText: 'Empresa'),
        child: Row(
          children: [
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 12),
            Text('Carregando empresas...'),
          ],
        ),
      );
    }
    if (companies.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            controller: widget.slugController,
            decoration: const InputDecoration(labelText: 'Empresa / slug'),
            validator: (v) => v == null || v.isEmpty ? 'Informe o slug' : null,
          ),
          if (auth.companiesError != null) ...[
            const SizedBox(height: 6),
            Text(
              auth.companiesError!,
              style: const TextStyle(color: AppTheme.danger, fontSize: 12),
            ),
          ],
        ],
      );
    }

    return DropdownButtonFormField<String>(
      initialValue: selectedSlug,
      isExpanded: true,
      decoration: const InputDecoration(labelText: 'Empresa'),
      items: companies
          .map(
            (company) => DropdownMenuItem<String>(
              value: company.slug,
              child: Text(
                company.name,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          )
          .toList(),
      onChanged: widget.auth.loading
          ? null
          : (value) {
              if (value == null) return;
              widget.slugController.text = value;
            },
      validator: (value) =>
          value == null || value.isEmpty ? 'Selecione a empresa' : null,
    );
  }
}
