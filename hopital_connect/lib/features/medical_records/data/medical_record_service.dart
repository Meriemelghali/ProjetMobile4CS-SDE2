import '../../../core/network/api_client.dart';
import '../domain/medical_record.dart';

/// Appels de l'API `/medical-records`. Les droits sont vérifiés par le
/// serveur : médecin (écriture), infirmier (lecture + constantes),
/// patient (lecture de son propre dossier).
class MedicalRecordService {
  MedicalRecordService({ApiClient? apiClient})
    : _api = apiClient ?? ApiClient();

  final ApiClient _api;

  Future<List<PatientSummary>> searchPatients({String query = ''}) async {
    final trimmed = query.trim();
    final response = await _api.get(
      '/medical-records/patients',
      queryParameters: trimmed.isEmpty ? null : {'q': trimmed},
    );
    final values = response['patients'];
    if (values is! List) {
      throw const ApiException('Liste des patients invalide.');
    }
    return values
        .whereType<Map<String, dynamic>>()
        .map(PatientSummary.fromJson)
        .toList();
  }

  Future<PatientMedicalFile> mine() async =>
      PatientMedicalFile.fromJson(await _api.get('/medical-records/me'));

  Future<PatientMedicalFile> byPatient(String patientId) async =>
      PatientMedicalFile.fromJson(
        await _api.get('/medical-records/$patientId'),
      );

  Future<MedicalRecord> updateRecord(
    String patientId,
    MedicalRecord record,
  ) async {
    final response = await _api.put(
      '/medical-records/$patientId',
      body: record.toUpdateJson(),
    );
    return MedicalRecord.fromJson(response['record'] as Map<String, dynamic>);
  }

  Future<Consultation> addConsultation(
    String patientId,
    ConsultationDraft draft,
  ) async {
    final response = await _api.post(
      '/medical-records/$patientId/consultations',
      body: draft.toJson(),
    );
    return Consultation.fromJson(
      response['consultation'] as Map<String, dynamic>,
    );
  }

  Future<Consultation> updateConsultation(
    String consultationId,
    ConsultationDraft draft,
  ) async {
    final response = await _api.put(
      '/medical-records/consultations/$consultationId',
      body: draft.toJson(),
    );
    return Consultation.fromJson(
      response['consultation'] as Map<String, dynamic>,
    );
  }

  Future<VitalSign> addVitals(String patientId, VitalDraft draft) async {
    final response = await _api.post(
      '/medical-records/$patientId/vitals',
      body: draft.toJson(),
    );
    return VitalSign.fromJson(response['vital'] as Map<String, dynamic>);
  }
}
