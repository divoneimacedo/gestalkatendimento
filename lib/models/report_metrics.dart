class ReportMetrics {
  final int totalCalls;
  final int attendedRate;
  final int attendedCount;
  final int notAttendedCount;
  final String tmaMin;
  final String tmaAvg;
  final String tmaMax;
  final int tmaMinSeconds;
  final int tmaAvgSeconds;
  final int tmaMaxSeconds;
  final String tmeAvg;
  final int tmeAvgSeconds;
  final String tmoAvg;
  final int tmoAvgSeconds;
  final Map<String, int> statusDistribution;
  final List<CallsByDayMetric> callsByDay;
  final List<InterpreterPerformanceMetric> interpretersPerformance;

  ReportMetrics({
    required this.totalCalls,
    required this.attendedRate,
    required this.attendedCount,
    required this.notAttendedCount,
    required this.tmaMin,
    required this.tmaAvg,
    required this.tmaMax,
    required this.tmaMinSeconds,
    required this.tmaAvgSeconds,
    required this.tmaMaxSeconds,
    required this.tmeAvg,
    required this.tmeAvgSeconds,
    required this.tmoAvg,
    required this.tmoAvgSeconds,
    required this.statusDistribution,
    required this.callsByDay,
    required this.interpretersPerformance,
  });

  factory ReportMetrics.empty() {
    return ReportMetrics(
      totalCalls: 0,
      attendedRate: 0,
      attendedCount: 0,
      notAttendedCount: 0,
      tmaMin: '0m 0s',
      tmaAvg: '0m 0s',
      tmaMax: '0m 0s',
      tmaMinSeconds: 0,
      tmaAvgSeconds: 0,
      tmaMaxSeconds: 0,
      tmeAvg: '0m 0s',
      tmeAvgSeconds: 0,
      tmoAvg: '0m 0s',
      tmoAvgSeconds: 0,
      statusDistribution: const {},
      callsByDay: const [],
      interpretersPerformance: const [],
    );
  }

  factory ReportMetrics.fromJson(Map<String, dynamic> json) {
    final tma = _map(json['tma']);
    final tme = _map(json['tme']);
    final tmo = _map(json['tmo']);
    final distribution = _map(json['statusDistribution']);

    return ReportMetrics(
      totalCalls: _int(json['totalCalls']),
      attendedRate: _int(json['attendedRate']),
      attendedCount: _int(json['attendedCount']),
      notAttendedCount: _int(json['notAttendedCount']),
      tmaMin: _string(tma['min'], '0m 0s'),
      tmaAvg: _string(tma['avg'], '0m 0s'),
      tmaMax: _string(tma['max'], '0m 0s'),
      tmaMinSeconds: _int(tma['minSeconds']),
      tmaAvgSeconds: _int(tma['avgSeconds']),
      tmaMaxSeconds: _int(tma['maxSeconds']),
      tmeAvg: _string(tme['avg'], '0m 0s'),
      tmeAvgSeconds: _int(tme['avgSeconds']),
      tmoAvg: _string(tmo['avg'], '0m 0s'),
      tmoAvgSeconds: _int(tmo['avgSeconds']),
      statusDistribution: distribution.map(
        (key, value) => MapEntry(key, _int(value)),
      ),
      callsByDay:
          _list(json['callsByDay']).map(CallsByDayMetric.fromJson).toList(),
      interpretersPerformance: _list(json['interpretersPerformance'])
          .map(InterpreterPerformanceMetric.fromJson)
          .toList(),
    );
  }
}

class CallsByDayMetric {
  final String date;
  final int attended;
  final int notAttended;

  const CallsByDayMetric({
    required this.date,
    required this.attended,
    required this.notAttended,
  });

  factory CallsByDayMetric.fromJson(Map<String, dynamic> json) {
    return CallsByDayMetric(
      date: _string(json['date'], '-'),
      attended: _int(json['attended']),
      notAttended: _int(json['notAttended']),
    );
  }
}

class InterpreterPerformanceMetric {
  final String name;
  final int totalCalls;
  final double totalHours;
  final String avgTMA;

  const InterpreterPerformanceMetric({
    required this.name,
    required this.totalCalls,
    required this.totalHours,
    required this.avgTMA,
  });

  factory InterpreterPerformanceMetric.fromJson(Map<String, dynamic> json) {
    return InterpreterPerformanceMetric(
      name: _string(json['name'], '-'),
      totalCalls: _int(json['totalCalls']),
      totalHours: _double(json['totalHours']),
      avgTMA: _string(json['avgTMA'], '0m 0s'),
    );
  }
}

Map<String, dynamic> _map(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  return <String, dynamic>{};
}

String _string(dynamic value, String fallback) {
  final text = value?.toString();
  if (text == null || text.isEmpty) return fallback;
  return text;
}

int _int(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

double _double(dynamic value) {
  if (value is double) return value;
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? 0;
}

List<Map<String, dynamic>> _list(dynamic value) {
  if (value is! List) return const [];

  return value
      .whereType<Map>()
      .map((item) => Map<String, dynamic>.from(item))
      .toList();
}
