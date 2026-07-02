class AdminDashboardStats {
  final int totalCalls;
  final int callsInProgress;
  final int callsWaiting;
  final int totalCompanies;
  final int totalUsers;
  final int totalChannels;

  const AdminDashboardStats({
    required this.totalCalls,
    required this.callsInProgress,
    required this.callsWaiting,
    required this.totalCompanies,
    required this.totalUsers,
    required this.totalChannels,
  });

  factory AdminDashboardStats.fromJson(Map<String, dynamic> json) {
    return AdminDashboardStats(
      totalCalls: _int(json['totalCalls']),
      callsInProgress: _int(json['callsInProgress']),
      callsWaiting: _int(json['callsWaiting']),
      totalCompanies: _int(json['totalCompanies']),
      totalUsers: _int(json['totalUsers']),
      totalChannels: _int(json['totalChannels']),
    );
  }
}

int _int(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}
