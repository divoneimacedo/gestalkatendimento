class CallDetails {
  final String id;
  final String protocol;
  final String caller;
  final String meetingId;
  final String status;
  final DateTime? createdAt;
  final DateTime? startedAt;

  const CallDetails({
    required this.id,
    required this.protocol,
    required this.caller,
    required this.meetingId,
    required this.status,
    this.createdAt,
    this.startedAt,
  });

  factory CallDetails.fromJson(Map<String, dynamic> json) {
    return CallDetails(
      id: json['id']?.toString() ?? '',
      protocol: json['protocol']?.toString() ?? '',
      caller: json['caller']?.toString() ?? '',
      meetingId: json['meetingId']?.toString() ?? '',
      status: json['status']?.toString() ?? '',
      createdAt: _date(json['createdAt']),
      startedAt: _date(json['startedAt']),
    );
  }
}

DateTime? _date(dynamic value) {
  if (value is DateTime) return value;
  return DateTime.tryParse(value?.toString() ?? '');
}
