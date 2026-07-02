class Channel {
  final String id;
  final String companyId;
  final String companyName;
  final String name;
  final String accessLink;
  final String qrCode;
  final bool isPrivated;
  final bool isInative;
  final int priority;

  const Channel({
    required this.id,
    required this.companyId,
    required this.companyName,
    required this.name,
    required this.accessLink,
    required this.qrCode,
    required this.isPrivated,
    required this.isInative,
    required this.priority,
  });

  factory Channel.fromJson(Map<String, dynamic> json) {
    return Channel(
      id: json['id']?.toString() ?? '',
      companyId: json['companyId']?.toString() ?? '',
      companyName: json['companyName']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      accessLink: json['accessLink']?.toString() ?? '',
      qrCode: json['qrCode']?.toString() ?? '',
      isPrivated: json['isPrivated'] == true,
      isInative: json['isInative'] == true,
      priority: _int(json['priority']),
    );
  }

  Channel copyWith({
    String? id,
    String? companyId,
    String? companyName,
    String? name,
    String? accessLink,
    String? qrCode,
    bool? isPrivated,
    bool? isInative,
    int? priority,
  }) {
    return Channel(
      id: id ?? this.id,
      companyId: companyId ?? this.companyId,
      companyName: companyName ?? this.companyName,
      name: name ?? this.name,
      accessLink: accessLink ?? this.accessLink,
      qrCode: qrCode ?? this.qrCode,
      isPrivated: isPrivated ?? this.isPrivated,
      isInative: isInative ?? this.isInative,
      priority: priority ?? this.priority,
    );
  }
}

int _int(dynamic value) {
  if (value is int) return value;
  return int.tryParse(value?.toString() ?? '') ?? 0;
}
