import 'dart:async';

import 'package:flutter/foundation.dart';

import '../core/exceptions/api_exception.dart';
import '../models/interpreter.dart';
import '../services/interpreters_service.dart';

class InterpretersController extends ChangeNotifier {
  final InterpretersService interpretersService;

  InterpretersController({required this.interpretersService});

  Timer? _searchDebounce;
  List<InterpreterListItem> interpreters = [];
  String statusFilter = 'all';
  String searchTerm = '';
  bool loading = false;
  String? error;
  int total = 0;
  int page = 1;
  int limit = 10;
  int totalPages = 1;

  bool get canGoPrevious => page > 1 && !loading;
  bool get canGoNext => page < totalPages && !loading;

  Future<void> load({bool resetPage = false}) async {
    if (resetPage) page = 1;

    loading = true;
    error = null;
    notifyListeners();

    try {
      final result = await interpretersService.fetchInterpreters(
        page: page,
        limit: limit,
        status: statusFilter,
        search: searchTerm,
      );

      interpreters = result.interpreters;
      total = result.total;
      page = result.page;
      limit = result.limit;
      totalPages = result.totalPages == 0 ? 1 : result.totalPages;
    } on ApiException catch (exception) {
      error = exception.message;
    } catch (_) {
      error = 'Erro ao carregar intérpretes.';
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> refresh() {
    return load();
  }

  Future<void> setStatusFilter(String value) async {
    statusFilter = value;
    await load(resetPage: true);
  }

  void setSearchTerm(String value) {
    searchTerm = value;
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 450), () {
      load(resetPage: true);
    });
    notifyListeners();
  }

  Future<void> nextPage() async {
    if (!canGoNext) return;
    page += 1;
    await load();
  }

  Future<void> previousPage() async {
    if (!canGoPrevious) return;
    page -= 1;
    await load();
  }

  Future<void> firstPage() async {
    if (page == 1 || loading) return;
    page = 1;
    await load();
  }

  Future<void> lastPage() async {
    if (page == totalPages || loading) return;
    page = totalPages;
    await load();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    super.dispose();
  }
}
