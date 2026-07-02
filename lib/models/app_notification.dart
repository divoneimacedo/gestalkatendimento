class AppNotification {
  final String id;
  final String title;
  final String message;
  final String type;
  final String status;
  final String? videoUrl;
  final Map<String, dynamic>? data;
  final DateTime? createdAt;
  final DateTime? readAt;

  const AppNotification({
    required this.id,
    required this.title,
    required this.message,
    required this.type,
    required this.status,
    this.videoUrl,
    this.data,
    this.createdAt,
    this.readAt,
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    final rawData = json['data'];

    return AppNotification(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? 'Notificacao',
      message: json['message']?.toString() ?? '',
      type: json['type']?.toString() ?? '',
      status: json['status']?.toString() ?? '',
      videoUrl: _nullableString(json['videoUrl']),
      data: rawData is Map ? Map<String, dynamic>.from(rawData) : null,
      createdAt: _date(json['createdAt']),
      readAt: _date(json['readAt']),
    );
  }

  AppNotification copyWith({
    String? id,
    String? title,
    String? message,
    String? type,
    String? status,
    String? videoUrl,
    Map<String, dynamic>? data,
    DateTime? createdAt,
    DateTime? readAt,
  }) {
    return AppNotification(
      id: id ?? this.id,
      title: title ?? this.title,
      message: message ?? this.message,
      type: type ?? this.type,
      status: status ?? this.status,
      videoUrl: videoUrl ?? this.videoUrl,
      data: data ?? this.data,
      createdAt: createdAt ?? this.createdAt,
      readAt: readAt ?? this.readAt,
    );
  }

  bool get isUnread => status != 'READ';
}

String? _nullableString(dynamic value) {
  final text = value?.toString();
  if (text == null || text.isEmpty) return null;
  return text;
}

DateTime? _date(dynamic value) {
  if (value == null) return null;
  return DateTime.tryParse(value.toString());
}
