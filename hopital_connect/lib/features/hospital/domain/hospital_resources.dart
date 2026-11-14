enum RoomType {
  single,
  doubleRoom,
  intensiveCare;

  String get apiValue => switch (this) {
    RoomType.single => 'single',
    RoomType.doubleRoom => 'double',
    RoomType.intensiveCare => 'intensive_care',
  };
}

enum RoomStatus { available, full, maintenance }

enum BedStatus { free, occupied, reserved, cleaning }

enum OperatingRoomStatus {
  free,
  inProgress,
  sterilization;

  String get apiValue => switch (this) {
    OperatingRoomStatus.free => 'free',
    OperatingRoomStatus.inProgress => 'in_progress',
    OperatingRoomStatus.sterilization => 'sterilization',
  };
}

enum EquipmentStatus { functional, broken, maintenance }

extension RoomTypeLabel on RoomType {
  String get label => switch (this) {
    RoomType.single => 'Simple',
    RoomType.doubleRoom => 'Double',
    RoomType.intensiveCare => 'Soins intensifs',
  };
}

extension RoomStatusLabel on RoomStatus {
  String get label => switch (this) {
    RoomStatus.available => 'Disponible',
    RoomStatus.full => 'Pleine',
    RoomStatus.maintenance => 'En maintenance',
  };
}

extension BedStatusLabel on BedStatus {
  String get label => switch (this) {
    BedStatus.free => 'Libre',
    BedStatus.occupied => 'Occupé',
    BedStatus.reserved => 'Réservé',
    BedStatus.cleaning => 'En nettoyage',
  };
}

extension OperatingRoomStatusLabel on OperatingRoomStatus {
  String get label => switch (this) {
    OperatingRoomStatus.free => 'Libre',
    OperatingRoomStatus.inProgress => 'En cours',
    OperatingRoomStatus.sterilization => 'En stérilisation',
  };
}

extension EquipmentStatusLabel on EquipmentStatus {
  String get label => switch (this) {
    EquipmentStatus.functional => 'Fonctionnel',
    EquipmentStatus.broken => 'En panne',
    EquipmentStatus.maintenance => 'En maintenance',
  };
}

class Hospital {
  const Hospital({
    required this.id,
    required this.name,
    this.address = '',
    this.phone = '',
    this.isActive = true,
    this.serviceIds = const [],
  });

  final String id;
  final String name;
  final String address;
  final String phone;
  final bool isActive;
  final List<String> serviceIds;

  factory Hospital.fromJson(Map<String, dynamic> json) => Hospital(
    id: _resourceId(json['_id'] ?? json['id']),
    name: json['name'] as String? ?? '',
    address: json['address'] as String? ?? '',
    phone: json['phone'] as String? ?? '',
    isActive: json['active'] as bool? ?? true,
    serviceIds: _idList(json['serviceIds']),
  );

  Map<String, Object?> toJson() => {
    'name': name,
    'address': address,
    'phone': phone,
    'active': isActive,
    'serviceIds': serviceIds,
  };
}

class HospitalRoom {
  const HospitalRoom({
    required this.id,
    required this.hospitalId,
    required this.number,
    required this.floor,
    required this.type,
    required this.status,
    this.serviceId,
    this.capacity = 0,
  });

  final String id;
  final String hospitalId;
  final String number;
  final String floor;
  final RoomType type;
  final RoomStatus status;
  final String? serviceId;
  final int capacity;

  factory HospitalRoom.fromJson(Map<String, dynamic> json) => HospitalRoom(
    id: _resourceId(json['_id'] ?? json['id']),
    hospitalId: _resourceId(json['hospitalId']),
    serviceId: json['serviceId'] == null
        ? null
        : _resourceId(json['serviceId']),
    number: (json['number'] ?? json['name'])?.toString() ?? '',
    floor: json['floor']?.toString() ?? '',
    type: _roomType(json['type']),
    status: _enumByName(
      RoomStatus.values,
      json['status'],
      RoomStatus.available,
    ),
    capacity: (json['capacity'] as num? ?? 0).toInt(),
  );

