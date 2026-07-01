import 'package:json_annotation/json_annotation.dart';

part 'user.g.dart';

@JsonSerializable()
class User {
  @JsonKey(fromJson: _stringFromJson)
  final String id;
  @JsonKey(fromJson: _stringFromJson)
  final String name;
  @JsonKey(fromJson: _stringFromJson)
  final String username;
  @JsonKey(fromJson: _stringFromJson)
  final String profile;
  @JsonKey(fromJson: _stringFromJson)
  final String companyId;
  @JsonKey(fromJson: _boolFromJson)
  final bool needsTermsAcceptance;
  @JsonKey(fromJson: _permissionsFromJson)
  final List<String> permissions;

  // Campos que podem não vir no login
  @JsonKey(readValue: _readIsInterpreter, fromJson: _boolFromJson)
  final bool isInterpreter;
  @JsonKey(readValue: _readIsAdmin, fromJson: _boolFromJson)
  final bool isAdmin;
  final String? email;
  final String? avatar;
  final String? phoneNumber;

  User({
    required this.id,
    required this.name,
    this.username = '',
    required this.profile,
    required this.companyId,
    required this.needsTermsAcceptance,
    required this.permissions,
    this.isInterpreter = false,
    this.isAdmin = false,
    this.email,
    this.avatar,
    this.phoneNumber,
  });

  factory User.fromJson(Map<String, dynamic> json) => _$UserFromJson(json);

  Map<String, dynamic> toJson() => _$UserToJson(this);

  User copyWith({
    String? id,
    String? name,
    String? username,
    String? profile,
    String? companyId,
    bool? needsTermsAcceptance,
    List<String>? permissions,
    bool? isInterpreter,
    bool? isAdmin,
    String? email,
    String? avatar,
    String? phoneNumber,
  }) {
    return User(
      id: id ?? this.id,
      name: name ?? this.name,
      username: username ?? this.username,
      profile: profile ?? this.profile,
      companyId: companyId ?? this.companyId,
      needsTermsAcceptance: needsTermsAcceptance ?? this.needsTermsAcceptance,
      permissions: permissions ?? this.permissions,
      isInterpreter: isInterpreter ?? this.isInterpreter,
      isAdmin: isAdmin ?? this.isAdmin,
      email: email ?? this.email,
      avatar: avatar ?? this.avatar,
      phoneNumber: phoneNumber ?? this.phoneNumber,
    );
  }
}

String _stringFromJson(dynamic value) => value?.toString() ?? '';

bool _boolFromJson(dynamic value) {
  if (value is bool) return value;
  if (value is num) return value != 0;
  if (value is String) {
    return value.toLowerCase() == 'true' || value == '1';
  }
  return false;
}

List<String> _permissionsFromJson(dynamic value) {
  if (value is List) {
    return value.map((item) => item.toString()).toList();
  }

  if (value is String) {
    return value
        .replaceAll('[', '')
        .replaceAll(']', '')
        .split(',')
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList();
  }

  return [];
}

Object? _readIsInterpreter(Map json, String key) {
  if (json[key] != null) return json[key];

  final profile = json['profile']?.toString().toLowerCase();
  return profile == 'interpreter' ||
      profile == 'interprete' ||
      profile == 'intérprete';
}

Object? _readIsAdmin(Map json, String key) {
  if (json[key] != null) return json[key];

  final profile = json['profile']?.toString().toLowerCase();
  return profile == 'admin' || profile == 'administrator';
}
