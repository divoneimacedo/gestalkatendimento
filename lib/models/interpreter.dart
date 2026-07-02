class InterpreterCurrentCall {
  final String id;
  final String company;
  final int duration;

  const InterpreterCurrentCall({
    required this.id,
    required this.company,
    required this.duration,
  });

  factory InterpreterCurrentCall.fromJson(Map<String, dynamic> json) {
    return InterpreterCurrentCall(
      id: json['id']?.toString() ?? '',
      company: json['company']?.toString() ?? '',
      duration: _int(json['duration']),
    );
  }
}

class InterpreterListItem {
  final String id;
  final String name;
  final String username;
  final DateTime? connectionTime;
  final String status;
  final InterpreterCurrentCall? currentCall;
  final int callsAttended;
  final int averageTime;

  const InterpreterListItem({
    required this.id,
    required this.name,
    required this.username,
    required this.connectionTime,
    required this.status,
    required this.currentCall,
    required this.callsAttended,
    required this.averageTime,
  });

  factory InterpreterListItem.fromJson(Map<String, dynamic> json) {
    final rawCurrentCall = json['currentCall'];

    return InterpreterListItem(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      username: json['username']?.toString() ?? '',
      connectionTime: _dateTime(json['connectionTime']),
      status: json['status']?.toString() ?? 'offline',
      currentCall: rawCurrentCall is Map
          ? InterpreterCurrentCall.fromJson(
              Map<String, dynamic>.from(rawCurrentCall))
          : null,
      callsAttended: _int(json['callsAttended']),
      averageTime: _int(json['averageTime']),
    );
  }
}

int _int(dynamic value) {
  if (value is int) return value;
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

DateTime? _dateTime(dynamic value) {
  final text = value?.toString() ?? '';
  if (text.isEmpty) return null;
  return DateTime.tryParse(text);
}
