import 'package:dio/dio.dart';

import '../models/report_call.dart';
import '../models/report_metrics.dart';
import '../models/user.dart';
import 'api/api_service.dart';

class ReportFilters {
  final DateTime? startDate;
  final DateTime? endDate;
  final String? status;
  final String? search;
  final String? channelId;
  final String? attendantId;
  final String sortBy;
  final String sortOrder;

  const ReportFilters({
    this.startDate,
    this.endDate,
    this.status,
    this.search,
    this.channelId,
    this.attendantId,
    this.sortBy = 'createdAt',
    this.sortOrder = 'desc',
  });

  ReportFilters copyWith({
    DateTime? startDate,
    DateTime? endDate,
    String? status,
    String? search,
    String? channelId,
    String? attendantId,
    String? sortBy,
    String? sortOrder,
    bool clearStartDate = false,
    bool clearEndDate = false,
    bool clearStatus = false,
    bool clearSearch = false,
    bool clearChannel = false,
    bool clearAttendant = false,
  }) {
    return ReportFilters(
      startDate: clearStartDate ? null : startDate ?? this.startDate,
      endDate: clearEndDate ? null : endDate ?? this.endDate,
      status: clearStatus ? null : status ?? this.status,
      search: clearSearch ? null : search ?? this.search,
      channelId: clearChannel ? null : channelId ?? this.channelId,
      attendantId: clearAttendant ? null : attendantId ?? this.attendantId,
      sortBy: sortBy ?? this.sortBy,
      sortOrder: sortOrder ?? this.sortOrder,
    );
  }
}

class ReportOption {
  final String id;
  final String name;

  const ReportOption({
    required this.id,
    required this.name,
  });

  factory ReportOption.fromJson(Map<String, dynamic> json) {
    return ReportOption(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
    );
  }
}

class ReportFilterOptions {
  final List<ReportOption> channels;
  final List<ReportOption> interpreters;

  const ReportFilterOptions({
    required this.channels,
    required this.interpreters,
  });

  factory ReportFilterOptions.empty() {
    return const ReportFilterOptions(channels: [], interpreters: []);
  }

  factory ReportFilterOptions.fromJson(Map<String, dynamic> json) {
    return ReportFilterOptions(
      channels: _options(json['channels']),
      interpreters: _options(json['interpreters']),
    );
  }
}

class ReportService {
  final ApiService apiService;

  ReportService(this.apiService);

  Future<PaginatedReportCalls> getCalls({
    required User? user,
    required String slug,
    required ReportFilters filters,
    required int page,
    required int limit,
  }) async {
    final response = await apiService.dio.get<dynamic>(
      '/reports/calls',
      queryParameters: _queryParameters(
        user: user,
        slug: slug,
        filters: filters,
        page: page,
        limit: limit,
      ),
    );

    final data = _responseMap(response);
    return PaginatedReportCalls.fromJson(data);
  }

  Future<ReportMetrics> getMetrics({
    required User? user,
    required String slug,
    required ReportFilters filters,
  }) async {
    final response = await apiService.dio.get<dynamic>(
      '/reports/metrics',
      queryParameters: _queryParameters(
        user: user,
        slug: slug,
        filters: filters,
      ),
    );

    return ReportMetrics.fromJson(_responseMap(response));
  }

  Future<ReportFilterOptions> getFilterOptions() async {
    final response = await apiService.dio.get<dynamic>('/reports/filters');
    return ReportFilterOptions.fromJson(_responseMap(response));
  }

  Future<List<ReportCall>> getAllCallsForExport({
    required User? user,
    required String slug,
    required ReportFilters filters,
  }) async {
    final response = await apiService.dio.get<dynamic>(
      '/reports/calls',
      queryParameters: _queryParameters(
        user: user,
        slug: slug,
        filters: filters,
        page: 1,
        limit: 99999,
      ),
    );

    return PaginatedReportCalls.fromJson(_responseMap(response)).calls;
  }

  Map<String, dynamic> _queryParameters({
    required User? user,
    required String slug,
    required ReportFilters filters,
    int? page,
    int? limit,
  }) {
    final params = <String, dynamic>{};

    if (filters.startDate != null) {
      params['startDate'] = _date(filters.startDate!);
    }

    if (filters.endDate != null) {
      params['endDate'] = _date(filters.endDate!);
    }

    if (filters.status != null && filters.status!.isNotEmpty) {
      params['status'] = filters.status;
    }

    if (filters.channelId != null && filters.channelId!.isNotEmpty) {
      params['channelId'] = filters.channelId;
    }

    if (filters.attendantId != null && filters.attendantId!.isNotEmpty) {
      params['attendantId'] = filters.attendantId;
    }

    if (slug != 'gestalk' && (user?.companyId.isNotEmpty ?? false)) {
      params['companyId'] = user!.companyId;
    }

    if (page != null) params['page'] = page;
    if (limit != null) params['limit'] = limit;

    if (filters.search != null && filters.search!.trim().isNotEmpty) {
      params['search'] = filters.search!.trim();
    }

    params['sortBy'] = filters.sortBy;
    params['sortOrder'] = filters.sortOrder;

    return params;
  }

  String _date(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }

  Map<String, dynamic> _responseMap(Response<dynamic> response) {
    final data = response.data;
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return Map<String, dynamic>.from(data);
    return <String, dynamic>{};
  }
}

List<ReportOption> _options(dynamic value) {
  if (value is! List) return const [];

  return value
      .whereType<Map>()
      .map((item) => ReportOption.fromJson(Map<String, dynamic>.from(item)))
      .where((item) => item.id.isNotEmpty)
      .toList();
}