  Map<String, Object?> toJson() => {
    'hospitalId': hospitalId,
    if (serviceId != null) 'serviceId': serviceId,
    'number': number,
    'floor': floor,
    'type': type.apiValue,
    'status': status.name,
    if (capacity > 0) 'capacity': capacity,
  };
}

class HospitalBed {
  const HospitalBed({
    required this.id,
    required this.roomId,
    required this.number,
    required this.status,
    this.patientId,
    this.assignedAt,
  });

  final String id;
  final String roomId;
  final String number;
  final BedStatus status;
  final String? patientId;
  final DateTime? assignedAt;

  factory HospitalBed.fromJson(Map<String, dynamic> json) {
    final patient = json['patientId'];
    return HospitalBed(
      id: _resourceId(json['_id'] ?? json['id']),
      roomId: _resourceId(json['roomId']),
      number: (json['bedNumber'] ?? json['number'])?.toString() ?? '',
      status: _enumByName(BedStatus.values, json['status'], BedStatus.free),
      patientId: patient == null ? null : _resourceId(patient),
      assignedAt: _optionalDate(json['assignedAt']),
    );
  }

  Map<String, Object?> toJson() => {
    'roomId': roomId,
    'number': number,
    'status': status.name,
  };
}

class OperatingRoom {
  const OperatingRoom({
    required this.id,
    required this.hospitalId,
    required this.name,
    required this.status,
    this.number = '',
    this.serviceId,
    this.isActive = true,
  });

  final String id;
  final String hospitalId;
  final String name;
  final OperatingRoomStatus status;
  final String number;
  final String? serviceId;
  final bool isActive;

  factory OperatingRoom.fromJson(Map<String, dynamic> json) => OperatingRoom(
    id: _resourceId(json['_id'] ?? json['id']),
    hospitalId: _resourceId(json['hospitalId']),
    name: json['name'] as String? ?? '',
    number: json['number']?.toString() ?? '',
    status: _operatingRoomStatus(json['status']),
    serviceId: json['serviceId'] == null
        ? null
        : _resourceId(json['serviceId']),
    isActive: json['active'] as bool? ?? true,
  );

  Map<String, Object?> toJson() => {
    'hospitalId': hospitalId,
    'name': name,
    if (number.isNotEmpty) 'number': number,
    'status': status.apiValue,
    if (serviceId != null) 'serviceId': serviceId,
    'active': isActive,
  };
}

class HospitalEquipment {
  const HospitalEquipment({
    required this.id,
    required this.hospitalId,
    required this.name,
    required this.type,
    required this.serialNumber,
    required this.status,
    this.lastMaintenanceAt,
    this.maintenanceDueAt,
    this.serviceId,
    this.operatingRoomId,
  });

  final String id;
  final String hospitalId;
  final String name;
  final String type;
  final String serialNumber;
  final EquipmentStatus status;
  final DateTime? lastMaintenanceAt;
  final DateTime? maintenanceDueAt;
  final String? serviceId;
  final String? operatingRoomId;

  factory HospitalEquipment.fromJson(Map<String, dynamic> json) =>
      HospitalEquipment(
        id: _resourceId(json['_id'] ?? json['id']),
        hospitalId: _resourceId(json['hospitalId']),
        name: json['name'] as String? ?? '',
        type: json['type'] as String? ?? '',
        serialNumber: json['serialNumber'] as String? ?? '',
        status: _enumByName(
          EquipmentStatus.values,
          json['status'],
          EquipmentStatus.functional,
        ),
        lastMaintenanceAt: _optionalDate(json['lastMaintenanceAt']),
        maintenanceDueAt: _optionalDate(json['maintenanceDueAt']),
        serviceId: json['serviceId'] == null
            ? null
            : _resourceId(json['serviceId']),
        operatingRoomId: json['operatingRoomId'] == null
            ? null
            : _resourceId(json['operatingRoomId']),
      );

