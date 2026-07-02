import 'package:dio/dio.dart';

import '../../core/config/app_config.dart';
import '../../core/exceptions/api_exception.dart';
import '../../models/user.dart';
import '../../services/api/api_service.dart';
import '../../services/storage/token_storage.dart';

class LoginCompanyOption {
  final String name;
  final String slug;

  const LoginCompanyOption({
    required this.name,
    required this.slug,
  });
}

class AuthRepository {
  final ApiService apiService;
  final TokenStorage tokenStorage;

  AuthRepository({
    required this.apiService,
    required this.tokenStorage,
  });

  Future<User> login({
    required String userName,
    required String password,
    required String slug,
  }) async {
    try {
      final response = await apiService.dio.post(
        '/auth/local/signin',
        data: {
          'username': userName,
          'password': password,
          'slug': slug,
        },
      );

      final data = response.data;
      if (data is Map && data['error'] != null) {
        String errorMessage = _translateLoginError(data['error'].toString());
        throw ApiException(
          errorMessage,
          data: data,
        );
      }

      final accessToken =
          data['accessToken'] ?? data['access_token'] ?? data['token'];

      final refreshToken = data['refreshToken'] ?? data['refresh_token'];

      if (accessToken == null || accessToken.toString().isEmpty) {
        throw ApiException('Token não retornado pela API', data: data);
      }

      final userJson = data['user'] ?? data['usuario'] ?? data;
      final user = User.fromJson(Map<String, dynamic>.from(userJson));

      await tokenStorage.saveTokens(
        accessToken: accessToken.toString(),
        refreshToken: refreshToken?.toString(),
      );
      await tokenStorage.saveSlug(slug);
      await tokenStorage.saveUser(user);

      return user;
    } on DioException catch (e) {
      throw ApiException(
        _extractDioErrorMessage(e),
        statusCode: e.response?.statusCode,
        data: e.response?.data,
      );
    }
  }

  Future<List<LoginCompanyOption>> fetchLoginCompanies() async {
    try {
      final appToken = AppConfig.loginCompaniesToken.trim();
      if (appToken.isEmpty) {
        throw ApiException(
          'Token de listagem de empresas não configurado no app. Defina LOGIN_COMPANIES_TOKEN.',
        );
      }

      final response = await apiService.dio.get<dynamic>(
        '/company/public/login-companies',
        options: Options(
          headers: {
            'x-app-token': appToken,
          },
        ),
      );

      final data = response.data;
      final rawCompanies = data is Map ? data['companies'] : null;

      if (rawCompanies is! List) return [];

      final options = rawCompanies
          .whereType<Map>()
          .map((company) {
            final name = company['name']?.toString() ?? '';
            final slug = company['slug']?.toString() ?? '';

            if (name.isEmpty || slug.isEmpty) return null;

            return LoginCompanyOption(name: name, slug: slug);
          })
          .whereType<LoginCompanyOption>()
          .toList();

      options.sort((a, b) => a.name.compareTo(b.name));
      return options;
    } on ApiException {
      rethrow;
    } on DioException catch (e) {
      throw ApiException(
        _extractDioErrorMessage(e),
        statusCode: e.response?.statusCode,
        data: e.response?.data,
      );
    }
  }

  Future<void> logout() async {
    await tokenStorage.clear();
  }

  Future<User?> getSavedUser() {
    return tokenStorage.getUser();
  }

  Future<void> saveUser(User user) {
    return tokenStorage.saveUser(user);
  }

  Future<String?> getSavedSlug() {
    return tokenStorage.getSlug();
  }

  String _extractDioErrorMessage(DioException error) {
    final data = error.response?.data;

    if (data is Map) {
      if (data['error'] != null) {
        String errorMessage = _translateLoginError(data['error'].toString());
        return errorMessage;
      }

      if (data['message'] != null) {
        return _translateLoginError(data['message'].toString());
      }
    }

    if (error.response?.statusCode == 401) {
      return 'Usuário ou senha inválidos.';
    }

    return 'Erro na API: ${error.response?.statusCode ?? error.message}';
  }

  String _translateLoginError(String message) {
    final normalized = message.trim().toLowerCase();

    if (normalized.startsWith('incorrect password. you have')) {
      final attempts = RegExp(r'you have (\d+) more attempt')
          .firstMatch(normalized)
          ?.group(1);

      if (attempts == null) return 'Senha incorreta.';

      return attempts == '1'
          ? 'Senha incorreta. Você tem mais 1 tentativa.'
          : 'Senha incorreta. Você tem mais $attempts tentativas.';
    }

    const translatedMessages = {
      'company not found': 'Empresa não encontrada.',
      'invalid credentials': 'Usuário ou senha inválidos.',
      'user or password incorrect': 'Usuário ou senha inválidos.',
      'invalid username or password': 'Usuário ou senha inválidos.',
      'invalid email or password': 'Usuário ou senha inválidos.',
      'unauthorized': 'Usuário ou senha inválidos.',
      'unauthorized user': 'Usuário não autorizado.',
      'user not found': 'Usuário não encontrado.',
      'user account is inactive': 'Conta inativa.',
      'account disabled': 'Conta desativada.',
      'account blocked due to multiple failed login attempts. please contact support.':
          'Conta bloqueada por muitas tentativas. Entre em contato com o suporte.',
      'forbidden': 'Você não tem permissão para acessar este sistema.',
    };

    return translatedMessages[normalized] ?? message;
  }
}
