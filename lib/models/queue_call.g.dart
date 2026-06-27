// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'queue_call.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

QueueCall _$QueueCallFromJson(Map<String, dynamic> json) => QueueCall(
      id: _stringFromJson(json['id']),
      status: _stringFromJson(json['status']),
      caller: _nullableStringFromJson(json['caller']),
      protocol: _nullableStringFromJson(json['protocol']),
      channelName:
          _nullableStringFromJson(_readChannelName(json, 'channelName')),
      serviceTypeName: _nullableStringFromJson(
          _readServiceTypeName(json, 'serviceTypeName')),
      serviceTypePriority: _readServiceTypePriority(
                  json, 'serviceTypePriority') ==
              null
          ? 0
          : _intFromJson(_readServiceTypePriority(json, 'serviceTypePriority')),
      createdAt: _dateTimeFromJson(json['createdAt']),
      waitingTime: _waitingTimeFromJson(json['waitingTime']),
      attendant: _nullableStringFromJson(json['attendant']),
    );

Map<String, dynamic> _$QueueCallToJson(QueueCall instance) => <String, dynamic>{
      'id': instance.id,
      'status': instance.status,
      'caller': instance.caller,
      'protocol': instance.protocol,
      'channelName': instance.channelName,
      'serviceTypeName': instance.serviceTypeName,
      'serviceTypePriority': instance.serviceTypePriority,
      'createdAt': instance.createdAt?.toIso8601String(),
      'waitingTime': instance.waitingTime,
      'attendant': instance.attendant,
    };
