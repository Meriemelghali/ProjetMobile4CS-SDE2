import '../../../core/network/api_client.dart';
import '../domain/pharmacy_models.dart';

class PharmacyService {
  PharmacyService({ApiClient? apiClient}) : _api = apiClient ?? ApiClient();
  final ApiClient _api;

  Future<List<Pharmacy>> pharmacies() async =>
      _list('/pharmacy/pharmacies', 'pharmacies', Pharmacy.fromJson);

  Future<List<Medication>> medications({String? search}) async => _list(
    '/pharmacy/medications',
    'medications',
    Medication.fromJson,
    search == null ? null : {'search': search},
  );
  Future<List<Medication>> alerts() async =>
      _list('/pharmacy/alerts', 'medications', Medication.fromJson);
  Future<List<Prescription>> prescriptions({String? status}) async => _list(
    '/pharmacy/prescriptions',
    'prescriptions',
    Prescription.fromJson,
    status == null ? null : {'status': status},
  );
  Future<List<Dispensation>> dispensations() async =>
      _list('/pharmacy/dispensations', 'dispensations', Dispensation.fromJson);
  Future<List<MedicationRequest>> requests() async =>
      _list('/pharmacy/requests', 'requests', MedicationRequest.fromJson);
  Future<List<SupplyOrder>> orders() async =>
      _list('/pharmacy/orders', 'orders', SupplyOrder.fromJson);

  Future<Medication> createMedication(Map<String, Object?> body) async => _item(
    await _api.post('/pharmacy/medications', body: body),
    'medication',
    Medication.fromJson,
  );
  Future<Medication> updateMedication(
    String id,
    Map<String, Object?> body,
  ) async => _item(
    await _api.put('/pharmacy/medications/$id', body: body),
    'medication',
    Medication.fromJson,
  );
  Future<Medication> adjustStock(String id, int quantity) async => _item(
    await _api.put(
      '/pharmacy/medications/$id/stock',
      body: {'quantity': quantity},
    ),
    'medication',
    Medication.fromJson,
  );
  Future<Prescription> prescriptionAction(
    String id,
    String action, {
    String? reason,
  }) async => _item(
    await _api.post(
      '/pharmacy/prescriptions/$id/$action',
      body: {'reason': ?reason},
    ),
    'prescription',
    Prescription.fromJson,
  );
  Future<void> dispense(String id) async {
    await _api.post('/pharmacy/prescriptions/$id/dispense');
  }

  Future<MedicationRequest> requestAction(
    String id,
    String action, {
    String? reason,
  }) async => _item(
    await _api.post(
      '/pharmacy/requests/$id/$action',
      body: {'reason': ?reason},
    ),
    'request',
    MedicationRequest.fromJson,
  );
  Future<SupplyOrder> createOrder(Map<String, Object?> body) async => _item(
    await _api.post('/pharmacy/orders', body: body),
    'order',
    SupplyOrder.fromJson,
  );
  Future<SupplyOrder> receiveOrder(String id) async => _item(
    await _api.post('/pharmacy/orders/$id/receive'),
    'order',
    SupplyOrder.fromJson,
  );

  Future<List<T>> _list<T>(
    String path,
    String key,
    T Function(Map<String, dynamic>) parse, [
    Map<String, String>? query,
  ]) async {
    final response = await _api.get(path, queryParameters: query);
    final values = response[key];
    if (values is! List) throw ApiException('Réponse invalide pour $key.');
    return values.whereType<Map<String, dynamic>>().map(parse).toList();
  }

  T _item<T>(
    Map<String, dynamic> response,
    String key,
    T Function(Map<String, dynamic>) parse,
  ) {
    final value = response[key];
    if (value is! Map<String, dynamic>)
      throw ApiException('Réponse invalide pour $key.');
    return parse(value);
  }
}
