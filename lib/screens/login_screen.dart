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

class _LoginCard extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 420),
      child: Card(
        elevation: 8,
        color: Colors.white,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Gestalk Atendimento',
                  style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 24),
                TextFormField(
                  controller: slugController,
                  decoration:
                      const InputDecoration(labelText: 'Empresa / slug'),
                  validator: (v) =>
                      v == null || v.isEmpty ? 'Informe o slug' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: userNameController,
                  decoration: const InputDecoration(labelText: 'Usuário'),
                  validator: (v) =>
                      v == null || v.isEmpty ? 'Informe o usuário' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: passwordController,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'Senha'),
                  validator: (v) =>
                      v == null || v.isEmpty ? 'Informe a senha' : null,
                ),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: auth.loading
                      ? null
                      : () async {
                          if (!formKey.currentState!.validate()) return;

                          await auth.signIn(
                            userName: userNameController.text,
                            password: passwordController.text,
                            slug: slugController.text,
                          );

                          if (!context.mounted) return;

                          if (auth.isAuthenticated) {
                            context.go(
                              AppRouter.defaultLocationForUser(
                                auth.user,
                                slugController.text,
                              ),
                            );
                            return;
                          }

                          final error = auth.error;
                          if (error != null && error.isNotEmpty) {
                            ScaffoldMessenger.of(context)
                              ..hideCurrentSnackBar()
                              ..showSnackBar(
                                SnackBar(
                                  content: Text(error),
                                  behavior: SnackBarBehavior.floating,
                                  backgroundColor: AppTheme.danger,
                                ),
                              );
                          }
                        },
                  child: auth.loading
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
}
