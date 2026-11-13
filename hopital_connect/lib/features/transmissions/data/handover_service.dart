import '../../../core/network/api_client.dart';
import '../domain/handover.dart';

class HandoverService {
  HandoverService({ApiClient? apiClient}) : _api = apiClient ?? ApiClient();

  final ApiClient _api;

  Future<List<Handover>> list({String? serviceId}) async {
    final response = await _api.get(
      '/handovers',
      queryParameters: serviceId == null ? null : {'serviceId': serviceId},
    );
    final values = response['handovers'];
    if (values is! List) {
      throw const ApiException('Liste des transmissions invalide.');
    }
    return values
        .map((item) => Handover.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<Handover> create(Handover handover) async {
    final response = await _api.post('/handovers', body: handover.toJson());
    return Handover.fromJson(response['handover'] as Map<String, dynamic>);
  }
}
