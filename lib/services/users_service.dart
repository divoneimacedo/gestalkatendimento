import 'package:dio/dio.dart';

import '../core/exceptions/api_exception.dart';
import '../models/managed_user.dart';
import 'api/api_service.dart';

class UsersService {
  final ApiService apiService;

  UsersService(this.apiService);

  Future<ManagedUsersPage> fetchUsers({
    required String slug,
    required bool blockedOnly,
    required int page,
    required int limit,
    required String search,
  }) async {
    try {
      final path = blockedOnly
          ? '/user/blocked'
          : slug == 'gestalk'
              ? '/user'
              : '/user/company/slug/$slug';

      final response = await apiService.dio.get<dynamic>(
        path,
        queryParameters: {
          'page': page,
          'limit': limit,
          if (search.trim().isNotEmpty) 'search': search.trim(),
        },
      );

      final data = response.data;
      final rawUsers = data is Map ? data['users'] : null;
      final rawPagination = data is Map ? data['pagination'] : null;

      final users = rawUsers is List
          ? rawUsers
              .whereType<Map>()
              .map((item) =>
                  ManagedUser.fromJson(Map<String, dynamic>.from(item)))
              .toList()
          : <ManagedUser>[];

      final pagination = rawPagination is Map
          ? Map<String, dynamic>.from(rawPagination)
          : const <String, dynamic>{};

      return ManagedUsersPage(
        users: users,
        total: _int(pagination['total'], users.length),
        page: _int(pagination['page'], page),
        limit: _int(pagination['limit'], limit),
        totalPages: _int(pagination['totalPages'], 1),
      );
    } on DioException catch (error) {
      throw ApiException(
        _message(error, fallback: 'Erro ao buscar usuários.'),
        statusCode: error.response?.statusCode,
        data: error.response?.data,
      );
    }
  }

  Future<void> updateUser(ManagedUser user) async {
    try {
      await apiService.dio.patch<dynamic>(
        '/user/${user.id}',
        data: {
          'name': user.name,
          'email': user.email,
          'username': user.username,
          'companyId': user.companyId,
          'profileId': user.profileId,
          'phoneNumber': user.phoneNumber,
        },
      );
    } on DioException catch (error) {
      throw ApiException(
        _message(error, fallback: 'Erro ao atualizar usuário.'),
        statusCode: error.response?.statusCode,
        data: error.response?.data,
      );
    }
  }

  Future<void> blockUser(String userId) {
    return _patchAction('/user/$userId/block', 'Erro ao bloquear usuário.');
  }

  Future<void> unblockUser(String userId) {
    return _patchAction(
      '/user/$userId/unblock',
      'Erro ao desbloquear usuário.',
    );
  }

  Future<void> deleteUser(String userId) async {
    try {
      await apiService.dio.delete<dynamic>('/user/$userId');
    } on DioException catch (error) {
      throw ApiException(
        _message(error, fallback: 'Erro ao excluir usuário.'),
        statusCode: error.response?.statusCode,
        data: error.response?.data,
      );
    }
  }

  Future<void> sendNotification({
    required String userId,
    required String message,
  }) async {
    try {
      await apiService.dio.post<dynamic>(
        '/notifications/send',
        data: {
          'userId': userId,
          'type': 'PUSH',
          'title': 'Notificação',
          'message': message,
        },
      );
    } on DioException catch (error) {
      throw ApiException(
        _message(error, fallback: 'Erro ao enviar notificação.'),
        statusCode: error.response?.statusCode,
        data: error.response?.data,
      );
    }
  }

  Future<void> _patchAction(String path, String fallback) async {
    try {
      await apiService.dio.patch<dynamic>(path);
    } on DioException catch (error) {
      throw ApiException(
        _message(error, fallback: fallback),
        statusCode: error.response?.statusCode,
        data: error.response?.data,
      );
    }
  }

  String _message(DioException error, {required String fallback}) {
    final data = error.response?.data;
    if (data is Map && data['message'] != null) {
      return data['message'].toString();
    }
    return fallback;
  }
}

int _int(dynamic value, int fallback) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? fallback;
  return fallback;
}
