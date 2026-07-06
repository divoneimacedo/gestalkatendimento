import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../controllers/active_call_overlay_controller.dart';
import '../screens/call_screen.dart';

class ActiveCallOverlay extends StatelessWidget {
  const ActiveCallOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<ActiveCallOverlayController>();
    final slug = controller.slug;
    final callId = controller.callId;

    if (slug == null || callId == null) {
      return const SizedBox.shrink();
    }

    return Positioned(
      right: 18,
      bottom: 18,
      width: 680,
      height: 520,
      child: SafeArea(
        child: CallScreen(
          key: ValueKey('active-call-$slug-$callId'),
          slug: slug,
          callId: callId,
          embedded: true,
          onClosed: controller.clear,
        ),
      ),
    );
  }
}
