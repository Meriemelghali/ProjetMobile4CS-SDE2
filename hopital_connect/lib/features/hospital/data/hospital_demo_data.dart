import '../domain/hospital_resources.dart';
import '../../services/domain/hospital_service.dart';

class HospitalDemoData {
  HospitalDemoData._();

  static const hospitals = [
    Hospital(id: 'demo-hospital', name: 'Hôpital Démo'),
  ];

  static const services = [
    HospitalService(
      id: 'demo-pediatrics',
      name: 'Pédiatrie',
      location: 'Bâtiment A · 1er étage',
      description: 'Unité de pédiatrie',
      serviceType: ServiceType.medical,
    ),
    HospitalService(
      id: 'demo-emergency',
      name: 'Urgences',
      location: 'Bâtiment principal · RDC',
      description: 'Service des urgences',
      serviceType: ServiceType.emergency,
    ),
    HospitalService(
      id: 'demo-surgery',
      name: 'Chirurgie',
      location: 'Bâtiment B · 2e étage',
      description: 'Service de chirurgie',
      serviceType: ServiceType.surgical,
    ),
    HospitalService(
      id: 'demo-maternity',
      name: 'Maternité',
      location: 'Bâtiment A · 2e étage',
      description: 'Service de maternité',
      serviceType: ServiceType.maternity,
    ),
  ];

  static const rooms = [
    HospitalRoom(
      id: 'demo-room-pediatrics',
      hospitalId: 'demo-hospital',
      serviceId: 'demo-pediatrics',
      number: 101,
      floor: '1',
      type: RoomType.doubleRoom,
      status: RoomStatus.full,
      capacity: 10,
    ),
    HospitalRoom(
      id: 'demo-room-emergency',
      hospitalId: 'demo-hospital',
      serviceId: 'demo-emergency',
      number: 1,
      floor: 'RDC',
      type: RoomType.intensiveCare,
      status: RoomStatus.available,
      capacity: 10,
    ),
    HospitalRoom(
      id: 'demo-room-surgery',
      hospitalId: 'demo-hospital',
      serviceId: 'demo-surgery',
      number: 201,
      floor: '2',
      type: RoomType.doubleRoom,
      status: RoomStatus.available,
      capacity: 10,
    ),
    HospitalRoom(
      id: 'demo-room-maternity',
      hospitalId: 'demo-hospital',
      serviceId: 'demo-maternity',
      number: 202,
      floor: '2',
      type: RoomType.doubleRoom,
      status: RoomStatus.available,
      capacity: 8,
    ),
  ];

  static final beds = [
    ..._beds('demo-room-pediatrics', 10, 10, 'PED'),
    ..._beds('demo-room-emergency', 10, 7, 'URG'),
    ..._beds('demo-room-surgery', 10, 6, 'CHI'),
    ..._beds('demo-room-maternity', 8, 4, 'MAT'),
  ];

  static const operatingRooms = [
    OperatingRoom(
      id: 'demo-or-1',
      hospitalId: 'demo-hospital',
      name: 'Bloc 1',
      number: 1,
      serviceId: 'demo-surgery',
      status: OperatingRoomStatus.free,
    ),
    OperatingRoom(
      id: 'demo-or-2',
      hospitalId: 'demo-hospital',
      name: 'Bloc 2',
      number: 2,
      serviceId: 'demo-surgery',
      status: OperatingRoomStatus.inProgress,
    ),
  ];

  static final equipment = [
    const HospitalEquipment(
      id: 'demo-eq-1',
      hospitalId: 'demo-hospital',
      name: 'Moniteur multiparamétrique',
      type: 'Surveillance',
      serialNumber: 'DEMO-001',
      status: EquipmentStatus.functional,
      serviceId: 'demo-emergency',
    ),
    const HospitalEquipment(
      id: 'demo-eq-2',
      hospitalId: 'demo-hospital',
      name: 'Respirateur',
      type: 'Assistance respiratoire',
      serialNumber: 'DEMO-002',
      status: EquipmentStatus.maintenance,
      serviceId: 'demo-pediatrics',
    ),
    const HospitalEquipment(
      id: 'demo-eq-3',
      hospitalId: 'demo-hospital',
      name: 'Échographe',
      type: 'Imagerie',
      serialNumber: 'DEMO-003',
      status: EquipmentStatus.functional,
      serviceId: 'demo-maternity',
    ),
  ];

  static final interventions = [
    HospitalIntervention(
      id: 'demo-intervention-1',
      surgeonId: 'demo-doctor',
      patientId: 'demo-patient',
      operatingRoomId: 'demo-or-1',
      title: 'Intervention de démonstration',
      start: DateTime.now().add(const Duration(hours: 2)),
      end: DateTime.now().add(const Duration(hours: 3)),
      equipmentIds: const ['demo-eq-1'],
      serviceId: 'demo-surgery',
    ),
  ];

  static List<HospitalBed> _beds(
    String roomId,
    int total,
    int occupied,
    String prefix,
  ) => List.generate(
    total,
    (index) => HospitalBed(
      id: '$prefix-${index + 1}',
      roomId: roomId,
      number: index + 1,
      status: index < occupied ? BedStatus.occupied : BedStatus.free,
      patientId: index < occupied ? 'demo-patient-${index + 1}' : null,
    ),
  );
}
