import '../../../core/network/api_client.dart';
import '../domain/appointment.dart';

class AppointmentService {
  AppointmentService({ApiClient? apiClient}) : _api = apiClient ?? ApiClient();

  final ApiClient _api;

  Future<List<Appointment>> list() async {
    final response = await _api.get('/appointments');
    final values = response['appointments'];
    if (values is! List) {
      throw const ApiException('Réponse de rendez-vous invalide.');
    }
    return values
        .map((value) => Appointment.fromJson(value as Map<String, dynamic>))
        .toList();
  }

  Future<List<AppointmentDoctor>> listDoctors({String? serviceId}) async {
    final response = await _api.get(
      '/appointments/doctors',
      queryParameters: serviceId == null ? null : {'serviceId': serviceId},
    );
    final values = response['doctors'];
    if (values is! List) {
      throw const ApiException('Réponse de médecins invalide.');
    }
    return values
        .map(
          (value) => AppointmentDoctor.fromJson(value as Map<String, dynamic>),
        )
        .toList();
  }

  Future<List<DateTime>> availableSlots({
    required String doctorId,
    required DateTime date,
  }) async {
    final response = await _api.get(
      '/appointments/availability',
      queryParameters: {
        'doctorId': doctorId,
        'date':
            '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}',
      },
    );
    final values = response['slots'];
    if (values is! List) {
      throw const ApiException('Créneaux disponibles invalides.');
    }
    return values
        .map((value) => DateTime.parse(value as String).toLocal())
        .toList();
  }

  Future<Appointment> create({
    required String doctorId,
    required DateTime startAt,
    required String reason,
  }) async {
    final response = await _api.post(
      '/appointments',
      body: {
        'doctorId': doctorId,
        'startAt': startAt.toUtc().toIso8601String(),
        'reason': reason,
      },
    );
    return _appointmentFromResponse(response);
  }

  Future<Appointment> update(
    Appointment appointment, {
    String? doctorId,
    DateTime? startAt,
    String? reason,
    AppointmentStatus? status,
  }) async {
    final body = <String, Object?>{};
    if (doctorId != null) body['doctorId'] = doctorId;
    if (startAt != null) {
      body['startAt'] = startAt.toUtc().toIso8601String();
    }
    if (reason != null) body['reason'] = reason;
    if (status != null) body['status'] = status.apiValue;
    final response = await _api.put(
      '/appointments/${appointment.id}',
      body: body,
    );
    return _appointmentFromResponse(response);
  }

  Future<Appointment> claim(Appointment appointment) async {
    final response = await _api.post('/appointments/${appointment.id}/claim');
    return _appointmentFromResponse(response);
  }

  Future<Appointment> release(Appointment appointment) async {
    final response = await _api.post('/appointments/${appointment.id}/release');
    return _appointmentFromResponse(response);
  }

  Future<Appointment> decide(
    Appointment appointment, {
    required String action,
    String? reason,
    DateTime? proposedStartAt,
  }) async {
    final response = await _api.post(
      '/appointments/${appointment.id}/decision',
      body: {
        'action': action,
        'reason': ?reason,
        'proposedStartAt': ?proposedStartAt?.toUtc().toIso8601String(),
      },
    );
    return _appointmentFromResponse(response);
  }

  Future<Appointment> respondToProposal(
    Appointment appointment, {
    required bool accept,
  }) async {
    final response = await _api.post(
      '/appointments/${appointment.id}/proposal-response',
      body: {'action': accept ? 'accept' : 'reject'},
    );
    return _appointmentFromResponse(response);
  }

  Appointment _appointmentFromResponse(Map<String, dynamic> response) {
    final appointment = response['appointment'];
    if (appointment is! Map<String, dynamic>) {
      throw const ApiException('Réponse de rendez-vous invalide.');
    }
    return Appointment.fromJson(appointment);
  }
}
