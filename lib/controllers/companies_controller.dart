import 'dart:async';

import 'package:flutter/foundation.dart';

import '../core/exceptions/api_exception.dart';
import '../models/company.dart';
import '../services/companies_service.dart';

class CompaniesController extends ChangeNotifier {
  final CompaniesService companiesService;

  CompaniesController({required this.companiesService});

  Timer? _searchDebounce;
  List<Company> companies = [];
  String searchTerm = '';
  bool loading = false;
  String? error;
  int total = 0;
  int page = 1;
  int limit = 20;
  int totalPages = 1;

  bool get canGoPrevious => page > 1 && !loading;
  bool get canGoNext => page < totalPages && !loading;

  Future<void> load({
    required String slug,
    bool resetPage = false,
  }) async {
    if (resetPage) page = 1;

    loading = true;
    error = null;
    notifyListeners();

    try {
      final result = await companiesService.fetchCompanies(
        slug: slug,
        page: page,
        limit: limit,
        search: searchTerm,
      );

      companies = result.companies;
      total = result.total;
      page = result.page;
      limit = result.limit;
      totalPages = result.totalPages == 0 ? 1 : result.totalPages;
    } on ApiException catch (exception) {
      error = exception.message;
    } catch (_) {
      error = 'Erro ao carregar empresas.';
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> refresh({required String slug}) {
    return load(slug: slug);
  }

  void setSearchTerm({
    required String slug,
    required String value,
  }) {
    searchTerm = value;
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 450), () {
      load(slug: slug, resetPage: true);
    });
    notifyListeners();
  }

  Future<void> nextPage({required String slug}) async {
    if (!canGoNext) return;
    page += 1;
    await load(slug: slug);
  }

  Future<void> previousPage({required String slug}) async {
    if (!canGoPrevious) return;
    page -= 1;
    await load(slug: slug);
  }

  Future<void> firstPage({required String slug}) async {
    if (page == 1 || loading) return;
    page = 1;
    await load(slug: slug);
  }

  Future<void> lastPage({required String slug}) async {
    if (page == totalPages || loading) return;
    page = totalPages;
    await load(slug: slug);
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    super.dispose();
  }
}
