import 'package:dio/dio.dart';

import '../core/exceptions/api_exception.dart';
import '../models/admin_dashboard_stats.dart';
import '../models/admin_profile_type.dart';
import '../models/service_type.dart';
import 'api/api_service.dart';

class AdminService {
  final ApiService apiService;

  AdminService(this.apiService);

  Future<AdminDashboardStats> fetchDashboardStats() async {
    try {
      final response = await apiService.dio.get<dynamic>('/admin/dashboard');
      final data = response.data;
      if (data is Map) {
        return AdminDashboardStats.fromJson(Map<String, dynamic>.from(data));
      }
      throw ApiException('Dashboard não retornado pela API.');
    } on DioException catch (error) {
      throw ApiException(
        _message(error, fallback: 'Erro ao carregar dashboard.'),
        statusCode: error.response?.statusCode,
        data: error.response?.data,
      );
    }
  }

  Future<List<AdminProfileType>> fetchProfiles() async {
    try {
      final response = await apiService.dio.get<dynamic>('/profileTypes');
      final data = response.data;
      final rawProfiles = data is Map ? data['profileTypes'] : null;
      if (rawProfiles is! List) return [];

      return rawProfiles
          .whereType<Map>()
          .map((item) =>
              AdminProfileType.fromJson(Map<String, dynamic>.from(item)))
          .where((profile) => profile.id.isNotEmpty)
          .toList();
    } on DioException catch (error) {
      throw ApiException(
        _message(error, fallback: 'Erro ao carregar perfis.'),
        statusCode: error.response?.statusCode,
        data: error.response?.data,
      );
    }
  }

  Future<void> saveProfile({
    String? id,
    required String name,
    required List<String> accessModules,
  }) async {
    try {
      final data = {
        'name': name,
        'accessModules': accessModules,
      };
      if (id == null || id.isEmpty) {
        await apiService.dio.post<dynamic>('/profileTypes', data: data);
      } else {
        await apiService.dio.patch<dynamic>('/profileTypes/$id', data: data);
      }
    } on DioException catch (error) {
      throw ApiException(
        _message(error, fallback: 'Erro ao salvar perfil.'),
        statusCode: error.response?.statusCode,
        data: error.response?.data,
      );
    }
  }

  Future<void> deleteProfile(String id) async {
    try {
      await apiService.dio.delete<dynamic>('/profileTypes/$id');
    } on DioException catch (error) {
      throw ApiException(
        _message(error, fallback: 'Erro ao excluir perfil.'),
        statusCode: error.response?.statusCode,
        data: error.response?.data,
      );
    }
  }

  Future<ServiceTypesPage> fetchServiceTypes({
    required int page,
    required int limit,
  }) async {
    try {
      final response = await apiService.dio.get<dynamic>(
        '/service-types',
        queryParameters: {
          'page': page,
          'limit': limit,
        },
      );
      final data = response.data;
      final rawItems = data is Map ? data['serviceTypes'] : null;
      final rawPagination = data is Map ? data['pagination'] : null;
      final pagination = rawPagination is Map
          ? Map<String, dynamic>.from(rawPagination)
          : const <String, dynamic>{};

      final items = rawItems is List
          ? rawItems
              .whereType<Map>()
              .map((item) => ServiceType.fromJson(
                    Map<String, dynamic>.from(item),
                  ))
              .where((item) => item.id.isNotEmpty)
              .toList()
          : <ServiceType>[];

      return ServiceTypesPage(
        serviceTypes: items,
        total: _int(pagination['total'], items.length),
        page: _int(pagination['page'], page),
        limit: _int(pagination['limit'], limit),
        totalPages: _int(pagination['totalPages'], 1),
      );
    } on DioException catch (error) {
      throw ApiException(
        _message(error, fallback: 'Erro ao carregar filas.'),
        statusCode: error.response?.statusCode,
        data: error.response?.data,
      );
    }
  }

  Future<ServiceType> fetchServiceType(String id) async {
    try {
      final response = await apiService.dio.get<dynamic>('/service-types/$id');
      final data = response.data;
      final raw = data is Map ? data['serviceType'] : null;
      if (raw is! Map) throw ApiException('Fila não encontrada.');
      return ServiceType.fromJson(Map<String, dynamic>.from(raw));
    } on DioException catch (error) {
      throw ApiException(
        _message(error, fallback: 'Erro ao carregar fila.'),
        statusCode: error.response?.statusCode,
        data: error.response?.data,
      );
    }
  }

  Future<void> saveServiceType({
    String? id,
    required String name,
    required int priority,
    required String companyId,
  }) async {
    try {
      final data = {
        'name': name,
        'priority': priority,
        'companyId': companyId,
      };
      if (id == null || id.isEmpty) {
        await apiService.dio.post<dynamic>('/service-types', data: data);
      } else {
        await apiService.dio.patch<dynamic>('/service-types/$id', data: data);
      }
    } on DioException catch (error) {
      throw ApiException(
        _message(error, fallback: 'Erro ao salvar fila.'),
        statusCode: error.response?.statusCode,
        data: error.response?.data,
      );
    }
  }

  Future<void> deleteServiceType(String id) async {
    try {
      await apiService.dio.delete<dynamic>('/service-types/$id');
    } on DioException catch (error) {
      throw ApiException(
        _message(error, fallback: 'Erro ao excluir fila.'),
        statusCode: error.response?.statusCode,
        data: error.response?.data,
      );
    }
  }
}

int _int(dynamic value, int fallback) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? fallback;
  return fallback;
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
