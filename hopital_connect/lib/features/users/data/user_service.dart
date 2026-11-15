import '../../../core/network/api_client.dart';
import '../domain/staff_user.dart';

class UserService {
  UserService({ApiClient? apiClient}) : _api = apiClient ?? ApiClient();

  final ApiClient _api;

  Future<List<StaffUser>> list() async {
    final response = await _api.get('/users');
    final values = response['users'];
    if (values is! List) {
      throw const ApiException('Liste des comptes invalide.');
    }
    return values
        .map((item) => StaffUser.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<List<ServiceColleague>> listServiceMembers(String serviceId) async {
    final response = await _api.get('/users/service/$serviceId');
    final values = response['users'];
    if (values is! List) {
      throw const ApiException('Liste des collègues invalide.');
    }
    return values
        .map((item) => ServiceColleague.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<List<StaffUser>> listAssignablePatients() async {
    final response = await _api.get('/users/patients');
    final values = response['users'];
    if (values is! List) {
      throw const ApiException('Liste des patients assignables invalide.');
    }
    return values
        .map((item) => StaffUser.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<List<StaffUser>> listInterventionParticipants() async {
    final response = await _api.get('/users/intervention-participants');
    final values = response['users'];
    if (values is! List) {
      throw const ApiException('Liste des participants invalide.');
    }
    return values
        .map((item) => StaffUser.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<StaffUser> create({
    required String username,
    required String email,
    required String password,
    required String role,
    List<String> roles = const [],
    String? hospitalId,
    String? serviceId,
    String? pharmacyId,
    List<String> serviceIds = const [],
    String specialty = '',
    String photoUrl = '',
  }) async {
    final response = await _api.post(
      '/users',
      body: {
        'username': username,
        'email': email,
        'password': password,
        'role': role,
        'roles': roles.isEmpty ? [role] : roles,
        'hospitalId': ?hospitalId,
        'serviceId': ?serviceId,
        'pharmacyId': ?pharmacyId,
        if (serviceIds.isNotEmpty ||
            role == 'secretary' ||
            roles.contains('secretary'))
          'serviceIds': serviceIds,
        'specialty': specialty,
        'photoUrl': photoUrl,
      },
    );
    return StaffUser.fromJson(response['user'] as Map<String, dynamic>);
  }

  Future<StaffUser> update(StaffUser user) async {
    final response = await _api.put('/users/${user.id}', body: user.toJson());
    return StaffUser.fromJson(response['user'] as Map<String, dynamic>);
  }
}
