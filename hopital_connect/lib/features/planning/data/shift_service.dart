import '../../../core/network/api_client.dart';
import '../domain/shift.dart';

class ShiftService {
  ShiftService({ApiClient? apiClient}) : _api = apiClient ?? ApiClient();

  final ApiClient _api;

  Future<List<Shift>> list({String? userId}) async {
    final response = await _api.get(
      '/shifts',
      queryParameters: userId == null ? null : {'userId': userId},
    );
    final values = response['shifts'];
    if (values is! List) throw const ApiException('Liste des gardes invalide.');
    return values
        .map((item) => Shift.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<Shift> create(Shift shift) async {
    final response = await _api.post('/shifts', body: shift.toJson());
    return Shift.fromJson(response['shift'] as Map<String, dynamic>);
  }
}
