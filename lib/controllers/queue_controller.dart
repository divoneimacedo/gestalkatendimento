import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/queue_call.dart';
import '../services/notification_service.dart';
import '../services/queue_service.dart';
import '../services/sound_service.dart';

class QueueController extends ChangeNotifier {
  final QueueService queueService;
  final NotificationService notificationService;
  final SoundService soundService;

  QueueController({
    required this.queueService,
    required this.notificationService,
    required this.soundService,
  });

  List<QueueCall> calls = [];
  bool loading = false;
  String? error;
  Timer? _timer;
  int _previousLength = 0;

  Future<void> startPolling({required String slug, bool enableAlerts = true}) async {
    await refresh(slug: slug, enableAlerts: enableAlerts);
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 15), (_) {
      refresh(slug: slug, enableAlerts: enableAlerts);
    });
  }

  Future<void> refresh({required String slug, bool enableAlerts = true}) async {
    loading = calls.isEmpty;
    error = null;
    notifyListeners();

    try {
      final result = await queueService.getWaitingCalls(slug: slug);
      calls = result;

      if (enableAlerts) {
        if (calls.isNotEmpty) {
          await soundService.startContinuousAlert();
          if (calls.length > _previousLength) {
            await notificationService.showNewCall(count: calls.length);
          }
        } else {
          await soundService.stop();
        }
      }

      _previousLength = calls.length;
    } catch (e) {
      error = e.toString();
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> accept(QueueCall call, String attendantId) async {
    await queueService.acceptCall(call: call, attendantId: attendantId);
    await soundService.stop();
  }

  Future<void> cancel(String callId, String slug) async {
    await queueService.cancelCall(callId);
    await refresh(slug: slug, enableAlerts: false);
  }

  Future<void> stop() async {
    _timer?.cancel();
    await soundService.stop();
  }

  @override
  void dispose() {
    _timer?.cancel();
    soundService.dispose();
    super.dispose();
  }
}
