class CallDetails {
  final String id;
  final String protocol;
  final String caller;
  final String meetingId;
  final String status;
  final String ip;
  final String device;
  final String channelId;
  final String companyId;
  final bool recordingConsentAccepted;
  final DateTime? createdAt;
  final DateTime? startedAt;
  final DateTime? endedAt;
  final DateTime? recordingConsentAcceptedAt;
  final List<CallReview> reviews;

  const CallDetails({
    required this.id,
    required this.protocol,
    required this.caller,
    required this.meetingId,
    required this.status,
    this.ip = '',
    this.device = '',
    this.channelId = '',
    this.companyId = '',
    this.recordingConsentAccepted = false,
    this.createdAt,
    this.startedAt,
    this.endedAt,
    this.recordingConsentAcceptedAt,
    this.reviews = const [],
  });

  factory CallDetails.fromJson(Map<String, dynamic> json, {dynamic reviews}) {
    return CallDetails(
      id: json['id']?.toString() ?? '',
      protocol: json['protocol']?.toString() ?? '',
      caller: json['caller']?.toString() ?? '',
      meetingId: json['meetingId']?.toString() ?? '',
      status: json['status']?.toString() ?? '',
      ip: json['ip']?.toString() ?? '',
      device: json['device']?.toString() ?? '',
      channelId: json['channelId']?.toString() ?? '',
      companyId: json['companyId']?.toString() ?? '',
      recordingConsentAccepted: _bool(json['recordingConsentAccepted']),
      createdAt: _date(json['createdAt']),
      startedAt: _date(json['startedAt']),
      endedAt: _date(json['endedAt']),
      recordingConsentAcceptedAt: _date(json['recordingConsentAcceptedAt']),
      reviews: _reviewsFrom(reviews ?? json['reviews']),
    );
  }

  Duration? get duration {
    final start = startedAt ?? createdAt;
    final end = endedAt;
    if (start == null || end == null) return null;
    return end.difference(start);
  }
}

class CallReview {
  final String id;
  final String userId;
  final String callId;
  final int rating;
  final String description;
  final DateTime? createdAt;

  const CallReview({
    required this.id,
    required this.userId,
    required this.callId,
    required this.rating,
    required this.description,
    this.createdAt,
  });

  factory CallReview.fromJson(Map<String, dynamic> json) {
    return CallReview(
      id: json['id']?.toString() ?? '',
      userId: json['userId']?.toString() ?? '',
      callId: json['callId']?.toString() ?? '',
      rating: _int(json['rating']),
      description: json['description']?.toString() ?? '',
      createdAt: _date(json['createdAt']),
    );
  }
}

class CallRecording {
  final String id;
  final DateTime? createdAt;
  final CallRecordingFile? file;

  const CallRecording({
    required this.id,
    this.createdAt,
    this.file,
  });

  factory CallRecording.fromJson(Map<String, dynamic> json) {
    final fileJson = _map(json['file']);

    return CallRecording(
      id: json['id']?.toString() ?? '',
      createdAt: _date(json['createdAt']),
      file: fileJson.isEmpty ? null : CallRecordingFile.fromJson(fileJson),
    );
  }
}

class CallRecordingFile {
  final String id;
  final String fileUrl;
  final String type;
  final int durationSeconds;
  final int size;

  const CallRecordingFile({
    required this.id,
    required this.fileUrl,
    required this.type,
    required this.durationSeconds,
    required this.size,
  });

  factory CallRecordingFile.fromJson(Map<String, dynamic> json) {
    final meta = _map(json['meta']);

    return CallRecordingFile(
      id: json['id']?.toString() ?? '',
      fileUrl: json['fileUrl']?.toString() ?? json['url']?.toString() ?? '',
      type: json['type']?.toString() ?? meta['format']?.toString() ?? '',
      durationSeconds: _int(
        meta['duration'] ?? json['duration'] ?? json['durationSeconds'],
      ),
      size: _int(json['size']),
    );
  }
}

List<CallRecording> callRecordingsFromResponse(dynamic data) {
  if (data is Map && data['recordings'] is List) {
    return _recordingsFrom(data['recordings']);
  }

  if (data is List) {
    return _recordingsFrom(data);
  }

  return const [];
}

DateTime? _date(dynamic value) {
  if (value is DateTime) return value;
  return DateTime.tryParse(value?.toString() ?? '');
}

bool _bool(dynamic value) {
  if (value is bool) return value;
  return value?.toString().toLowerCase() == 'true';
}

int _int(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.round();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

Map<String, dynamic> _map(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  return const {};
}

List<CallReview> _reviewsFrom(dynamic value) {
  if (value is! List) return const [];

  return value
      .whereType<Map>()
      .map((item) => CallReview.fromJson(Map<String, dynamic>.from(item)))
      .toList();
}

List<CallRecording> _recordingsFrom(dynamic value) {
  if (value is! List) return const [];

  return value
      .whereType<Map>()
      .map((item) => CallRecording.fromJson(Map<String, dynamic>.from(item)))
      .toList();
}
