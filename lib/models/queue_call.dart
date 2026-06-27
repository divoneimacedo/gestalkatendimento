import 'package:json_annotation/json_annotation.dart';

part 'queue_call.g.dart';

@JsonSerializable()
class QueueCall {
  @JsonKey(fromJson: _stringFromJson)
  final String id;
  @JsonKey(fromJson: _stringFromJson)
  final String status;
  @JsonKey(fromJson: _nullableStringFromJson)
  final String? caller;
  @JsonKey(fromJson: _nullableStringFromJson)
  final String? protocol;
  @JsonKey(readValue: _readChannelName, fromJson: _nullableStringFromJson)
  final String? channelName;
  @JsonKey(readValue: _readServiceTypeName, fromJson: _nullableStringFromJson)
  final String? serviceTypeName;
  @JsonKey(readValue: _readServiceTypePriority, fromJson: _intFromJson)
  final int serviceTypePriority;
  @JsonKey(fromJson: _dateTimeFromJson)
  final DateTime? createdAt;
  @JsonKey(fromJson: _waitingTimeFromJson)
  final String? waitingTime;
  @JsonKey(fromJson: _nullableStringFromJson)
  String? attendant;

  QueueCall({
    required this.id,
    required this.status,
    this.caller,
    this.protocol,
    this.channelName,
    this.serviceTypeName,
    this.serviceTypePriority = 0,
    this.createdAt,
    this.waitingTime,
    this.attendant,
  });

  factory QueueCall.fromJson(Map<String, dynamic> json) =>
      _$QueueCallFromJson(json);

  Map<String, dynamic> toJson() => _$QueueCallToJson(this);
}

String _stringFromJson(dynamic value) => value?.toString() ?? '';

String? _nullableStringFromJson(dynamic value) => value?.toString();

int _intFromJson(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

DateTime? _dateTimeFromJson(dynamic value) {
  if (value is DateTime) return value;
  return DateTime.tryParse(value?.toString() ?? '');
}

String? _waitingTimeFromJson(dynamic value) {
  if (value == null) return null;
  if (value is num) return '${value.toInt()} min';

  final text = value.toString();
  if (text.isEmpty) return null;

  final minutes = int.tryParse(text);
  if (minutes != null) return '$minutes min';

  return text;
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

Object? _readServiceTypeName(Map json, String key) {
  final serviceTypeName = json['serviceTypeName'];
  if (serviceTypeName != null) return serviceTypeName;

  final serviceType = json['serviceType'];
  if (serviceType is Map && serviceType['name'] != null) {
    return serviceType['name'];
  }

  return null;
}

Object? _readServiceTypePriority(Map json, String key) {
  final serviceTypePriority = json['serviceTypePriority'];
  if (serviceTypePriority != null) return serviceTypePriority;

  final serviceType = json['serviceType'];
  if (serviceType is Map && serviceType['priority'] != null) {
    return serviceType['priority'];
  }

  return 0;
}
