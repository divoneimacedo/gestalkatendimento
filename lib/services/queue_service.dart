import 'package:dio/dio.dart';

import '../core/exceptions/api_exception.dart';
import '../models/queue_call.dart';
import 'api/api_service.dart';

class QueueService {
  final ApiService apiService;

  QueueService(this.apiService);

  Future<List<QueueCall>> getWaitingCalls({String? slug}) async {
    final endpoint = slug == null || slug.isEmpty || slug == 'gestalk'
        ? '/calls/waiting'
        : '/calls/waiting/$slug';

    try {
      final response = await apiService.dio.get(endpoint);
      final data = response.data;
      final rawCalls = _extractCalls(data);

      if (rawCalls is! List) return [];

      return rawCalls
          .whereType<Map>()
          .map((item) => QueueCall.fromJson(Map<String, dynamic>.from(item)))
          .toList();
    } on DioException catch (e) {
      throw ApiException(
        _extractDioErrorMessage(e),
        statusCode: e.response?.statusCode,
        data: e.response?.data,
      );
    }
  }

  Future<void> acceptCall({
    required QueueCall call,
    required String attendantId,
  }) async {
    await apiService.dio.patch(
      '/calls/ongoing/${call.id}',
      data: {'attendant': attendantId},
    );
  }

  Future<void> cancelCall(String callId) async {
    await apiService.dio.delete('/calls/cancel/$callId');
  }

  dynamic _extractCalls(dynamic data) {
    if (data is List) return data;

    if (data is Map) {
      if (data['calls'] != null) return data['calls'];

      final nestedData = data['data'];
      if (nestedData is Map && nestedData['calls'] != null) {
        return nestedData['calls'];
      }
    }

    return null;
  }

  String _extractDioErrorMessage(DioException error) {
    final data = error.response?.data;

    if (data is Map) {
      final message = data['error'] ?? data['message'];
      if (message != null) return message.toString();
    }

    if (error.response?.statusCode == 401) {
      return 'Sessão expirada. Faça login novamente.';
    }

    return 'Erro ao buscar fila: ${error.response?.statusCode ?? error.message}';
  }
}
