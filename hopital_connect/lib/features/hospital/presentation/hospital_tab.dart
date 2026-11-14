import 'package:flutter/material.dart';

import '../../../core/network/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets.dart';
import '../../services/domain/hospital_service.dart';
import '../../users/domain/staff_role.dart';
import '../../users/domain/staff_user.dart';
import '../data/hospital_resource_service.dart';
import '../domain/hospital_resources.dart';
import 'hospital_resource_dialogs.dart';

class HospitalTab extends StatefulWidget {
  const HospitalTab({
    super.key,
    required this.canManage,
    required this.isVisible,
    required this.hospitalsApi,
    required this.services,
    required this.users,
  });

  final bool canManage;
  final bool isVisible;
  final HospitalResourceService hospitalsApi;
  final List<HospitalService> services;
  final List<StaffUser> users;

  @override
  State<HospitalTab> createState() => _HospitalTabState();
}

class _HospitalTabState extends State<HospitalTab> {
  bool _isLoading = true;
  String? _error;
  List<Hospital> _hospitals = const [];
  List<HospitalRoom> _rooms = const [];
  List<HospitalBed> _beds = const [];
  List<OperatingRoom> _operatingRooms = const [];
  List<HospitalEquipment> _equipment = const [];
  List<HospitalIntervention> _interventions = const [];

  @override
  void initState() {
    super.initState();
    if (widget.isVisible) {
      _load();
    } else {
      _isLoading = false;
    }
  }

