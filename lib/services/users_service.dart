import 'package:dio/dio.dart';

import '../core/exceptions/api_exception.dart';
import '../models/app_notification.dart';
import '../models/managed_user.dart';
import 'api/api_service.dart';

class UserEditOption {
  final String id;
  final String name;

  const UserEditOption({
    required this.id,
    required this.name,
  });
}

class UserNotificationsPage {
  final List<AppNotification> notifications;
  final int total;
  final int page;
  final int limit;
  final int totalPages;

  const UserNotificationsPage({
    required this.notifications,
    required this.total,
    required this.page,
    required this.limit,
    required this.totalPages,
  });
}

class UsersService {
  final ApiService apiService;

  UsersService(this.apiService);

  Future<ManagedUser> fetchUserById(String userId) async {
    try {
      final response = await apiService.dio.get<dynamic>('/user/$userId');
      final data = response.data;
      final rawUser = data is Map ? data['user'] : null;

      if (rawUser is! Map) {
        throw ApiException('Usuário não encontrado.');
      }

      return ManagedUser.fromJson(Map<String, dynamic>.from(rawUser));
    } on DioException catch (error) {
      throw ApiException(
        _message(error, fallback: 'Erro ao buscar usuário.'),
        statusCode: error.response?.statusCode,
        data: error.response?.data,
      );
    }
  }

  Future<List<UserEditOption>> fetchCompanies() async {
    try {
      final response = await apiService.dio.get<dynamic>(
        '/company',
        queryParameters: {
          'page': 1,
          'limit': 100,
        },
      );
      final data = response.data;
      final rawCompanies = data is Map ? data['companies'] : null;

      if (rawCompanies is! List) return [];

      return rawCompanies
          .whereType<Map>()
          .map((item) => UserEditOption(
                id: item['id']?.toString() ?? '',
                name: item['name']?.toString() ?? '',
              ))
          .where((item) => item.id.isNotEmpty)
          .toList();
    } on DioException catch (error) {
      throw ApiException(
        _message(error, fallback: 'Erro ao buscar empresas.'),
        statusCode: error.response?.statusCode,
        data: error.response?.data,
      );
    }
  }

  Future<List<UserEditOption>> fetchProfiles() async {
    try {
      final response = await apiService.dio.get<dynamic>('/profileTypes');
      final data = response.data;
      final rawProfiles = data is Map ? data['profileTypes'] : null;

      if (rawProfiles is! List) return [];

      return rawProfiles
          .whereType<Map>()
          .map((item) => UserEditOption(
                id: item['id']?.toString() ?? '',
                name: item['name']?.toString() ?? '',
              ))
          .where((item) => item.id.isNotEmpty)
          .toList();
    } on DioException catch (error) {
      throw ApiException(
        _message(error, fallback: 'Erro ao buscar funções.'),
        statusCode: error.response?.statusCode,
        data: error.response?.data,
      );
    }
  }

  Future<UserNotificationsPage> fetchUserNotifications({
    required String userId,
    int page = 1,
    int limit = 100,
  }) async {
    try {
      final response = await apiService.dio.get<dynamic>(
        '/notifications/user/$userId',
        queryParameters: {
          'page': page,
          'limit': limit,
        },
      );

      final data = response.data;
      final rawNotifications = data is Map ? data['notifications'] : null;
      final rawPagination = data is Map ? data['pagination'] : null;

      final notifications = rawNotifications is List
          ? rawNotifications
              .whereType<Map>()
              .map((item) =>
                  AppNotification.fromJson(Map<String, dynamic>.from(item)))
              .where((notification) => notification.id.isNotEmpty)
              .toList()
          : <AppNotification>[];

      final pagination = rawPagination is Map
          ? Map<String, dynamic>.from(rawPagination)
          : const <String, dynamic>{};

      return UserNotificationsPage(
        notifications: notifications,
        total: _int(pagination['total'], notifications.length),
        page: _int(pagination['page'], page),
        limit: _int(pagination['limit'], limit),
        totalPages: _int(pagination['totalPages'], 1),
      );
    } on DioException catch (error) {
      throw ApiException(
        _message(error, fallback: 'Erro ao buscar notificações do usuário.'),
        statusCode: error.response?.statusCode,
        data: error.response?.data,
      );
    }
  }

  Future<void> markNotificationAsRead(String notificationId) async {
    try {
      await apiService.dio
          .patch<dynamic>('/notifications/$notificationId/read');
    } on DioException catch (error) {
      throw ApiException(
        _message(error, fallback: 'Erro ao marcar notificação como lida.'),
        statusCode: error.response?.statusCode,
        data: error.response?.data,
      );
    }
  }

  Future<ManagedUsersPage> fetchUsers({
    required String slug,
    required bool blockedOnly,
    required int page,
    required int limit,
    required String search,
    String? companyId,
  }) async {
    try {
      final isCompanyMode = companyId != null && companyId.isNotEmpty;
      final path = isCompanyMode
          ? '/user/company/$companyId'
          : blockedOnly
              ? '/user/blocked'
              : slug == 'gestalk'
                  ? '/user'
                  : '/user/company/slug/$slug';

      final response = await apiService.dio.get<dynamic>(
        path,
        queryParameters: isCompanyMode
            ? null
            : {
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
        total: isCompanyMode
            ? users.length
            : _int(pagination['total'], users.length),
        page: isCompanyMode ? 1 : _int(pagination['page'], page),
        limit: isCompanyMode ? users.length : _int(pagination['limit'], limit),
        totalPages: isCompanyMode ? 1 : _int(pagination['totalPages'], 1),
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

  Future<String> createUser({
    required String name,
    required String email,
    required String username,
    required String companyId,
    required String profileId,
    String? phoneNumber,
  }) async {
    try {
      final response = await apiService.dio.post<dynamic>(
        '/user',
        data: {
          'name': name,
          'email': email,
          'username': username,
          'companyId': companyId,
          'profileId': profileId,
          if (phoneNumber != null && phoneNumber.trim().isNotEmpty)
            'phoneNumber': phoneNumber.trim(),
        },
      );
      final data = response.data;
      final password = data is Map ? data['password'] : null;
      return password?.toString() ?? '';
    } on DioException catch (error) {
      throw ApiException(
        _message(error, fallback: 'Erro ao criar usuário.'),
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
