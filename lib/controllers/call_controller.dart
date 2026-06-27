import 'package:flutter/foundation.dart';

import '../models/call_details.dart';
import '../services/call_service.dart';

class CallController extends ChangeNotifier {
  final CallService callService;

  CallController({required this.callService});

  CallDetails? currentCall;
  String? videoSdkToken;
  bool loading = false;
  bool finishing = false;
  String? error;

  Future<void> load(String callId) async {
    loading = true;
    error = null;
    notifyListeners();

    try {
      final results = await Future.wait([
        callService.getById(callId),
        callService.getVideoSdkToken(),
      ]);
      currentCall = results[0] as CallDetails;
      videoSdkToken = results[1] as String;
    } catch (_) {
      error = 'Não foi possível carregar os dados da chamada.';
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> finish(String callId) async {
    finishing = true;
    error = null;
    notifyListeners();

    try {
      await callService.finish(callId);
    } catch (_) {
      error = 'Não foi possível encerrar a chamada no servidor.';
      rethrow;
    } finally {
      finishing = false;
      notifyListeners();
    }
  }
}
