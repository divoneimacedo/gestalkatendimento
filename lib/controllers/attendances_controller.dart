import 'package:flutter/foundation.dart';

import '../models/attendance_call.dart';
import '../services/attendance_service.dart';

class AttendancesController extends ChangeNotifier {
  final AttendanceService attendanceService;

  AttendancesController({required this.attendanceService});

  List<AttendanceCall> calls = [];
  bool loading = false;
  String? error;
  int page = 1;
  int limit = 25;
  int total = 0;
  int totalPages = 1;

  bool get canGoPrevious => page > 1 && !loading;
  bool get canGoNext => page < totalPages && !loading;

  Future<void> load({required String slug, int page = 1}) async {
    loading = true;
    error = null;
    notifyListeners();

    try {
      final result = await attendanceService.getCalls(
        slug: slug,
        page: page,
        limit: limit,
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
    notifyListeners();

    try {
      final result = await attendanceService.getCalls(
        slug: slug,
        page: page,
        limit: limit,
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

  void _applyResult(PaginatedAttendances result) {
    calls = result.calls;
    total = result.total;
    page = result.page;
    limit = result.limit;
    totalPages = result.totalPages;
  }
}
