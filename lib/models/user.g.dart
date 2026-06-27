// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

User _$UserFromJson(Map<String, dynamic> json) => User(
      id: _stringFromJson(json['id']),
      name: _stringFromJson(json['name']),
      profile: _stringFromJson(json['profile']),
      companyId: _stringFromJson(json['companyId']),
      needsTermsAcceptance: _boolFromJson(json['needsTermsAcceptance']),
      permissions: _permissionsFromJson(json['permissions']),
      isInterpreter: _readIsInterpreter(json, 'isInterpreter') == null
          ? false
          : _boolFromJson(_readIsInterpreter(json, 'isInterpreter')),
      isAdmin: _readIsAdmin(json, 'isAdmin') == null
          ? false
          : _boolFromJson(_readIsAdmin(json, 'isAdmin')),
      email: json['email'] as String?,
      avatar: json['avatar'] as String?,
    );

Map<String, dynamic> _$UserToJson(User instance) => <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'profile': instance.profile,
      'companyId': instance.companyId,
      'needsTermsAcceptance': instance.needsTermsAcceptance,
      'permissions': instance.permissions,
      'isInterpreter': instance.isInterpreter,
      'isAdmin': instance.isAdmin,
      'email': instance.email,
      'avatar': instance.avatar,
    };
