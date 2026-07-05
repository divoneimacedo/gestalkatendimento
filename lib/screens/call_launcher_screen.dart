import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../controllers/active_call_overlay_controller.dart';

class CallLauncherScreen extends StatefulWidget {
  final String slug;
  final String callId;

  const CallLauncherScreen({
    super.key,
    required this.slug,
    required this.callId,
  });

  @override
  State<CallLauncherScreen> createState() => _CallLauncherScreenState();
}

class _CallLauncherScreenState extends State<CallLauncherScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      context.read<ActiveCallOverlayController>().start(
            slug: widget.slug,
            callId: widget.callId,
          );
      context.go('/queue/${widget.slug}');
    });
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}
