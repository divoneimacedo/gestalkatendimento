import 'package:flutter/foundation.dart';

class ActiveCallOverlayController extends ChangeNotifier {
  String? slug;
  String? callId;

  bool get hasActiveCall => slug != null && callId != null;

  void start({
    required String slug,
    required String callId,
  }) {
    if (this.slug == slug && this.callId == callId) return;
    if (hasActiveCall) return;

    this.slug = slug;
    this.callId = callId;
    notifyListeners();
  }

  void clear() {
    if (!hasActiveCall) return;

    slug = null;
    callId = null;
    notifyListeners();
  }
}
