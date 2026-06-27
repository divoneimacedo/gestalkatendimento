// import '../models/user.dart';
// import 'api/api_service.dart';
// import 'token_storage.dart';

// class AuthService {
//   final ApiService apiClient;
//   final TokenStorage storage;

//   AuthService(this.apiClient, this.storage);

//   Future<User> signIn({required String email, required String password, required String slug}) async {
//     await storage.saveSlug(slug);

//     final response = await apiClient.dio.post('/auth/local/signin', data: {
//       'email': email,
//       'password': password,
//     });

//     final data = response.data as Map<String, dynamic>;
//     final accessToken = data['access_token'] ?? data['accessToken'] ?? data['token'];
//     final refreshToken = data['refresh_token'] ?? data['refreshToken'];

//     if (accessToken == null) {
//       throw Exception('Login não retornou access_token. Ajuste o contrato em AuthService.');
//     }

//     await storage.saveTokens(accessToken: accessToken.toString(), refreshToken: refreshToken?.toString());

//     final userJson = (data['user'] ?? data['data']?['user'] ?? data) as Map<String, dynamic>;
//     return User.fromJson(userJson);
//   }

//   Future<void> logout() async {
//     await storage.clear();
//   }
// }
