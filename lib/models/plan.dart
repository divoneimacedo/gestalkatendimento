class Plan {
  final String id;
  final String name;
  final num value;
  final int duration;
  final bool isInative;

  const Plan({
    required this.id,
    required this.name,
    required this.value,
    required this.duration,
    required this.isInative,
  });

  factory Plan.fromJson(Map<String, dynamic> json) {
    return Plan(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      value: _num(json['value']),
      duration: _int(json['duration']),
      isInative: json['isInative'] == true,
    );
  }
}

int _int(dynamic value) {
  if (value is int) return value;
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

num _num(dynamic value) {
  if (value is num) return value;
  return num.tryParse(value?.toString() ?? '') ?? 0;
}
