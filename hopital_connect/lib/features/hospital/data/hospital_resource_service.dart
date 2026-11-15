import '../../../core/network/api_client.dart';
import '../domain/hospital_resources.dart';

class HospitalResourceService {
  HospitalResourceService({ApiClient? apiClient})
    : _api = apiClient ?? ApiClient();

  final ApiClient _api;

  Future<List<Hospital>> hospitals() =>
      _list('/hospitals', 'hospitals', Hospital.fromJson);

  Future<Hospital> createHospital(Hospital hospital) =>
      _create('/hospitals', 'hospital', hospital.toJson(), Hospital.fromJson);

  Future<Hospital> updateHospital(Hospital hospital) => _update(
    '/hospitals',
    'hospital',
    hospital.id,
    hospital.toJson(),
    Hospital.fromJson,
  );

  Future<void> deleteHospital(String id) => _delete('/hospitals/$id');

  Future<List<HospitalRoom>> rooms() =>
      _list('/rooms', 'rooms', HospitalRoom.fromJson);

  Future<HospitalRoom> createRoom(HospitalRoom room) =>
      _create('/rooms', 'room', room.toJson(), HospitalRoom.fromJson);

  Future<HospitalRoom> updateRoom(HospitalRoom room) =>
      _update('/rooms', 'room', room.id, room.toJson(), HospitalRoom.fromJson);

  Future<void> deleteRoom(String id) => _delete('/rooms/$id');

  Future<RoomOccupancy> roomOccupancy(String id) async {
    final response = await _api.get('/rooms/$id/occupancy');
    final data = response['occupancy'];
    if (data is! Map<String, dynamic>) {
      throw const ApiException('Réponse invalide pour le taux d’occupation.');
    }
    return RoomOccupancy.fromJson(data);
  }

  Future<List<HospitalBed>> beds() =>
      _list('/beds', 'beds', HospitalBed.fromJson);

  Future<HospitalBed> createBed(HospitalBed bed) =>
      _create('/beds', 'bed', bed.toJson(), HospitalBed.fromJson);

  Future<HospitalBed> updateBed(HospitalBed bed) =>
      _update('/beds', 'bed', bed.id, bed.toJson(), HospitalBed.fromJson);

  Future<HospitalBed> updateBedStatus(String bedId, BedStatus status) async {
    final response = await _api.put(
      '/beds/$bedId',
      body: {'status': status.name},
    );
    return _item(response, 'bed', HospitalBed.fromJson);
  }

  Future<HospitalBed> assignBed(String bedId, String patientId) async {
    final response = await _api.put(
      '/beds/$bedId/assignment',
      body: {'patientId': patientId},
    );
    return _item(response, 'bed', HospitalBed.fromJson);
  }

  Future<void> releaseBed(String bedId) => _delete('/beds/$bedId/assignment');

  Future<void> deleteBed(String id) => _delete('/beds/$id');

  Future<List<OperatingRoom>> operatingRooms() =>
      _list('/operating-rooms', 'operatingRooms', OperatingRoom.fromJson);

  Future<OperatingRoom> createOperatingRoom(OperatingRoom room) => _create(
    '/operating-rooms',
    'operatingRoom',
    room.toJson(),
    OperatingRoom.fromJson,
  );

  Future<OperatingRoom> updateOperatingRoom(OperatingRoom room) => _update(
    '/operating-rooms',
    'operatingRoom',
    room.id,
    room.toJson(),
    OperatingRoom.fromJson,
  );

  Future<void> deleteOperatingRoom(String id) =>
      _delete('/operating-rooms/$id');

  Future<OperatingRoom> updateOperatingRoomStatus(
    String roomId,
    OperatingRoomStatus status,
  ) async {
    final response = await _api.put(
      '/operating-rooms/$roomId',
      body: {'status': status.apiValue},
    );
    return _item(response, 'operatingRoom', OperatingRoom.fromJson);
  }

  Future<List<HospitalEquipment>> equipment() =>
      _list('/equipment', 'equipment', HospitalEquipment.fromJson);

  Future<HospitalEquipment> createEquipment(HospitalEquipment equipment) =>
      _create(
        '/equipment',
        'equipment',
        equipment.toJson(),
        HospitalEquipment.fromJson,
      );

  Future<HospitalEquipment> updateEquipment(HospitalEquipment equipment) =>
      _update(
        '/equipment',
        'equipment',
        equipment.id,
        equipment.toJson(),
        HospitalEquipment.fromJson,
      );

  Future<HospitalEquipment> markMaintenance(
    String equipmentId, {
    required DateTime lastMaintenanceAt,
    required DateTime? maintenanceDueAt,
  }) async {
    final response = await _api.put(
      '/equipment/$equipmentId/maintenance',
      body: {
        'status': 'functional',
        'lastMaintenanceAt': lastMaintenanceAt.toIso8601String(),
        'maintenanceDueAt': maintenanceDueAt?.toIso8601String(),
      },
    );
    return _item(response, 'equipment', HospitalEquipment.fromJson);
  }

  Future<void> deleteEquipment(String id) => _delete('/equipment/$id');

  Future<List<HospitalIntervention>> interventions() =>
      _list('/interventions', 'interventions', HospitalIntervention.fromJson);

  Future<HospitalIntervention> createIntervention(
    HospitalIntervention intervention,
  ) => _create(
    '/interventions',
    'intervention',
    intervention.toJson(),
    HospitalIntervention.fromJson,
  );

  Future<HospitalIntervention> updateIntervention(
    HospitalIntervention intervention,
  ) => _update(
    '/interventions',
    'intervention',
    intervention.id,
    intervention.toJson(),
    HospitalIntervention.fromJson,
  );

  Future<void> deleteIntervention(String id) => _delete('/interventions/$id');

  Future<List<T>> _list<T>(
    String path,
    String key,
    T Function(Map<String, dynamic>) fromJson,
  ) async {
    final response = await _api.get(path);
    final values = response[key];
    if (values is! List) {
      throw ApiException('Liste "$key" invalide.');
    }
    return values.map((value) {
      if (value is! Map<String, dynamic>) {
        throw ApiException('Élément invalide dans "$key".');
      }
      return fromJson(value);
    }).toList();
  }

  Future<T> _create<T>(
    String path,
    String key,
    Map<String, Object?> body,
    T Function(Map<String, dynamic>) fromJson,
  ) async {
    final response = await _api.post(path, body: body);
    return _item(response, key, fromJson);
  }

  Future<T> _update<T>(
    String path,
    String key,
    String id,
    Map<String, Object?> body,
    T Function(Map<String, dynamic>) fromJson,
  ) async {
    if (id.isEmpty) throw const ApiException('Identifiant manquant.');
    final response = await _api.put('$path/$id', body: body);
    return _item(response, key, fromJson);
  }

  T _item<T>(
    Map<String, dynamic> response,
    String key,
    T Function(Map<String, dynamic>) fromJson,
  ) {
    final data = response[key];
    if (data is! Map<String, dynamic>) {
      throw ApiException('Réponse invalide pour "$key".');
    }
    return fromJson(data);
  }

  Future<void> _delete(String path) async {
    await _api.delete(path);
  }
}
