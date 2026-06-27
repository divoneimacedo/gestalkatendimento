import 'package:json_annotation/json_annotation.dart';

part 'attendance_call.g.dart';

@JsonSerializable()
class AttendanceCall {
  @JsonKey(fromJson: _stringFromJson)
  final String id;
  @JsonKey(fromJson: _stringFromJson)
  final String protocol;
  @JsonKey(fromJson: _stringFromJson)
  final String status;
  @JsonKey(readValue: _readChannelName, fromJson: _nullableStringFromJson)
  final String? channelName;
  @JsonKey(fromJson: _nullableStringFromJson)
  final String? device;
  @JsonKey(fromJson: _nullableStringFromJson)
  final String? email;
  @JsonKey(fromJson: _nullableStringFromJson)
  final String? ip;
  @JsonKey(fromJson: _dateTimeFromJson)
  final DateTime? createdAt;
  @JsonKey(fromJson: _dateTimeFromJson)
  final DateTime? endedAt;
  @JsonKey(fromJson: _nullableStringFromJson)
  final String? meetingId;

  AttendanceCall({
    required this.id,
    required this.protocol,
    required this.status,
    this.channelName,
    this.device,
    this.email,
    this.ip,
    this.createdAt,
    this.endedAt,
    this.meetingId,
  });

  factory AttendanceCall.fromJson(Map<String, dynamic> json) =>
      _$AttendanceCallFromJson(json);

  Map<String, dynamic> toJson() => _$AttendanceCallToJson(this);
}

String _stringFromJson(dynamic value) => value?.toString() ?? '';

String? _nullableStringFromJson(dynamic value) => value?.toString();

DateTime? _dateTimeFromJson(dynamic value) {
  if (value is DateTime) return value;
  return DateTime.tryParse(value?.toString() ?? '');
}

Object? _readChannelName(Map json, String key) {
  final channelName = json['channelName'];
  if (channelName != null) return channelName;

  final channel = json['channel'];
  if (channel is Map && channel['name'] != null) {
    return channel['name'];
  }

  return null;
}
