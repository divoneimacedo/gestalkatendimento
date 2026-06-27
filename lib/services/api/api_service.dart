import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../core/config/app_config.dart';
import '../storage/token_storage.dart';

class ApiService {
  final TokenStorage tokenStorage;
  VoidCallback? onUnauthorized;

  late final Dio dio;
  late final Dio _refreshDio;
  Future<bool>? _refreshingToken;
  bool _unauthorizedNotified = false;

  ApiService({
    required this.tokenStorage,
  }) {
    final options = BaseOptions(
      baseUrl: AppConfig.apiUrl,
      connectTimeout: const Duration(seconds: 20),
      receiveTimeout: const Duration(seconds: 20),
      headers: {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      },
    );

    dio = Dio(options);
    _refreshDio = Dio(options);

    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await tokenStorage.accessToken;

          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }

          return handler.next(options);
        },
        onError: (error, handler) async {
          final isUnauthorized = error.response?.statusCode == 401;
          final alreadyRetried = error.requestOptions.extra['retried'] == true;
          final isAuthRequest = error.requestOptions.path.contains('/auth/');

          if (!isUnauthorized || isAuthRequest) {
            return handler.next(error);
          }

          if (alreadyRetried) {
            await _handleUnauthorized();
            return handler.next(error);
          }

          final refreshed = await _refreshAccessToken();

          if (!refreshed) {
            await _handleUnauthorized();
            return handler.next(error);
          }

          try {
            final requestOptions = error.requestOptions;
            final accessToken = await tokenStorage.accessToken;

            requestOptions.extra['retried'] = true;
            requestOptions.headers['Authorization'] = 'Bearer $accessToken';

            final response = await dio.fetch<dynamic>(requestOptions);
            return handler.resolve(response);
          } catch (_) {
            await _handleUnauthorized();
            return handler.next(error);
          }
        },
      ),
    );
  }

  Future<bool> _refreshAccessToken() {
    _refreshingToken ??= _doRefreshAccessToken();
    return _refreshingToken!.whenComplete(() => _refreshingToken = null);
  }

  Future<bool> _doRefreshAccessToken() async {
    final refreshToken = await tokenStorage.refreshToken;

    if (refreshToken == null || refreshToken.isEmpty) {
      return false;
    }

    try {
      final response = await _refreshDio.post<dynamic>(
        '/auth/refresh',
        options: Options(
          headers: {
            'Authorization': 'Bearer $refreshToken',
          },
        ),
      );

      final data = response.data;
      if (data is! Map) return false;

      final accessToken =
          data['accessToken'] ?? data['access_token'] ?? data['token'];
      final nextRefreshToken = data['refreshToken'] ?? data['refresh_token'];

      if (accessToken == null || accessToken.toString().isEmpty) {
        return false;
      }

      await tokenStorage.saveTokens(
        accessToken: accessToken.toString(),
        refreshToken: nextRefreshToken?.toString() ?? refreshToken,
      );

      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> _handleUnauthorized() async {
    await tokenStorage.clear();

    if (_unauthorizedNotified) return;
    _unauthorizedNotified = true;

    Future.microtask(() {
      onUnauthorized?.call();
      _unauthorizedNotified = false;
    });
  }
}
