import 'package:flutter/foundation.dart';

import '../core/exceptions/api_exception.dart';
import '../models/user.dart';
import '../repositories/auth/auth_repository.dart';

class AuthController extends ChangeNotifier {
  final AuthRepository repository;

  User? user;
  String? slug;
  bool loading = false;
  String? error;

  AuthController(this.repository);

  bool get isAuthenticated => user != null;

  Future<void> restoreSession() async {
    loading = true;
    error = null;
    notifyListeners();

    try {
      user = await repository.getSavedUser();
      slug = await repository.getSavedSlug();
    } catch (e) {
      error = 'Erro ao recuperar sessão salva.';
      debugPrint('ERRO RESTAURAR SESSAO: $e');
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<String?> getSavedSlug() {
    return repository.getSavedSlug();
  }

  Future<void> signIn({
    required String userName,
    required String password,
    required String slug,
  }) async {
    loading = true;
    error = null;
    notifyListeners();

    try {
      user = await repository.login(
        userName: userName,
        password: password,
        slug: slug,
      );
      this.slug = slug;
    } on ApiException catch (e) {
      error = e.message;
    } catch (e) {
      error = 'Erro inesperado ao fazer login.';
      debugPrint('ERRO GERAL LOGIN: $e');
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    await repository.logout();
    user = null;
    slug = null;
    notifyListeners();
  }

  Future<void> updateStoredUser(User nextUser) async {
    user = nextUser;
    await repository.saveUser(nextUser);
    notifyListeners();
  }
}
