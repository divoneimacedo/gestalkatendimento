import 'package:flutter/material.dart';

import '../widgets/app_shell.dart';

class PlaceholderPageScreen extends StatelessWidget {
  final String slug;
  final String routeKey;
  final String title;
  final IconData icon;
  final String description;

  const PlaceholderPageScreen({
    super.key,
    required this.slug,
    required this.routeKey,
    required this.title,
    required this.icon,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return AppShell(
      title: title,
      slug: slug,
      currentRoute: routeKey,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 56, color: Theme.of(context).primaryColor),
                  const SizedBox(height: 18),
                  Text(
                    title,
                    style: Theme.of(context).textTheme.headlineSmall,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    description,
                    style: Theme.of(context).textTheme.bodyLarge,
                    textAlign: TextAlign.center,
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
