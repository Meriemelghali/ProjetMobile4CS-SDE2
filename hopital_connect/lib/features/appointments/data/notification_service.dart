import '../../../core/network/api_client.dart';
import '../domain/appointment_notification.dart';

class NotificationService {
  NotificationService({ApiClient? apiClient}) : _api = apiClient ?? ApiClient();

  final ApiClient _api;

  Future<List<AppointmentNotification>> list() async {
    final response = await _api.get('/notifications');
    final values = response['notifications'];
    if (values is! List) {
      throw const ApiException('Liste des notifications invalide.');
    }
    return values
        .map(
          (value) =>
              AppointmentNotification.fromJson(value as Map<String, dynamic>),
        )
        .toList();
  }

  Future<void> markAllRead() async {
    await _api.put('/notifications/read-all', body: const {});
  }
}