  @override
  void didUpdateWidget(covariant HospitalTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.isVisible && widget.isVisible) _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final api = widget.hospitalsApi;
      final hospitals = await api.hospitals();
      final rooms = await api.rooms();
      final beds = await api.beds();
      final operatingRooms = await api.operatingRooms();
      final equipment = await api.equipment();
      final interventions = await api.interventions();
      if (!mounted) return;
      setState(() {
        _hospitals = hospitals;
        _rooms = rooms;
        _beds = beds;
        _operatingRooms = operatingRooms;
        _equipment = equipment;
        _interventions = interventions;
      });
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _perform(Future<void> Function() action) async {
    try {
      await action();
      await _load();
    } on ApiException catch (error) {
      _showMessage(error.message);
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<bool> _confirmDelete(String title) async =>
      await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Supprimer $title ?'),
          content: const Text('Cette action est irréversible.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Annuler'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Supprimer'),
            ),
          ],
        ),
      ) ??
      false;

  Future<void> _editHospital([Hospital? hospital]) async {
    final result = await showDialog<Hospital>(
      context: context,
      builder: (_) =>
          HospitalDialog(hospital: hospital, services: widget.services),
    );
    if (result == null || !mounted) return;
    await _perform(() async {
      if (hospital == null) {
        await widget.hospitalsApi.createHospital(result);
      } else {
        await widget.hospitalsApi.updateHospital(result);
      }
    });
  }

  Future<void> _deleteHospital(Hospital hospital) async {
    if (!await _confirmDelete('cet hôpital')) return;
    await _perform(() => widget.hospitalsApi.deleteHospital(hospital.id));
  }

  Future<void> _editRoom([HospitalRoom? room]) async {
    if (_hospitals.isEmpty) {
      _showMessage('Créez d’abord un hôpital.');
      return;
    }
    final result = await showDialog<HospitalRoom>(
      context: context,
      builder: (_) => RoomDialog(
        room: room,
        hospitals: _hospitals,
        services: widget.services,
      ),
    );
    if (result == null || !mounted) return;
    await _perform(() async {
      if (room == null) {
        await widget.hospitalsApi.createRoom(result);
      } else {
        await widget.hospitalsApi.updateRoom(result);
      }
    });
  }

  Future<void> _deleteRoom(HospitalRoom room) async {
    if (!await _confirmDelete('cette chambre')) return;
    await _perform(() => widget.hospitalsApi.deleteRoom(room.id));
  }

  Future<void> _editBed(String roomId, [HospitalBed? bed]) async {
    final result = await showDialog<HospitalBed>(
      context: context,
      builder: (_) => BedDialog(bed: bed, roomId: roomId),
    );
    if (result == null || !mounted) return;
    await _perform(() async {
      if (bed == null) {
        await widget.hospitalsApi.createBed(result);
      } else {
        await widget.hospitalsApi.updateBed(result);
      }
    });
  }

  Future<void> _assignBed(HospitalBed bed) async {
    final patients = widget.users
        .where((user) => user.role == StaffRole.patient && user.isActive)
        .toList();
    if (patients.isEmpty) {
      _showMessage('Aucun compte patient actif à sélectionner.');
      return;
    }
    final patientId = await showDialog<String>(
      context: context,
      builder: (_) => PatientPickerDialog(patients: patients),
    );
    if (patientId == null || !mounted) return;
    await _perform(() => widget.hospitalsApi.assignBed(bed.id, patientId));
  }

  Future<void> _releaseBed(HospitalBed bed) async {
    await _perform(() => widget.hospitalsApi.releaseBed(bed.id));
  }

  Future<void> _deleteBed(HospitalBed bed) async {
    if (!await _confirmDelete('ce lit')) return;
    await _perform(() => widget.hospitalsApi.deleteBed(bed.id));
  }

  Future<void> _editOperatingRoom([OperatingRoom? room]) async {
    if (_hospitals.isEmpty) {
      _showMessage('Créez d’abord un hôpital.');
      return;
    }
    final result = await showDialog<OperatingRoom>(
      context: context,
      builder: (_) => OperatingRoomDialog(
        operatingRoom: room,
        hospitals: _hospitals,
        services: widget.services,
      ),
    );
    if (result == null || !mounted) return;
    await _perform(() async {
      if (room == null) {
        await widget.hospitalsApi.createOperatingRoom(result);
      } else {
        await widget.hospitalsApi.updateOperatingRoom(result);
      }
    });
  }

  Future<void> _deleteOperatingRoom(OperatingRoom room) async {
    if (!await _confirmDelete('cette salle d’opération')) return;
    await _perform(() => widget.hospitalsApi.deleteOperatingRoom(room.id));
  }

  Future<void> _editEquipment([HospitalEquipment? equipment]) async {
    if (_hospitals.isEmpty) {
      _showMessage('Créez d’abord un hôpital.');
      return;
    }
    if (widget.services.isEmpty && _operatingRooms.isEmpty) {
      _showMessage('Créez d’abord un service ou une salle d’opération.');
      return;
    }
    final result = await showDialog<HospitalEquipment>(
      context: context,
      builder: (_) => EquipmentDialog(
        equipment: equipment,
        hospitals: _hospitals,
        services: widget.services,
        operatingRooms: _operatingRooms,
      ),
    );
    if (result == null || !mounted) return;
    await _perform(() async {
      if (equipment == null) {
        await widget.hospitalsApi.createEquipment(result);
      } else {
        await widget.hospitalsApi.updateEquipment(result);
      }
    });
  }

  Future<void> _markMaintenance(HospitalEquipment equipment) async {
    final dates = await showDialog<({DateTime completed, DateTime? due})>(
      context: context,
      builder: (_) => MaintenanceDialog(equipment: equipment),
    );
    if (dates == null || !mounted) return;
    await _perform(
      () => widget.hospitalsApi.markMaintenance(
        equipment.id,
        lastMaintenanceAt: dates.completed,
        maintenanceDueAt: dates.due,
      ),
    );
  }

  Future<void> _deleteEquipment(HospitalEquipment equipment) async {
    if (!await _confirmDelete('ce matériel')) return;
    await _perform(() => widget.hospitalsApi.deleteEquipment(equipment.id));
  }

  Future<void> _editIntervention([HospitalIntervention? intervention]) async {
    final schedulableRooms = _operatingRooms
        .where(
          (room) =>
              room.isActive &&
              (room.status == OperatingRoomStatus.free ||
                  room.id == intervention?.operatingRoomId),
        )
        .toList();
    if (schedulableRooms.isEmpty) {
      _showMessage('Aucune salle libre pour planifier une intervention.');
      return;
    }
    final doctors = widget.users
        .where((user) => user.role == StaffRole.doctor && user.isActive)
        .toList();
    final patients = widget.users
        .where((user) => user.role == StaffRole.patient && user.isActive)
        .toList();
    if (doctors.isEmpty || patients.isEmpty) {
      _showMessage('Ajoutez un compte médecin et un compte patient actifs.');
      return;
    }
    final result = await showDialog<HospitalIntervention>(
      context: context,
      builder: (_) => InterventionDialog(
        intervention: intervention,
        doctors: doctors,
        patients: patients,
        operatingRooms: schedulableRooms,
        equipment: _equipment,
      ),
    );
    if (result == null || !mounted) return;
    await _perform(() async {
      if (intervention == null) {
        await widget.hospitalsApi.createIntervention(result);
      } else {
        await widget.hospitalsApi.updateIntervention(result);
      }
    });
  }

  Future<void> _deleteIntervention(HospitalIntervention intervention) async {
    if (!await _confirmDelete('cette intervention')) return;
    await _perform(
      () => widget.hospitalsApi.deleteIntervention(intervention.id),
    );
  }

  String _serviceName(String? id) {
    if (id == null) return 'Sans service';
    for (final service in widget.services) {
      if (service.id == id) return service.name;
    }
    return 'Service inconnu';
  }

  String _hospitalName(String id) {
    for (final hospital in _hospitals) {
      if (hospital.id == id) return hospital.name;
    }
    return 'Hôpital inconnu';
  }

  String _operatingRoomName(String id) {
    for (final room in _operatingRooms) {
      if (room.id == id) return room.name;
    }
    return 'Salle inconnue';
  }

  String _userName(String id) {
    for (final user in widget.users) {
      if (user.id == id) return user.displayName;
    }
    return 'Utilisateur autorisé';
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _load,
                icon: const Icon(Icons.refresh),
                label: const Text('Réessayer'),
              ),
            ],
          ),
        ),
      );
    }
    return DefaultTabController(
      length: 4,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Row(
              children: [
                const Expanded(
                  child: SectionIntro(
                    title: 'Ressources hospitalières',
                    subtitle: 'Lits, bloc opératoire et matériel',
                  ),
                ),
                IconButton(
                  tooltip: 'Actualiser',
                  onPressed: _load,
                  icon: const Icon(Icons.refresh),
                ),
              ],
            ),
          ),
          const TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: [
              Tab(text: 'Hôpitaux'),
              Tab(text: 'Chambres et lits'),
              Tab(text: 'Bloc opératoire'),
              Tab(text: 'Matériel'),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                _hospitalList(),
                _roomList(),
                _operatingRoomList(),
                _equipmentList(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _hospitalList() {
    final totalBeds = _beds.length;
    final occupiedBeds = _beds
        .where((bed) => bed.status == BedStatus.occupied)
        .length;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _summaryCard(
          'Lits occupés',
          '$occupiedBeds / $totalBeds',
          Icons.bed_outlined,
        ),
        const SizedBox(height: 12),
        const Text(
          'Occupation par service',
          style: TextStyle(
            color: AppColors.navy,
            fontSize: 17,
            fontWeight: FontWeight.w700,
          ),
        ),
        ...widget.services.map((service) {
          final serviceRooms = _rooms
              .where((room) => room.serviceId == service.id)
              .toList();
          final serviceBeds = _beds
              .where((bed) => serviceRooms.any((room) => room.id == bed.roomId))
              .toList();
          final occupied = serviceBeds
              .where((bed) => bed.status == BedStatus.occupied)
              .length;
          final capacity = serviceRooms.fold<int>(
            0,
            (total, room) =>
                total +
                (room.capacity > 0 ? room.capacity : _bedsIn(room).length),
          );
          final percentage = capacity == 0
              ? 0
              : (occupied * 100 / capacity).round();
          return ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.local_hospital_outlined),
            title: Text(service.name),
            subtitle: Text('$occupied / $capacity lits occupés'),
            trailing: Text('$percentage%'),
          );
        }),
        const SizedBox(height: 8),
        const Text(
          'Établissements',
          style: TextStyle(
            color: AppColors.navy,
            fontSize: 17,
            fontWeight: FontWeight.w700,
          ),
        ),
        if (widget.canManage)
          _addButton(
            'Ajouter un hôpital',
            Icons.add_business_outlined,
            _editHospital,
          ),
        ..._hospitals.map(
          (hospital) => Card(
            child: ListTile(
              leading: const CircleAvatar(
                child: Icon(Icons.local_hospital_outlined),
              ),
              title: Text(hospital.name),
              subtitle: Text(
                [
                  hospital.address,
                  if (hospital.phone.isNotEmpty) hospital.phone,
                  '${hospital.serviceIds.length} service(s)',
                  _hospitalOccupancyLabel(hospital),
                ].where((part) => part.isNotEmpty).join(' · '),
              ),
              trailing: widget.canManage
                  ? _actions(
                      onEdit: () => _editHospital(hospital),
                      onDelete: () => _deleteHospital(hospital),
                    )
                  : null,
            ),
          ),
        ),
        if (_hospitals.isEmpty)
          const _EmptyMessage(message: 'Aucun hôpital enregistré.'),
      ],
    );
  }

  List<HospitalBed> _bedsIn(HospitalRoom room) =>
      _beds.where((bed) => bed.roomId == room.id).toList();

  String _hospitalOccupancyLabel(Hospital hospital) {
    final rooms = _rooms.where((room) => room.hospitalId == hospital.id);
    final roomList = rooms.toList();
    final bedList = _beds
        .where((bed) => roomList.any((room) => room.id == bed.roomId))
        .toList();
    final occupied = bedList
        .where((bed) => bed.status == BedStatus.occupied)
        .length;
    final capacity = roomList.fold<int>(
      0,
      (total, room) =>
          total + (room.capacity > 0 ? room.capacity : _bedsIn(room).length),
    );
    final percentage = capacity == 0 ? 0 : (occupied * 100 / capacity).round();
    return 'Occupation $occupied/$capacity ($percentage%)';
  }

  Widget _roomList() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (widget.canManage)
          _addButton('Ajouter une chambre', Icons.add, _editRoom),
        ..._rooms.map((room) {
          final roomBeds = _beds.where((bed) => bed.roomId == room.id).toList();
          final freeBeds = roomBeds
              .where((bed) => bed.status == BedStatus.free)
              .length;
          final occupiedBeds = roomBeds
              .where((bed) => bed.status == BedStatus.occupied)
              .length;
          return Card(
            child: ExpansionTile(
              leading: const Icon(Icons.meeting_room_outlined),
              title: Text('Chambre ${room.number}'),
              subtitle: Text(
                '${_hospitalName(room.hospitalId)} · ${_serviceName(room.serviceId)} · ${room.type.label} · ${room.status.label}',
              ),
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '$freeBeds lit(s) libre(s) · $occupiedBeds occupé(s) · ${roomBeds.length} au total',
                    ),
                  ),
                ),
                if (widget.canManage)
                  Wrap(
                    children: [
                      TextButton.icon(
                        onPressed: () => _editBed(room.id),
                        icon: const Icon(Icons.add),
                        label: const Text('Ajouter un lit'),
                      ),
                      TextButton.icon(
                        onPressed: () => _editRoom(room),
                        icon: const Icon(Icons.edit_outlined),
                        label: const Text('Modifier'),
                      ),
                      TextButton.icon(
                        onPressed: () => _deleteRoom(room),
                        icon: const Icon(Icons.delete_outline),
                        label: const Text('Supprimer'),
                      ),
                    ],
                  ),
                ...roomBeds.map(
                  (bed) => ListTile(
                    dense: true,
                    leading: Icon(
                      bed.status == BedStatus.occupied
                          ? Icons.bed
                          : Icons.bed_outlined,
                    ),
                    title: Text('Lit ${bed.number} · ${bed.status.label}'),
                    subtitle: bed.patientId == null
                        ? null
                        : Text('Patient · ${_userName(bed.patientId!)}'),
                    trailing: widget.canManage
                        ? Wrap(
                            spacing: 0,
                            children: [
                              if (bed.status == BedStatus.free)
                                IconButton(
                                  tooltip: 'Affecter un patient',
                                  onPressed: () => _assignBed(bed),
                                  icon: const Icon(Icons.person_add_alt_1),
                                ),
                              if (bed.patientId != null)
                                IconButton(
                                  tooltip: 'Libérer le lit',
                                  onPressed: () => _releaseBed(bed),
                                  icon: const Icon(Icons.logout),
                                ),
                              PopupMenuButton<String>(
                                onSelected: (action) {
                                  if (action == 'edit') _editBed(room.id, bed);
                                  if (action == 'delete') {
                                    _deleteBed(bed);
                                  }
                                },
                                itemBuilder: (_) => const [
                                  PopupMenuItem(
                                    value: 'edit',
                                    child: Text('Modifier'),
                                  ),
                                  PopupMenuItem(
                                    value: 'delete',
                                    child: Text('Supprimer'),
                                  ),
                                ],
                              ),
                            ],
                          )
                        : null,
                  ),
                ),
                if (roomBeds.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('Aucun lit dans cette chambre.'),
                  ),
              ],
            ),
          );
        }),
        if (_rooms.isEmpty)
          const _EmptyMessage(message: 'Aucune chambre enregistrée.'),
      ],
    );
  }

  Widget _operatingRoomList() {
    final now = DateTime.now();
    final upcoming =
        _interventions.where((item) => item.end.isAfter(now)).toList()
          ..sort((left, right) => left.start.compareTo(right.start));
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (widget.canManage) ...[
          _addButton('Ajouter une salle', Icons.add, _editOperatingRoom),
          _addButton(
            'Planifier une intervention',
            Icons.event_available_outlined,
            _editIntervention,
          ),
        ],
        ..._operatingRooms.map(
          (room) => Card(
            child: ListTile(
              leading: const CircleAvatar(
                child: Icon(Icons.medical_services_outlined),
              ),
              title: Text(
                room.number.isEmpty
                    ? room.name
                    : '${room.name} · ${room.number}',
              ),
              subtitle: Text(
                '${_hospitalName(room.hospitalId)} · ${_serviceName(room.serviceId)} · ${room.status.label}',
              ),
              trailing: widget.canManage
                  ? _actions(
                      onEdit: () => _editOperatingRoom(room),
                      onDelete: () => _deleteOperatingRoom(room),
                    )
                  : null,
            ),
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'Interventions planifiées',
          style: TextStyle(
            color: AppColors.navy,
            fontSize: 17,
            fontWeight: FontWeight.w700,
          ),
        ),
        ...upcoming.map(
          (item) => Card(
            child: ListTile(
              leading: const Icon(Icons.event_note_outlined),
              title: Text(item.title),
              subtitle: Text(
                '${_operatingRoomName(item.operatingRoomId)} · ${_userName(item.surgeonId)} · ${item.start.toLocal()} – ${item.end.toLocal()}',
              ),
              trailing: widget.canManage
                  ? PopupMenuButton<String>(
                      onSelected: (action) {
                        if (action == 'edit') _editIntervention(item);
                        if (action == 'delete') _deleteIntervention(item);
                      },
                      itemBuilder: (_) => const [
                        PopupMenuItem(value: 'edit', child: Text('Modifier')),
                        PopupMenuItem(value: 'delete', child: Text('Annuler')),
                      ],
                    )
                  : null,
            ),
          ),
        ),
        if (_operatingRooms.isEmpty)
          const _EmptyMessage(message: 'Aucune salle d’opération.'),
      ],
    );
  }

  Widget _equipmentList() {
    final now = DateTime.now();
    final due = _equipment.where((item) {
      final date = item.maintenanceDueAt;
      return item.status != EquipmentStatus.functional ||
          (date != null && !date.isAfter(now));
    }).length;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _summaryCard(
          'Panne ou maintenance à prévoir',
          '$due équipement(s)',
          Icons.build_outlined,
        ),
        const SizedBox(height: 12),
        if (widget.canManage)
          _addButton('Ajouter un matériel', Icons.add, _editEquipment),
        ..._equipment.map((item) {
          final overdue =
              item.maintenanceDueAt != null &&
              !item.maintenanceDueAt!.isAfter(now);
          final assignment = item.serviceId != null
              ? _serviceName(item.serviceId)
              : item.operatingRoomId == null
              ? 'Non affecté'
              : _operatingRoomName(item.operatingRoomId!);
          return Card(
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: item.status == EquipmentStatus.functional
                    ? const Color(0xFFE1F2EF)
                    : const Color(0xFFFFE9E8),
                child: Icon(
                  item.status == EquipmentStatus.functional
                      ? Icons.medical_services_outlined
                      : Icons.warning_amber_rounded,
                ),
              ),
              title: Text(item.name),
              subtitle: Text(
                '${item.type} · N° ${item.serialNumber} · $assignment · ${item.status.label}${overdue ? ' · Maintenance à prévoir' : ''}',
              ),
              isThreeLine: true,
              trailing: widget.canManage
                  ? PopupMenuButton<String>(
                      onSelected: (action) {
                        if (action == 'edit') _editEquipment(item);
                        if (action == 'maintenance') _markMaintenance(item);
                        if (action == 'delete') _deleteEquipment(item);
                      },
                      itemBuilder: (_) => const [
                        PopupMenuItem(value: 'edit', child: Text('Modifier')),
                        PopupMenuItem(
                          value: 'maintenance',
                          child: Text('Enregistrer une maintenance'),
                        ),
                        PopupMenuItem(
                          value: 'delete',
                          child: Text('Supprimer'),
                        ),
                      ],
                    )
                  : null,
            ),
          );
        }),
        if (_equipment.isEmpty)
          const _EmptyMessage(message: 'Aucun matériel enregistré.'),
      ],
    );
  }

  Widget _summaryCard(String title, String value, IconData icon) => Card(
    color: Colors.white,
    child: ListTile(
      leading: Icon(icon, color: AppColors.blue),
      title: Text(title),
      trailing: Text(
        value,
        style: const TextStyle(
          color: AppColors.navy,
          fontWeight: FontWeight.w700,
        ),
      ),
    ),
  );

  Widget _addButton(String label, IconData icon, VoidCallback onPressed) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: OutlinedButton.icon(
          onPressed: onPressed,
          icon: Icon(icon),
          label: Text(label),
        ),
      );

  Widget _actions({
    required VoidCallback onEdit,
    required VoidCallback onDelete,
  }) => PopupMenuButton<String>(
    onSelected: (action) {
      if (action == 'edit') onEdit();
      if (action == 'delete') onDelete();
    },
    itemBuilder: (_) => const [
      PopupMenuItem(value: 'edit', child: Text('Modifier')),
      PopupMenuItem(value: 'delete', child: Text('Supprimer')),
    ],
  );
}

class _EmptyMessage extends StatelessWidget {
  const _EmptyMessage({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 30),
    child: Center(
      child: Text(message, style: const TextStyle(color: Color(0xFF687B86))),
    ),
  );
}
