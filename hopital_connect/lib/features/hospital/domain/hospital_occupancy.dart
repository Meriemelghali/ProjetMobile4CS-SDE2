import 'hospital_resources.dart';
import '../../services/domain/hospital_service.dart';

enum OccupancyLevel { normal, attention, saturated }

class BedOccupancySummary {
  const BedOccupancySummary({
    required this.occupied,
    required this.free,
    required this.total,
  });

  factory BedOccupancySummary.fromBeds(Iterable<HospitalBed> beds) {
    var occupied = 0;
    var free = 0;
    var total = 0;
    for (final bed in beds) {
      total++;
      if (bed.status == BedStatus.occupied) occupied++;
      if (bed.status == BedStatus.free) free++;
    }
    return BedOccupancySummary(occupied: occupied, free: free, total: total);
  }

  final int occupied;
  final int free;
  final int total;

  double get rate => total == 0 ? 0 : occupied / total;
  int get percentage => (rate * 100).round();
}

class ServiceOccupancy {
  const ServiceOccupancy({
    required this.service,
    required this.rooms,
    required this.beds,
    required this.summary,
  });

  final HospitalService service;
  final List<HospitalRoom> rooms;
  final List<HospitalBed> beds;
  final BedOccupancySummary summary;

  OccupancyLevel get level => switch (summary.rate) {
    < 0.7 => OccupancyLevel.normal,
    <= 0.9 => OccupancyLevel.attention,
    _ => OccupancyLevel.saturated,
  };
}

List<ServiceOccupancy> calculateServiceOccupancies({
  required Iterable<HospitalService> services,
  required Iterable<HospitalRoom> rooms,
  required Iterable<HospitalBed> beds,
  String? hospitalId,
  bool onlyActive = true,
}) {
  final selectedRooms = rooms
      .where((room) => hospitalId == null || room.hospitalId == hospitalId)
      .toList();
  final filteredServices =
      onlyActive ? services.where((service) => service.isActive) : services;
  final occupancies = filteredServices.map((
    service,
  ) {
    final serviceRooms = selectedRooms
        .where((room) => room.serviceId == service.id)
        .toList();
    final roomIds = serviceRooms.map((room) => room.id).toSet();
    final serviceBeds = beds
        .where((bed) => roomIds.contains(bed.roomId))
        .toList();
    return ServiceOccupancy(
      service: service,
      rooms: serviceRooms,
      beds: serviceBeds,
      summary: BedOccupancySummary.fromBeds(serviceBeds),
    );
  }).toList();
  occupancies.sort((left, right) {
    final byRate = right.summary.rate.compareTo(left.summary.rate);
    return byRate != 0
        ? byRate
        : left.service.name.compareTo(right.service.name);
  });
  return occupancies;
}
