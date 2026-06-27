import 'package:flutter/material.dart';

import 'app_menu_drawer.dart';
import 'gestalk_brand.dart';

class AppShell extends StatelessWidget {
  final String title;
  final Widget child;
  final List<Widget> actions;
  final String slug;
  final String currentRoute;

  const AppShell({
    super.key,
    required this.title,
    required this.child,
    required this.slug,
    required this.currentRoute,
    this.actions = const [],
  });

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final pagePadding = width <= 1366 ? 14.0 : 24.0;

    return Scaffold(
      drawer: AppMenuDrawer(slug: slug, currentRoute: currentRoute),
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const GestalkBrand(logoWidth: 86),
            const SizedBox(width: 18),
            Text(title),
          ],
        ),
        actions: actions,
      ),
      body: Center(
        child: Padding(
          padding: EdgeInsets.all(pagePadding),
          child: SizedBox.expand(
            child: child,
          ),
        ),
      ),
    );
  }
}
