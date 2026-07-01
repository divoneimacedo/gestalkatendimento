// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'attendance_call.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

AttendanceCall _$AttendanceCallFromJson(Map<String, dynamic> json) =>
    AttendanceCall(
      id: _stringFromJson(json['id']),
      protocol: _stringFromJson(json['protocol']),
      status: _stringFromJson(json['status']),
      channelName:
          _nullableStringFromJson(_readChannelName(json, 'channelName')),
      device: _nullableStringFromJson(json['device']),
      email: _nullableStringFromJson(json['email']),
      ip: _nullableStringFromJson(json['ip']),
      createdAt: _dateTimeFromJson(json['createdAt']),
      endedAt: _dateTimeFromJson(json['endedAt']),
      meetingId: _nullableStringFromJson(json['meetingId']),
    );

Map<String, dynamic> _$AttendanceCallToJson(AttendanceCall instance) =>
    <String, dynamic>{
      'id': instance.id,
      'protocol': instance.protocol,
      'status': instance.status,
      'channelName': instance.channelName,
      'device': instance.device,
      'email': instance.email,
      'ip': instance.ip,
      'createdAt': instance.createdAt?.toIso8601String(),
      'endedAt': instance.endedAt?.toIso8601String(),
      'meetingId': instance.meetingId,
    };
