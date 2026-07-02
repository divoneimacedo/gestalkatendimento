import 'package:dio/dio.dart';

import '../core/exceptions/api_exception.dart';
import '../models/interpreter.dart';
import 'api/api_service.dart';

class InterpretersPage {
  final List<InterpreterListItem> interpreters;
  final int total;
  final int page;
  final int limit;
  final int totalPages;

  const InterpretersPage({
    required this.interpreters,
    required this.total,
    required this.page,
    required this.limit,
    required this.totalPages,
  });
}

class InterpretersService {
  final ApiService apiService;

  InterpretersService(this.apiService);

  Future<InterpretersPage> fetchInterpreters({
    required int page,
    required int limit,
    required String status,
    required String search,
  }) async {
    try {
      final response = await apiService.dio.get<dynamic>(
        '/interpreters',
        queryParameters: {
          'page': page,
          'limit': limit,
          if (status != 'all') 'status': status,
          if (search.trim().isNotEmpty) 'search': search.trim(),
        },
      );

      final data = response.data;
      final rawInterpreters = data is Map ? data['interpreters'] : null;
      final rawPagination = data is Map ? data['pagination'] : null;

      final interpreters = rawInterpreters is List
          ? rawInterpreters
              .whereType<Map>()
              .map(
                (item) => InterpreterListItem.fromJson(
                  Map<String, dynamic>.from(item),
                ),
              )
              .where((item) => item.id.isNotEmpty)
              .toList()
          : <InterpreterListItem>[];

      final pagination = rawPagination is Map
          ? Map<String, dynamic>.from(rawPagination)
          : const <String, dynamic>{};

      return InterpretersPage(
        interpreters: interpreters,
        total: _int(pagination['total'], interpreters.length),
        page: _int(pagination['page'], page),
        limit: _int(pagination['limit'], limit),
        totalPages: _int(pagination['totalPages'], 1),
      );
    } on DioException catch (error) {
      throw ApiException(
        _message(error, fallback: 'Erro ao buscar intérpretes.'),
        statusCode: error.response?.statusCode,
        data: error.response?.data,
      );
    }
  }
}

int _int(dynamic value, int fallback) {
  if (value is int) return value;
  return int.tryParse(value?.toString() ?? '') ?? fallback;
}

String _message(DioException error, {required String fallback}) {
  final data = error.response?.data;
  if (data is Map) {
    final message = data['message'] ?? data['error'];
    if (message is List && message.isNotEmpty) return message.first.toString();
    if (message != null && message.toString().isNotEmpty) {
      return message.toString();
    }
  }
  return fallback;
}
