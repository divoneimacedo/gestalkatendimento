import 'package:dio/dio.dart';

import '../core/exceptions/api_exception.dart';
import '../models/user.dart';
import 'api/api_service.dart';

class ProfileService {
  final ApiService apiService;

  ProfileService(this.apiService);

  Future<User> getMyProfile() async {
    try {
      final response = await apiService.dio.get<dynamic>('/user/me');
      final data = response.data;
      final rawUser = data is Map ? data['user'] : null;

      if (rawUser is Map) {
        return User.fromJson(Map<String, dynamic>.from(rawUser));
      }

      throw ApiException('Dados do perfil não retornados pela API.');
    } on DioException catch (error) {
      throw ApiException(
        _extractMessage(error, fallback: 'Erro ao carregar perfil.'),
        statusCode: error.response?.statusCode,
        data: error.response?.data,
      );
    }
  }

  Future<void> updateMyProfile({
    required String name,
    required String email,
    String? phoneNumber,
    String? currentPassword,
    String? newPassword,
  }) async {
    try {
      await apiService.dio.patch<dynamic>(
        '/user/me',
        data: {
          'name': name,
          'email': email,
          'phoneNumber': phoneNumber,
          if (currentPassword != null && currentPassword.isNotEmpty)
            'currentPassword': currentPassword,
          if (newPassword != null && newPassword.isNotEmpty)
            'newPassword': newPassword,
        },
      );
    } on DioException catch (error) {
      throw ApiException(
        _extractMessage(error, fallback: 'Erro ao atualizar perfil.'),
        statusCode: error.response?.statusCode,
        data: error.response?.data,
      );
    }
  }

  String _extractMessage(DioException error, {required String fallback}) {
    final data = error.response?.data;

    if (data is Map && data['message'] != null) {
      return data['message'].toString();
    }

    if (error.response?.statusCode == 409) {
      return 'E-mail já está em uso.';
    }

    return fallback;
  }
}
