import 'package:dio/dio.dart';

import '../core/exceptions/api_exception.dart';
import '../models/attendance_call.dart';
import 'api/api_service.dart';

class PaginatedAttendances {
  final List<AttendanceCall> calls;
  final int total;
  final int page;
  final int limit;
  final int totalPages;

  PaginatedAttendances({
    required this.calls,
    required this.total,
    required this.page,
    required this.limit,
    required this.totalPages,
  });
}

class AttendanceService {
  final ApiService apiService;

  AttendanceService(this.apiService);

  Future<PaginatedAttendances> getCalls({
    String? slug,
    int page = 1,
    int limit = 25,
    String status = 'ALL',
    String search = '',
  }) async {
    final endpoint = slug == null || slug.isEmpty || slug == 'gestalk'
        ? '/calls'
        : '/calls/company/$slug';

    try {
      final response = await apiService.dio.get(
        endpoint,
        queryParameters: {
          'page': page,
          'limit': limit,
          if (status != 'ALL') 'status': status,
          if (search.trim().isNotEmpty) 'search': search.trim(),
        },
      );
      final data = response.data;
      final rawCalls = _extractCalls(data);

      if (rawCalls is! List) {
        return PaginatedAttendances(
          calls: [],
          total: 0,
          page: page,
          limit: limit,
          totalPages: 1,
        );
      }

      final calls = rawCalls
          .whereType<Map>()
          .map((item) => AttendanceCall.fromJson(
                Map<String, dynamic>.from(item),
              ))
          .toList();

      return PaginatedAttendances(
        calls: calls,
        total: _intFromJson(data, 'total') ?? calls.length,
        page: _intFromJson(data, 'page') ?? page,
        limit: _intFromJson(data, 'limit') ?? limit,
        totalPages: _intFromJson(data, 'totalPages') ?? 1,
      );
    } on DioException catch (e) {
      throw ApiException(
        _extractDioErrorMessage(e),
        statusCode: e.response?.statusCode,
        data: e.response?.data,
      );
    }
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

  int? _intFromJson(dynamic data, String key) {
    if (data is! Map || data[key] == null) return null;
    if (data[key] is int) return data[key] as int;
    if (data[key] is num) return (data[key] as num).toInt();
    return int.tryParse(data[key].toString());
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

    return 'Erro ao buscar atendimentos: '
        '${error.response?.statusCode ?? error.message}';
  }
}
