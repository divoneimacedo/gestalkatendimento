import 'package:flutter/foundation.dart';

import '../models/report_call.dart';
import '../models/report_metrics.dart';
import '../models/user.dart';
import '../services/report_service.dart';

class ReportsController extends ChangeNotifier {
  final ReportService reportService;

  ReportsController({required this.reportService});

  List<ReportCall> calls = [];
  ReportMetrics metrics = ReportMetrics.empty();
  ReportFilterOptions filterOptions = ReportFilterOptions.empty();
  ReportFilters filters = _defaultWeekFilters();
  bool loading = false;
  bool loadingOptions = false;
  bool exporting = false;
  String? error;
  int page = 1;
  int limit = 10;
  int total = 0;
  int totalPages = 1;

  bool get canGoPrevious => page > 1 && !loading;
  bool get canGoNext => page < totalPages && !loading;

  Future<void> loadOptions() async {
    if (loadingOptions || filterOptions.channels.isNotEmpty) return;

    loadingOptions = true;
    notifyListeners();

    try {
      filterOptions = await reportService.getFilterOptions();
    } catch (_) {
      // Os relatórios continuam funcionando sem os filtros auxiliares.
    } finally {
      loadingOptions = false;
      notifyListeners();
    }
  }

  Future<void> load({
    required User? user,
    required String slug,
    bool resetPage = false,
  }) async {
    if (resetPage) page = 1;

    loading = true;
    error = null;
    notifyListeners();

    try {
      final results = await Future.wait([
        reportService.getMetrics(user: user, slug: slug, filters: filters),
        reportService.getCalls(
          user: user,
          slug: slug,
          filters: filters,
          page: page,
          limit: limit,
        ),
      ]);

      metrics = results[0] as ReportMetrics;
      final paginatedCalls = results[1] as PaginatedReportCalls;
      calls = paginatedCalls.calls;
      total = paginatedCalls.total;
      page = paginatedCalls.page;
      limit = paginatedCalls.limit == 0 ? limit : paginatedCalls.limit;
      totalPages =
          paginatedCalls.totalPages == 0 ? 1 : paginatedCalls.totalPages;
    } catch (exception) {
      error = _friendlyError(exception);
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<List<ReportCall>> exportCalls({
    required User? user,
    required String slug,
  }) async {
    exporting = true;
    error = null;
    notifyListeners();

    try {
      return await reportService.getAllCallsForExport(
        user: user,
        slug: slug,
        filters: filters,
      );
    } catch (exception) {
      error = _friendlyError(exception);
      rethrow;
    } finally {
      exporting = false;
      notifyListeners();
    }
  }

  Future<void> refresh({required User? user, required String slug}) {
    return load(user: user, slug: slug);
  }

  Future<void> applyFilters({
    required User? user,
    required String slug,
    DateTime? startDate,
    DateTime? endDate,
    String? status,
    String? search,
    String? channelId,
    String? attendantId,
    bool clearStartDate = false,
    bool clearEndDate = false,
    bool clearStatus = false,
    bool clearSearch = false,
    bool clearChannel = false,
    bool clearAttendant = false,
  }) {
    filters = filters.copyWith(
      startDate: startDate,
      endDate: endDate,
      status: status,
      search: search,
      channelId: channelId,
      attendantId: attendantId,
      clearStartDate: clearStartDate,
      clearEndDate: clearEndDate,
      clearStatus: clearStatus,
      clearSearch: clearSearch,
      clearChannel: clearChannel,
      clearAttendant: clearAttendant,
    );
    return load(user: user, slug: slug, resetPage: true);
  }

  Future<void> sort({
    required User? user,
    required String slug,
    required String sortBy,
  }) {
    final nextOrder =
        filters.sortBy == sortBy && filters.sortOrder == 'asc' ? 'desc' : 'asc';

    filters = filters.copyWith(sortBy: sortBy, sortOrder: nextOrder);
    return load(user: user, slug: slug, resetPage: true);
  }

  Future<void> nextPage({required User? user, required String slug}) {
    if (!canGoNext) return Future.value();
    page += 1;
    return load(user: user, slug: slug);
  }

  Future<void> previousPage({required User? user, required String slug}) {
    if (!canGoPrevious) return Future.value();
    page -= 1;
    return load(user: user, slug: slug);
  }

  String _friendlyError(Object exception) {
    final message = exception.toString();

    if (message.contains('403') || message.contains('Forbidden')) {
      return 'Seu usuário não tem permissão para acessar os relatórios.';
    }

    if (message.contains('401')) {
      return 'Sua sessão expirou. Faça login novamente.';
    }

    return 'Não foi possível carregar os relatórios agora.';
  }
}

ReportFilters _defaultWeekFilters() {
  final now = DateTime.now();
  final start = DateTime(now.year, now.month, now.day - 6);
  final end = DateTime(now.year, now.month, now.day);

  return ReportFilters(startDate: start, endDate: end);
}
