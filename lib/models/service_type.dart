class ServiceType {
  final String id;
  final String name;
  final int priority;
  final String companyId;
  final String companyName;

  const ServiceType({
    required this.id,
    required this.name,
    required this.priority,
    required this.companyId,
    required this.companyName,
  });

  factory ServiceType.fromJson(
    Map<String, dynamic> json, {
    String companyName = '',
  }) {
    return ServiceType(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      priority: _int(json['priority']),
      companyId: json['companyId']?.toString() ?? '',
      companyName: json['companyName']?.toString() ?? companyName,
    );
  }
}

class ServiceTypesPage {
  final List<ServiceType> serviceTypes;
  final int total;
  final int page;
  final int limit;
  final int totalPages;

  const ServiceTypesPage({
    required this.serviceTypes,
    required this.total,
    required this.page,
    required this.limit,
    required this.totalPages,
  });
}

int _int(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}
