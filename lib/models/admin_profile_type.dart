class AdminProfileType {
  final String id;
  final String name;
  final List<String> accessModules;

  const AdminProfileType({
    required this.id,
    required this.name,
    required this.accessModules,
  });

  factory AdminProfileType.fromJson(Map<String, dynamic> json) {
    return AdminProfileType(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      accessModules: _list(json['accessModules']),
    );
  }
}

List<String> _list(dynamic value) {
  if (value is List) return value.map((item) => item.toString()).toList();
  if (value is String && value.trim().isNotEmpty) return [value];
  return const [];
}
