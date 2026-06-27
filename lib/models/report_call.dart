class ReportCall {
  final String id;
  final String protocol;
  final String company;
  final String channel;
  final String status;
  final DateTime? startTime;
  final DateTime? endTime;
  final String? caller;
  final String? attendant;
  final String? tme;
  final String? tma;
  final String? tmo;

  ReportCall({
    required this.id,
    required this.protocol,
    required this.company,
    required this.channel,
    required this.status,
    this.startTime,
    this.endTime,
    this.caller,
    this.attendant,
    this.tme,
    this.tma,
    this.tmo,
  });

  factory ReportCall.fromJson(Map<String, dynamic> json) {
    return ReportCall(
      id: _string(json['id']),
      protocol: _string(json['protocol']),
      company: _string(json['Company']),
      channel: _string(json['Channel']),
      status: _string(json['Status']),
      startTime: _date(json['Start time']),
      endTime: _date(json['End time']),
      caller: _nullableString(json['Caller']),
      attendant: _nullableString(json['Attendant']),
      tme: _nullableString(json['TME']),
      tma: _nullableString(json['TMA']),
      tmo: _nullableString(json['TMO'] ?? json['Duration']),
    );
  }
}

class PaginatedReportCalls {
  final List<ReportCall> calls;
  final int total;
  final int page;
  final int limit;
  final int totalPages;

  PaginatedReportCalls({
    required this.calls,
    required this.total,
    required this.page,
    required this.limit,
    required this.totalPages,
  });

  factory PaginatedReportCalls.fromJson(Map<String, dynamic> json) {
    final pagination = json['pagination'];
    final paginationMap = pagination is Map
        ? Map<String, dynamic>.from(pagination)
        : <String, dynamic>{};
    final results = json['results'];
    final calls = results is List
        ? results
            .whereType<Map>()
            .map((item) => ReportCall.fromJson(Map<String, dynamic>.from(item)))
            .toList()
        : <ReportCall>[];

    return PaginatedReportCalls(
      calls: calls,
      total: _int(paginationMap['total'], calls.length),
      page: _int(paginationMap['page'], 1),
      limit: _int(paginationMap['limit'], calls.length),
      totalPages: _int(paginationMap['totalPages'], 1),
    );
  }
}

String _string(dynamic value) => value?.toString() ?? '';

String? _nullableString(dynamic value) {
  final text = value?.toString();
  if (text == null || text.isEmpty) return null;
  return text;
}

int _int(dynamic value, int fallback) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? fallback;
}

DateTime? _date(dynamic value) {
  if (value == null) return null;
  return DateTime.tryParse(value.toString());
}
