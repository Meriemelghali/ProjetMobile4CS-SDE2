import '../../../core/network/api_client.dart';
import '../domain/hospital_service.dart';

class ServiceService {
  ServiceService({ApiClient? apiClient}) : _api = apiClient ?? ApiClient();

  final ApiClient _api;

  Future<List<HospitalService>> list() async {
    final response = await _api.get('/services');
    final values = response['services'];
    if (values is! List) {
      throw const ApiException('Liste des services invalide.');
    }
    return values
        .map((item) => HospitalService.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<HospitalService> create(HospitalService service) async {
    final response = await _api.post('/services', body: service.toJson());
    return HospitalService.fromJson(
      response['service'] as Map<String, dynamic>,
    );
  }

  Future<HospitalService> update(HospitalService service) async {
    final response = await _api.put(
      '/services/${service.id}',
      body: service.toJson(),
    );
    return HospitalService.fromJson(
      response['service'] as Map<String, dynamic>,
    );
  }
}
