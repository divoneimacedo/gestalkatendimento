import 'package:flutter/material.dart';

import '../core/config/app_config.dart';
import '../core/config/app_theme.dart';
import '../widgets/app_shell.dart';
import '../widgets/gestalk_brand.dart';

class AboutScreen extends StatelessWidget {
  final String slug;

  const AboutScreen({super.key, required this.slug});

  @override
  Widget build(BuildContext context) {
    return AppShell(
      title: 'Sobre',
      slug: slug,
      currentRoute: 'about',
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 920),
          child: Card(
            clipBehavior: Clip.antiAlias,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.fromLTRB(32, 30, 32, 28),
                    color: AppTheme.secondary,
                    child: const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        GestalkBrand(logoWidth: 180),
                        SizedBox(height: 22),
                        Text(
                          'Gestalk Atendimento',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 30,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Aplicativo desktop para atendimento em vídeo, acompanhamento da fila, notificações e operação dos intérpretes.',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 16,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(28),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 14,
                          runSpacing: 14,
                          children: const [
                            _InfoCard(
                              icon: Icons.video_call_outlined,
                              title: 'Atendimento',
                              description:
                                  'Receba chamadas, acesse a fila e conduza atendimentos com áudio e vídeo.',
                            ),
                            _InfoCard(
                              icon: Icons.notifications_active_outlined,
                              title: 'Notificações',
                              description:
                                  'Monitore novas chamadas e mensagens enviadas pelo sistema.',
                            ),
                            _InfoCard(
                              icon: Icons.analytics_outlined,
                              title: 'Relatórios',
                              description:
                                  'Consulte métricas, atendimentos e exportações operacionais.',
                            ),
                          ],
                        ),
                        const SizedBox(height: 28),
                        const _SectionTitle('Versionamento'),
                        const SizedBox(height: 10),
                        const _VersionRow(
                          label: 'Aplicativo',
                          value: AppConfig.appName,
                        ),
                        const _VersionRow(
                          label: 'Versão',
                          value: AppConfig.appVersion,
                        ),
                        _VersionRow(
                          label: 'Ambiente',
                          value: AppConfig.environment.name,
                        ),
                        const SizedBox(height: 28),
                        const _SectionTitle('Desenvolvimento'),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 28,
                            vertical: 26,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Row(
                            children: [
                              _UbistartLogo(),
                              SizedBox(width: 22),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Desenvolvido por Ubistart',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 20,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    SizedBox(height: 6),
                                    Text(
                                      'Transformações reais com software. ',
                                      style: TextStyle(
                                        color: Colors.white,
                                        height: 1.35,
                                      ),
                                    ),
                                    Text('On demand.',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w600,
                                        )),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;

  const _InfoCard({
    required this.icon,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 260,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppTheme.primary.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppTheme.primary.withValues(alpha: 0.16)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: AppTheme.primary, size: 30),
              const SizedBox(height: 14),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                description,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      height: 1.35,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;

  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w800,
          ),
    );
  }
}

class _VersionRow extends StatelessWidget {
  final String label;
  final String value;

  const _VersionRow({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          Expanded(child: SelectableText(value)),
        ],
      ),
    );
  }
}

class _UbistartLogo extends StatelessWidget {
  const _UbistartLogo();

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/images/logo_ubistart.png',
      width: 260,
      fit: BoxFit.contain,
      errorBuilder: (_, __, ___) {
        return const Text(
          'ubistart',
          style: TextStyle(
            color: Colors.white,
            fontSize: 42,
            fontWeight: FontWeight.w900,
          ),
        );
      },
    );
  }
}
