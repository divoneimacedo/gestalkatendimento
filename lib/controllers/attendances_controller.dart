import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/attendance_call.dart';
import '../services/attendance_service.dart';

class AttendancesController extends ChangeNotifier {
  final AttendanceService attendanceService;

  AttendancesController({required this.attendanceService});

  Timer? _searchDebounce;
  List<AttendanceCall> calls = [];
  bool loading = false;
  String? error;
  String status = 'ALL';
  String searchTerm = '';
  int page = 1;
  int limit = 25;
  int total = 0;
  int totalPages = 1;

  bool get canGoPrevious => page > 1 && !loading;
  bool get canGoNext => page < totalPages && !loading;

  Future<void> load({required String slug, int page = 1}) async {
    loading = true;
    error = null;
    calls = [];
    notifyListeners();

    try {
      final result = await attendanceService.getCalls(
        slug: slug,
        page: page,
        limit: limit,
        status: status,
        search: searchTerm,
      );
      _applyResult(result);
    } catch (e) {
      error = e.toString();
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> refresh({required String slug}) async {
    loading = true;
    error = null;
    calls = [];
    notifyListeners();

    try {
      final result = await attendanceService.getCalls(
        slug: slug,
        page: page,
        limit: limit,
        status: status,
        search: searchTerm,
      );
      _applyResult(result);
    } catch (e) {
      error = e.toString();
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> nextPage({required String slug}) async {
    if (!canGoNext) return;
    await load(slug: slug, page: page + 1);
  }

  Future<void> previousPage({required String slug}) async {
    if (!canGoPrevious) return;
    await load(slug: slug, page: page - 1);
  }

  Future<void> firstPage({required String slug}) async {
    if (!canGoPrevious) return;
    await load(slug: slug, page: 1);
  }

  Future<void> lastPage({required String slug}) async {
    if (!canGoNext) return;
    await load(slug: slug, page: totalPages);
  }

  Future<void> setStatus({required String slug, required String value}) async {
    status = value;
    await load(slug: slug, page: 1);
  }

  void setSearchTerm({required String slug, required String value}) {
    searchTerm = value;
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 450), () {
      load(slug: slug, page: 1);
    });
    notifyListeners();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    super.dispose();
  }

  void _applyResult(PaginatedAttendances result) {
    calls = result.calls;
    total = result.total;
    page = result.page;
    limit = result.limit;
    totalPages = result.totalPages;
  }
}
