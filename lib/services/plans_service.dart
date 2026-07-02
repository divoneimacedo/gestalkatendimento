import 'package:dio/dio.dart';

import '../core/exceptions/api_exception.dart';
import '../models/plan.dart';
import 'api/api_service.dart';

class PlansPage {
  final List<Plan> plans;
  final int total;
  final int page;
  final int limit;
  final int totalPages;

  const PlansPage({
    required this.plans,
    required this.total,
    required this.page,
    required this.limit,
    required this.totalPages,
  });
}

class PlansService {
  final ApiService apiService;

  PlansService(this.apiService);

  Future<PlansPage> fetchPlans({
    required String slug,
    required int page,
    required int limit,
  }) async {
    try {
      final path = slug == 'gestalk' ? '/plan' : '/plan/company/slug/$slug';
      final response = await apiService.dio.get<dynamic>(
        path,
        queryParameters: {
          'page': page,
          'limit': limit,
        },
      );

      final data = response.data;
      final rawPlans = data is Map ? data['plans'] : null;
      final rawPagination = data is Map ? data['pagination'] : null;

      final plans = rawPlans is List
          ? rawPlans
              .whereType<Map>()
              .map((item) => Plan.fromJson(Map<String, dynamic>.from(item)))
              .where((plan) => plan.id.isNotEmpty)
              .toList()
          : <Plan>[];

      final pagination = rawPagination is Map
          ? Map<String, dynamic>.from(rawPagination)
          : const <String, dynamic>{};

      return PlansPage(
        plans: plans,
        total: _int(pagination['total'], plans.length),
        page: _int(pagination['page'], page),
        limit: _int(pagination['limit'], limit),
        totalPages: _int(pagination['totalPages'], 1),
      );
    } on DioException catch (error) {
      throw ApiException(
        _message(error, fallback: 'Erro ao buscar planos.'),
        statusCode: error.response?.statusCode,
        data: error.response?.data,
      );
    }
  }

  Future<Plan> fetchPlan(String planId) async {
    try {
      final response = await apiService.dio.get<dynamic>('/plan/$planId');
      final data = response.data;
      final rawPlan = data is Map ? data['plan'] : null;

      if (rawPlan is! Map) {
        throw ApiException('Plano não encontrado.');
      }

      return Plan.fromJson(Map<String, dynamic>.from(rawPlan));
    } on DioException catch (error) {
      throw ApiException(
        _message(error, fallback: 'Erro ao buscar plano.'),
        statusCode: error.response?.statusCode,
        data: error.response?.data,
      );
    }
  }

  Future<void> createPlan({
    required String name,
    required num value,
    required int duration,
    required bool isInative,
  }) async {
    try {
      await apiService.dio.post<dynamic>(
        '/plan',
        data: {
          'name': name,
          'value': value,
          'duration': duration,
          'isInative': isInative,
        },
      );
    } on DioException catch (error) {
      throw ApiException(
        _message(error, fallback: 'Erro ao criar plano.'),
        statusCode: error.response?.statusCode,
        data: error.response?.data,
      );
    }
  }

  Future<void> updatePlan({
    required String planId,
    required String name,
    required num value,
    required int duration,
    required bool isInative,
  }) async {
    try {
      await apiService.dio.put<dynamic>(
        '/plan/$planId',
        data: {
          'name': name,
          'value': value,
          'duration': duration,
          'isInative': isInative,
        },
      );
    } on DioException catch (error) {
      throw ApiException(
        _message(error, fallback: 'Erro ao atualizar plano.'),
        statusCode: error.response?.statusCode,
        data: error.response?.data,
      );
    }
  }

  Future<void> deletePlan(String planId) async {
    try {
      await apiService.dio.delete<dynamic>('/plan/$planId');
    } on DioException catch (error) {
      throw ApiException(
        _message(error, fallback: 'Erro ao excluir plano.'),
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
