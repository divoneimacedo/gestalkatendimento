class ManagedUser {
  final String id;
  final String name;
  final String username;
  final String email;
  final String companyId;
  final String profileId;
  final String companyName;
  final String profileName;
  final String phoneNumber;
  final bool isBlock;
  final bool isInative;

  const ManagedUser({
    required this.id,
    required this.name,
    required this.username,
    required this.email,
    required this.companyId,
    required this.profileId,
    required this.companyName,
    required this.profileName,
    required this.phoneNumber,
    required this.isBlock,
    required this.isInative,
  });

  factory ManagedUser.fromJson(Map<String, dynamic> json) {
    return ManagedUser(
      id: _string(json['id']),
      name: _string(json['name']),
      username: _string(json['username']),
      email: _string(json['email']),
      companyId: _string(json['companyId']),
      profileId: _string(json['profileId']),
      companyName: _string(json['companyName']),
      profileName: _string(json['profileName']),
      phoneNumber: _string(json['phoneNumber']),
      isBlock: _bool(json['isBlock']),
      isInative: _bool(json['isInative']),
    );
  }

  ManagedUser copyWith({
    String? name,
    String? username,
    String? email,
    String? companyId,
    String? profileId,
    String? companyName,
    String? profileName,
    String? phoneNumber,
  }) {
    return ManagedUser(
      id: id,
      name: name ?? this.name,
      username: username ?? this.username,
      email: email ?? this.email,
      companyId: companyId ?? this.companyId,
      profileId: profileId ?? this.profileId,
      companyName: companyName ?? this.companyName,
      profileName: profileName ?? this.profileName,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      isBlock: isBlock,
      isInative: isInative,
    );
  }
}

class ManagedUsersPage {
  final List<ManagedUser> users;
  final int total;
  final int page;
  final int limit;
  final int totalPages;

  const ManagedUsersPage({
    required this.users,
    required this.total,
    required this.page,
    required this.limit,
    required this.totalPages,
  });
}

String _string(dynamic value) => value?.toString() ?? '';

bool _bool(dynamic value) {
  if (value is bool) return value;
  if (value is num) return value != 0;
  if (value is String) {
    return value.toLowerCase() == 'true' || value == '1';
  }
  return false;
}
