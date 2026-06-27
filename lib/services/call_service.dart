import '../models/call_details.dart';
import 'api/api_service.dart';

class CallService {
  final ApiService apiService;

  CallService(this.apiService);

  Future<CallDetails> getById(String callId) async {
    final response = await apiService.dio.get<dynamic>('/calls/$callId');
    final data = response.data;

    if (data is Map && data['call'] is Map) {
      return CallDetails.fromJson(Map<String, dynamic>.from(data['call']));
    }

    if (data is Map) {
      return CallDetails.fromJson(Map<String, dynamic>.from(data));
    }

    return CallDetails(
      id: callId,
      protocol: '',
      caller: '',
      meetingId: '',
      status: '',
    );
  }

  Future<void> finish(String callId) async {
    await apiService.dio.delete('/calls/$callId');
  }

  Future<String> getVideoSdkToken() async {
    final response = await apiService.dio.get<dynamic>('/get-token');
    final data = response.data;

    if (data is Map && data['token'] != null) {
      return data['token'].toString();
    }

    throw Exception('Token do VideoSDK não retornado pelo backend.');
  }
}
