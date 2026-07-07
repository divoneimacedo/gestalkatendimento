import 'dart:async';

import 'package:flutter/foundation.dart';

import '../core/exceptions/api_exception.dart';
import '../models/managed_user.dart';
import '../services/users_service.dart';

class UsersController extends ChangeNotifier {
  final UsersService usersService;

  UsersController({required this.usersService});

  Timer? _searchDebounce;
  List<ManagedUser> users = [];
  String searchTerm = '';
  bool loading = false;
  bool showBlockedOnly = false;
  String? error;
  int total = 0;
  int page = 1;
  int limit = 20;
  int totalPages = 1;

  bool get canGoPrevious => page > 1 && !loading;
  bool get canGoNext => page < totalPages && !loading;
  List<ManagedUser> get filteredUsers => users;

  Future<void> load({
    required String slug,
    String? companyId,
    bool resetPage = false,
  }) async {
    if (resetPage) page = 1;

    loading = true;
    error = null;
    users = [];
    notifyListeners();

    try {
      final result = await usersService.fetchUsers(
        slug: slug,
        blockedOnly: showBlockedOnly,
        page: page,
        limit: limit,
        search: companyId == null || companyId.isEmpty ? searchTerm : '',
        companyId: companyId,
      );

      users = result.users;
      total = result.total;
      page = result.page;
      limit = result.limit;
      totalPages = result.totalPages == 0 ? 1 : result.totalPages;
    } on ApiException catch (exception) {
      error = exception.message;
    } catch (_) {
      error = 'Erro ao carregar usuários.';
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> refresh({required String slug, String? companyId}) {
    return load(slug: slug, companyId: companyId);
  }

  Future<void> setBlockedOnly({
    required String slug,
    required bool value,
    String? companyId,
  }) async {
    showBlockedOnly = value;
    await load(slug: slug, companyId: companyId, resetPage: true);
  }

  void setSearchTerm({
    required String slug,
    required String value,
    String? companyId,
  }) {
    searchTerm = value;
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 450), () {
      load(slug: slug, companyId: companyId, resetPage: true);
    });
    notifyListeners();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    super.dispose();
  }

  Future<void> nextPage({required String slug, String? companyId}) async {
    if (!canGoNext) return;
    page += 1;
    await load(slug: slug, companyId: companyId);
  }

  Future<void> previousPage({required String slug, String? companyId}) async {
    if (!canGoPrevious) return;
    page -= 1;
    await load(slug: slug, companyId: companyId);
  }

  Future<void> firstPage({required String slug, String? companyId}) async {
    if (page == 1 || loading) return;
    page = 1;
    await load(slug: slug, companyId: companyId);
  }

  Future<void> lastPage({required String slug, String? companyId}) async {
    if (page == totalPages || loading) return;
    page = totalPages;
    await load(slug: slug, companyId: companyId);
  }

  Future<void> updateUser({
    required String slug,
    required ManagedUser user,
  }) async {
    await usersService.updateUser(user);
    await load(slug: slug);
  }

  Future<void> toggleBlock({
    required String slug,
    required ManagedUser user,
  }) async {
    if (user.isBlock) {
      await usersService.unblockUser(user.id);
    } else {
      await usersService.blockUser(user.id);
    }
    await load(slug: slug);
  }

  Future<void> deleteUser({
    required String slug,
    required ManagedUser user,
  }) async {
    await usersService.deleteUser(user.id);
    await load(slug: slug);
  }

  Future<void> sendNotification({
    required ManagedUser user,
    required String message,
  }) {
    return usersService.sendNotification(
      userId: user.id,
      message: message,
    );
  }
}