  Map<String, Object?> toJson() => {
    'hospitalId': hospitalId,
    'name': name,
    'type': type,
    'serialNumber': serialNumber,
    'status': status.name,
    if (lastMaintenanceAt != null)
      'lastMaintenanceAt': lastMaintenanceAt!.toIso8601String(),
    if (maintenanceDueAt != null)
      'maintenanceDueAt': maintenanceDueAt!.toIso8601String(),
    if (serviceId != null) 'serviceId': serviceId,
    if (operatingRoomId != null) 'operatingRoomId': operatingRoomId,
  };
}

class HospitalIntervention {
  const HospitalIntervention({
    required this.id,
    required this.surgeonId,
    required this.patientId,
    required this.operatingRoomId,
    required this.title,
    required this.start,
    required this.end,
    required this.equipmentIds,
    this.serviceId,
    this.status = 'planned',
  });

  final String id;
  final String surgeonId;
  final String patientId;
  final String operatingRoomId;
  final String title;
  final DateTime start;
  final DateTime end;
  final List<String> equipmentIds;
  final String? serviceId;
  final String status;

  factory HospitalIntervention.fromJson(Map<String, dynamic> json) =>
      HospitalIntervention(
        id: _resourceId(json['_id'] ?? json['id']),
        surgeonId: _resourceId(json['surgeonId']),
        patientId: _resourceId(json['patientId']),
        operatingRoomId: _resourceId(json['operatingRoomId']),
        title: json['title'] as String? ?? '',
        start: DateTime.parse(json['start'] as String),
        end: DateTime.parse(json['end'] as String),
        equipmentIds: _idList(json['equipmentIds']),
        serviceId: json['serviceId'] == null
            ? null
            : _resourceId(json['serviceId']),
        status: json['status'] as String? ?? 'planned',
      );

  Map<String, Object?> toJson() => {
    'surgeonId': surgeonId,
    'patientId': patientId,
    'operatingRoomId': operatingRoomId,
    'title': title,
    'start': start.toIso8601String(),
    'end': end.toIso8601String(),
    'equipmentIds': equipmentIds,
    'status': status,
  };
}

class RoomOccupancy {
  const RoomOccupancy({
    required this.roomId,
    required this.capacity,
    required this.occupiedBeds,
    required this.availableBeds,
  });

  final String roomId;
  final int capacity;
  final int occupiedBeds;
  final int availableBeds;

  factory RoomOccupancy.fromJson(Map<String, dynamic> json) => RoomOccupancy(
    roomId: _resourceId(json['roomId']),
    capacity: (json['capacity'] as num? ?? 0).toInt(),
    occupiedBeds: (json['occupiedBeds'] as num? ?? 0).toInt(),
    availableBeds: (json['availableBeds'] as num? ?? 0).toInt(),
  );
}

RoomType _roomType(Object? value) {
  final normalized = value?.toString();
  return switch (normalized) {
    'double' || 'doubleRoom' => RoomType.doubleRoom,
    'intensive_care' || 'intensiveCare' => RoomType.intensiveCare,
    _ => RoomType.single,
  };
}

OperatingRoomStatus _operatingRoomStatus(Object? value) {
  final normalized = value?.toString();
  return switch (normalized) {
    'in_progress' || 'inProgress' => OperatingRoomStatus.inProgress,
    'sterilization' => OperatingRoomStatus.sterilization,
    _ => OperatingRoomStatus.free,
  };
}

String _resourceId(Object? value) {
  if (value is Map<String, dynamic>) {
    return _resourceId(value['_id'] ?? value['id']);
  }
  return value?.toString() ?? '';
}

List<String> _idList(Object? value) {
  if (value is! List) return const [];
  return value.map(_resourceId).toList();
}

T _enumByName<T extends Enum>(List<T> values, Object? value, T fallback) {
  final name = value?.toString();
  return values.firstWhere((item) => item.name == name, orElse: () => fallback);
}

DateTime? _optionalDate(Object? value) {
  if (value is! String || value.isEmpty) return null;
  return DateTime.tryParse(value);
}
