import 'package:flutter/material.dart';

import '../../../core/network/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets.dart';
import '../../services/domain/hospital_service.dart';
import '../../users/domain/staff_role.dart';
import '../../users/domain/staff_user.dart';
import '../../users/data/user_service.dart';
import '../data/hospital_demo_data.dart';
import '../data/hospital_resource_service.dart';
import '../domain/hospital_occupancy.dart';
import '../domain/hospital_resources.dart';
import '../domain/resource_permissions.dart';
import 'hospital_resource_dialogs.dart';
import 'hospital_occupancy_widgets.dart';

class HospitalTab extends StatefulWidget {
  const HospitalTab({
    super.key,
    required this.canManage,
    required this.isVisible,
    required this.hospitalsApi,
    required this.services,
    required this.users,
    this.user,
    this.useMockData = false,
  });

  final bool canManage;
  final bool isVisible;
  final HospitalResourceService hospitalsApi;
  final List<HospitalService> services;
  final List<StaffUser> users;
  final StaffUser? user;
  final bool useMockData;

  @override
  State<HospitalTab> createState() => _HospitalTabState();
}

class _HospitalTabState extends State<HospitalTab>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final _searchController = TextEditingController();
  int _activeTab = 0;
  String? _roomServiceFilterId;
  String? _roomFloorFilter;
  bool _onlyAvailableBeds = false;
  bool _onlyReservedBeds = false;
  bool _isLoading = true;
  bool _hasLoaded = false;
  String? _error;
  DateTime? _lastSyncedAt;
  String? _selectedHospitalId;
  late final List<int> _visibleTabIndices = _tabsForUser();
  List<Hospital> _hospitals = const [];
  List<HospitalRoom> _rooms = const [];
  List<HospitalBed> _beds = const [];
  List<OperatingRoom> _operatingRooms = const [];
  List<HospitalEquipment> _equipment = const [];
  List<HospitalIntervention> _interventions = const [];

  bool get _canManage => widget.canManage && !widget.useMockData;
  bool get _canManageRooms => _permission(canManageRooms);
  bool get _canManageBeds => _permission(canManageBeds);
  bool get _canChangeBedStatus => _permission(canChangeBedStatus);
  bool get _canAssignPatients => _permission(canAssignPatient);
  bool get _canManageOperatingRooms => _permission(canManageOperatingRooms);
  bool get _canChangeOperatingRoomStatus =>
      _permission(canChangeOperatingRoomStatus);
  bool get _canManageEquipment => _permission(canManageEquipment);
  bool get _isServiceManager => widget.user?.role == StaffRole.serviceHead;
  bool get _isBlockManager =>
      widget.user?.role == StaffRole.operatingRoomManager;
  bool _canChangeThisOperatingRoom(OperatingRoom room) {
    final user = widget.user;
    if (user?.role != StaffRole.nurse) return _canChangeOperatingRoomStatus;
    final assignedServices = {
      ...user!.serviceIds,
      if (user.serviceId != null) user.serviceId!,
    };
    return room.serviceId != null &&
        assignedServices.contains(room.serviceId) &&
        _services.any(
          (service) => service.id == room.serviceId && service.hasOperations,
        );
  }

  bool _permission(bool Function(StaffUser) check) =>
      !widget.useMockData &&
      (widget.user == null ? _canManage : check(widget.user!));
  List<HospitalService> get _services {
    final services = widget.useMockData
        ? HospitalDemoData.services
        : widget.services;
    final serviceId = widget.user?.serviceId;
    if (_isServiceManager && serviceId != null) {
      return services.where((service) => service.id == serviceId).toList();
    }
    if (_isBlockManager) {
      final hospital = _hospitals.where(
        (item) => item.id == widget.user?.hospitalId,
      );
      if (hospital.isNotEmpty) {
        final serviceIds = hospital.first.serviceIds.toSet();
        return services
            .where((service) => serviceIds.contains(service.id))
            .toList();
      }
    }
    return services;
  }

  String _tabLabel(int index) => switch (index) {
    0 => 'Hôpitaux',
    1 => 'Chambres et lits',
    2 => 'Bloc opératoire',
    _ => 'Matériel',
  };

  List<int> _tabsForUser() {
    final user = widget.user;
    if (user == null) return const [0, 1, 2, 3];
    return [
      0,
      if (user.role != StaffRole.operatingRoomManager) 1,
      if (user.role != StaffRole.serviceHead) 2,
      3,
    ];
  }

  @override
  void initState() {
    super.initState();
    _roomServiceFilterId = widget.user?.role == StaffRole.serviceHead
        ? widget.user?.serviceId
        : null;
    _selectedHospitalId = widget.user?.hospitalId;
    _tabController = TabController(
      length: _visibleTabIndices.length,
      vsync: this,
    )..addListener(_handleTabChange);
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

  @override
  void dispose() {
    _tabController
      ..removeListener(_handleTabChange)
      ..dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _handleTabChange() {
    final visibleIndex = _visibleTabIndices[_tabController.index];
    if (_activeTab == visibleIndex) return;
    setState(() => _activeTab = visibleIndex);
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final api = widget.hospitalsApi;
      final hospitals = widget.useMockData
          ? HospitalDemoData.hospitals
          : await api.hospitals();
      final rooms = widget.useMockData
          ? HospitalDemoData.rooms
          : await api.rooms();
      final beds = widget.useMockData
          ? HospitalDemoData.beds
          : await api.beds();
      final operatingRooms = widget.useMockData
          ? HospitalDemoData.operatingRooms
          : await api.operatingRooms();
      final equipment = widget.useMockData
          ? HospitalDemoData.equipment
          : await api.equipment();
      final interventions = widget.useMockData
          ? HospitalDemoData.interventions
          : await api.interventions();
      if (!mounted) return;
      setState(() {
        _hospitals = hospitals;
        _rooms = rooms;
        _beds = beds;
        _operatingRooms = operatingRooms;
        _equipment = equipment;
        _interventions = interventions;
        if (!_hospitals.any((hospital) => hospital.id == _selectedHospitalId)) {
          _selectedHospitalId = null;
        }
        _hasLoaded = true;
        _lastSyncedAt = DateTime.now();
      });
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = _errorMessage(error));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _perform(Future<void> Function() action) async {
    try {
      await action();
      await _load();
    } on ApiException catch (error) {
      _showMessage(_errorMessage(error));
    }
  }

  String _errorMessage(ApiException error) =>
      error.statusCode == 403 ? 'Action non autorisée' : error.message;

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

  Future<void> _editRoom([HospitalRoom? room]) async {
    if (_hospitals.isEmpty) {
      _showMessage(
        'Aucun hôpital par défaut configuré. Redémarrez le serveur backend.',
      );
      return;
    }
    final result = await showDialog<RoomDialogResult>(
      context: context,
      builder: (_) => RoomDialog(
        room: room,
        hospitals: _hospitals,
        services: _services,
        lockScope: _isServiceManager,
      ),
    );
    if (result == null || !mounted) return;
    if (room == null) {
      await _createRoomWithFirstBed(result);
    } else {
      await _perform(() => widget.hospitalsApi.updateRoom(result.room));
    }
  }

  Future<void> _createRoomWithFirstBed(RoomDialogResult result) async {
    final firstBedNumber = result.firstBedNumber;
    if (firstBedNumber == null) {
      _showMessage('Le numéro du premier lit est obligatoire.');
      return;
    }

    late final HospitalRoom createdRoom;
    try {
      createdRoom = await widget.hospitalsApi.createRoom(result.room);
    } on ApiException catch (error) {
      _showMessage(error.message);
      return;
    }

    try {
      await widget.hospitalsApi.createBed(
        HospitalBed(
          id: '',
          roomId: createdRoom.id,
          number: firstBedNumber,
          status: BedStatus.free,
        ),
      );
    } on ApiException catch (error) {
      await _load();
      _showMessage(
        'Chambre créée, mais le premier lit n’a pas pu être créé : ${error.message}',
      );
      return;
    }
    await _load();
  }

  Future<void> _deleteRoom(HospitalRoom room) async {
    if (!await _confirmDelete('cette chambre')) return;
    await _perform(() => widget.hospitalsApi.deleteRoom(room.id));
  }

  Future<void> _editBed(String roomId, [HospitalBed? bed]) async {
    if (bed == null) {
      for (final room in _rooms.where((item) => item.id == roomId)) {
        final bedCount = _beds.where((item) => item.roomId == roomId).length;
        if (bedCount >= room.bedCapacity) {
          _showMessage(
            'Cette chambre a atteint sa capacité maximale '
            '(${room.bedCapacity} lit${room.bedCapacity > 1 ? 's' : ''}).',
          );
          return;
        }
      }
    }
    final result = await showDialog<HospitalBed>(
      context: context,
      builder: (_) =>
          BedDialog(bed: bed, roomId: roomId, statusOnly: !_canManageBeds),
    );
    if (result == null || !mounted) return;
    await _perform(() async {
      if (bed == null) {
        await widget.hospitalsApi.createBed(result);
      } else if (!_canManageBeds) {
        await widget.hospitalsApi.updateBedStatus(result.id, result.status);
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
      _showMessage(
        'Aucun hôpital par défaut configuré. Redémarrez le serveur backend.',
      );
      return;
    }
    final hospitalId = room?.hospitalId ?? _hospitals.first.id;
    final nextNumber = _operatingRooms
        .where((item) => item.hospitalId == hospitalId)
        .fold(1, (next, item) => item.number >= next ? item.number + 1 : next);
    final result = await showDialog<OperatingRoom>(
      context: context,
      builder: (_) => OperatingRoomDialog(
        operatingRoom: room,
        initialNumber: nextNumber,
        hospitals: _hospitals,
        services: _services,
        lockHospital: _isBlockManager,
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

  Future<void> _setOperatingRoomStatus(
    OperatingRoom room,
    OperatingRoomStatus status,
  ) async {
    await _perform(
      () => widget.hospitalsApi.updateOperatingRoomStatus(room.id, status),
    );
  }

  Future<void> _editEquipment([HospitalEquipment? equipment]) async {
    if (_hospitals.isEmpty) {
      _showMessage(
        'Aucun hôpital par défaut configuré. Redémarrez le serveur backend.',
      );
      return;
    }
    if (_services.isEmpty && _operatingRooms.isEmpty) {
      _showMessage('Créez d’abord un service ou une salle d’opération.');
      return;
    }
    final result = await showDialog<HospitalEquipment>(
      context: context,
      builder: (_) => EquipmentDialog(
        equipment: equipment,
        operatingRooms: _operatingRooms
            .where(
              (room) =>
                  !_isServiceManager &&
                  (!_isBlockManager ||
                      room.hospitalId == widget.user?.hospitalId),
            )
            .toList(),
        hospitals: _isBlockManager
            ? _hospitals
                  .where((hospital) => hospital.id == widget.user?.hospitalId)
                  .toList()
            : _hospitals,
        services: _isServiceManager
            ? _services
            : _isBlockManager
            ? const []
            : _services,
        lockHospital: _isServiceManager || _isBlockManager,
        lockTarget: _isServiceManager || _isBlockManager,
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
              (room.status == OperatingRoomStatus.free ||
              room.id == intervention?.operatingRoomId),
        )
        .toList();
    if (schedulableRooms.isEmpty) {
      _showMessage('Aucune salle libre pour planifier une intervention.');
      return;
    }
    List<StaffUser> participants;
    try {
      participants = await UserService().listInterventionParticipants();
    } on ApiException {
      participants = widget.users;
    }
    final currentUser = widget.user;
    final currentServiceIds = {
      ...?currentUser?.serviceIds,
      if (currentUser?.serviceId != null) currentUser!.serviceId!,
    };
    final doctors = participants
        .where((user) => user.role == StaffRole.doctor && user.isActive)
        .where(
          (doctor) =>
              currentUser == null ||
              currentUser.role == StaffRole.administrator ||
              (currentUser.role == StaffRole.doctor &&
                  doctor.id == currentUser.id) ||
              (currentUser.role == StaffRole.secretary &&
                  doctor.serviceIds.any(currentServiceIds.contains)),
        )
        .toList();
    final patients = participants
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
    for (final service in _services) {
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

  Future<void> _showOperatingSchedule() {
    final upcoming =
        _interventions
            .where((item) => item.end.isAfter(DateTime.now()))
            .toList()
          ..sort((left, right) => left.start.compareTo(right.start));
    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            const ListTile(
              title: Text(
                'Planning du bloc opératoire',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            if (upcoming.isEmpty)
              const ListTile(title: Text('Aucune intervention à venir.')),
            for (final intervention in upcoming)
              ListTile(
                leading: const Icon(Icons.event_note_outlined),
                title: Text(intervention.title),
                subtitle: Text(
                  '${_operatingRoomName(intervention.operatingRoomId)} · ${_userName(intervention.surgeonId)} · ${intervention.start.toLocal()} – ${intervention.end.toLocal()}',
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget? _activeTabAction() {
    if (_activeTab == 1 && _canManageRooms) {
      return OutlinedButton.icon(
        style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
        onPressed: _editRoom,
        icon: const Icon(Icons.add),
        label: const Text('Ajouter une chambre'),
      );
    }
    if (_activeTab == 2) {
      return OutlinedButton.icon(
        style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
        onPressed: _showOperatingSchedule,
        icon: const Icon(Icons.calendar_month_outlined),
        label: const Text('Voir le planning du bloc'),
      );
    }
    if (_activeTab == 3 && _canManageEquipment) {
      return OutlinedButton.icon(
        style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
        onPressed: _editEquipment,
        icon: const Icon(Icons.add),
        label: const Text('Déclarer un équipement'),
      );
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading && !_hasLoaded) return const HospitalLoadingSkeleton();
    if (_error != null && !_hasLoaded) {
      return ErrorState(message: _error!, onRetry: _load);
    }
    final syncTime = _lastSyncedAt;
    final syncLabel = syncTime == null
        ? 'Dernière synchro : —'
        : 'Dernière synchro : ${syncTime.hour.toString().padLeft(2, '0')}:${syncTime.minute.toString().padLeft(2, '0')}';
    final tabAction = _activeTabAction();

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1180),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SectionIntro(
                    title: 'État des ressources',
                    subtitle: 'Lits, bloc opératoire et matériel',
                  ),
                  const SizedBox(height: 6),
                  Text(
                    syncLabel,
                    style: const TextStyle(
                      color: Color(0xFF536873),
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    alignment: WrapAlignment.end,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      ?tabAction,
                      IconButton(
                        tooltip: 'Actualiser les ressources',
                        onPressed: _isLoading ? null : _load,
                        constraints: const BoxConstraints.tightFor(
                          width: 48,
                          height: 48,
                        ),
                        icon: _isLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.refresh),
                      ),
                    ],
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 8),
                    Material(
                      color: const Color(0xFFFFF1E8),
                      borderRadius: BorderRadius.circular(10),
                      child: ListTile(
                        dense: true,
                        leading: const Icon(
                          Icons.cloud_off_outlined,
                          color: Color(0xFF8A3B12),
                        ),
                        title: Text(_error!),
                        trailing: TextButton(
                          onPressed: _load,
                          child: const Text('Réessayer'),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            TabBar(
              controller: _tabController,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              tabs: [
                for (final index in _visibleTabIndices)
                  Tab(text: _tabLabel(index)),
              ],
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  for (final index in _visibleTabIndices)
                    _refreshable(switch (index) {
                      0 => _hospitalList(),
                      1 => _roomList(),
                      2 => _operatingRoomListImproved(),
                      _ => _equipmentList(),
                    }),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _refreshable(Widget child) =>
      RefreshIndicator(onRefresh: _load, child: child);

  Widget _hospitalList() {
    final roomIds = _rooms
        .where(
          (room) =>
              _selectedHospitalId == null ||
              room.hospitalId == _selectedHospitalId,
        )
        .map((room) => room.id)
        .toSet();
    final visibleBeds = _beds.where((bed) => roomIds.contains(bed.roomId));
    final summary = BedOccupancySummary.fromBeds(visibleBeds);
    if (summary.total == 0) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          SizedBox(
            height: MediaQuery.sizeOf(context).height * 0.55,
            child: EmptyState(
              message: 'Aucune donnée de lits disponible',
              actionLabel: 'Voir les chambres et lits',
              onAction: () => _tabController.animateTo(1),
            ),
          ),
        ],
      );
    }

    final occupancies = calculateServiceOccupancies(
      services: _services,
      rooms: _rooms,
      beds: _beds,
      hospitalId: _selectedHospitalId,
    );
    final query = _searchController.text.trim().toLowerCase();
    final filteredOccupancies = occupancies
        .where((item) => item.service.name.toLowerCase().contains(query))
        .toList();
    final saturatedServices = occupancies
        .where((item) => item.level == OccupancyLevel.saturated)
        .length;
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      children: [
        OccupancyStatsRow(summary: summary),
        const SizedBox(height: 16),
        if (_hospitals.length > 1)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: DropdownButtonFormField<String?>(
              initialValue: _selectedHospitalId,
              decoration: const InputDecoration(
                labelText: 'Hôpital',
                prefixIcon: Icon(Icons.apartment_outlined),
                border: OutlineInputBorder(),
              ),
              items: [
                const DropdownMenuItem<String?>(
                  value: null,
                  child: Text('Tous les hôpitaux'),
                ),
                for (final hospital in _hospitals)
                  DropdownMenuItem<String?>(
                    value: hospital.id,
                    child: Text(hospital.name),
                  ),
              ],
              onChanged: (hospitalId) =>
                  setState(() => _selectedHospitalId = hospitalId),
            ),
          ),
        const Text(
          'Occupation par service',
          style: TextStyle(
            color: AppColors.navy,
            fontSize: 17,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _searchController,
          onChanged: (_) => setState(() {}),
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            hintText: 'Rechercher un service',
            prefixIcon: const Icon(Icons.search),
            suffixIcon: _searchController.text.isEmpty
                ? null
                : IconButton(
                    tooltip: 'Effacer la recherche',
                    onPressed: () {
                      _searchController.clear();
                      setState(() {});
                    },
                    icon: const Icon(Icons.clear),
                  ),
            border: const OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        if (saturatedServices > 0)
          AlertBanner(saturatedServicesCount: saturatedServices),
        if (filteredOccupancies.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Text('Aucun service correspondant à la recherche.'),
          ),
        for (final occupancy in filteredOccupancies)
          ServiceOccupancyCard(
            occupancy: occupancy,
            onTap: () => _showServiceDetails(occupancy),
          ),
      ],
    );
  }

  Future<void> _showServiceDetails(ServiceOccupancy occupancy) =>
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (_) => FractionallySizedBox(
          heightFactor: 0.75,
          child: ServiceDetailSheet(occupancy: occupancy),
        ),
      );

  Widget _roomList() {
    final serviceId = _isServiceManager
        ? widget.user?.serviceId
        : _services.any((service) => service.id == _roomServiceFilterId)
        ? _roomServiceFilterId
        : null;
    final floors =
        _rooms
            .map((room) => room.floor.trim())
            .where((floor) => floor.isNotEmpty)
            .toSet()
            .toList()
          ..sort((left, right) {
            final leftNumber = int.tryParse(left);
            final rightNumber = int.tryParse(right);
            if (leftNumber != null && rightNumber != null) {
              return leftNumber.compareTo(rightNumber);
            }
            if (leftNumber != null) return -1;
            if (rightNumber != null) return 1;
            return left.toLowerCase().compareTo(right.toLowerCase());
          });
    final floor = floors.contains(_roomFloorFilter) ? _roomFloorFilter : null;
    final roomIds = _rooms.map((room) => room.id).toSet();
    final bedsInHospital = _beds
        .where((bed) => roomIds.contains(bed.roomId))
        .toList();
    final freeCount = bedsInHospital
        .where((bed) => bed.status == BedStatus.free)
        .length;
    final occupiedCount = bedsInHospital
        .where((bed) => bed.status == BedStatus.occupied)
        .length;
    final cleaningCount = bedsInHospital
        .where((bed) => bed.status == BedStatus.cleaning)
        .length;
    final reservedCount = bedsInHospital
        .where((bed) => bed.status == BedStatus.reserved)
        .length;
    final filteredRooms = _rooms.where((room) {
      if (serviceId != null && room.serviceId != serviceId) return false;
      if (floor != null && room.floor.trim() != floor) return false;
      final roomBeds = _beds.where((bed) => bed.roomId == room.id);
      if (_onlyAvailableBeds &&
          !roomBeds.any((bed) => bed.status == BedStatus.free)) {
        return false;
      }
      if (_onlyReservedBeds &&
          !roomBeds.any((bed) => bed.status == BedStatus.reserved)) {
        return false;
      }
      return true;
    }).toList();

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      children: [
        RoomBedsStatusBar(
          freeCount: freeCount,
          occupiedCount: occupiedCount,
          cleaningCount: cleaningCount,
          reservedCount: reservedCount,
          services: _services,
          floors: floors,
          selectedServiceId: serviceId,
          onServiceChanged: (value) =>
              setState(() => _roomServiceFilterId = value),
          lockServiceFilter: _isServiceManager,
          selectedFloor: floor,
          onFloorChanged: (value) => setState(() => _roomFloorFilter = value),
          onlyAvailable: _onlyAvailableBeds,
          onOnlyAvailableChanged: (value) => setState(() {
            _onlyAvailableBeds = value;
            if (value) _onlyReservedBeds = false;
          }),
          onlyReserved: _onlyReservedBeds,
          onOnlyReservedChanged: (value) => setState(() {
            _onlyReservedBeds = value;
            if (value) _onlyAvailableBeds = false;
          }),
        ),
        const SizedBox(height: 16),
        if (_rooms.isEmpty)
          const _EmptyMessage(message: 'Aucune chambre enregistrée.')
        else if (filteredRooms.isEmpty)
          _EmptyMessage(
            message: _onlyReservedBeds
                ? 'Aucune chambre avec un lit réservé.'
                : _onlyAvailableBeds
                ? 'Aucune chambre avec un lit disponible.'
                : 'Aucune chambre pour les filtres sélectionnés.',
          )
        else
          LayoutBuilder(
            builder: (context, constraints) {
              const spacing = 16.0;
              final columnCount = constraints.maxWidth >= 740 ? 2 : 1;
              final cardWidth =
                  (constraints.maxWidth - spacing * (columnCount - 1)) /
                  columnCount;
              return Wrap(
                spacing: spacing,
                runSpacing: spacing,
                children: [
                  for (final room in filteredRooms)
                    SizedBox(
                      width: cardWidth,
                      child: RoomBedCard(
                        room: room,
                        hospitalName: _hospitalName(room.hospitalId),
                        serviceName: _serviceName(room.serviceId),
                        beds: _beds
                            .where((bed) => bed.roomId == room.id)
                            .toList(),
                        displayedBeds: _beds
                            .where(
                              (bed) =>
                                  bed.roomId == room.id &&
                                  (!_onlyAvailableBeds ||
                                      bed.status == BedStatus.free) &&
                                  (!_onlyReservedBeds ||
                                      bed.status == BedStatus.reserved),
                            )
                            .toList(),
                        canManage: _canManageBeds,
                        canChangeBedStatus: _canChangeBedStatus,
                        canAssignPatient: _canAssignPatients,
                        onAddBed: () => _editBed(room.id),
                        onEditRoom: () => _editRoom(room),
                        onDeleteRoom: () => _deleteRoom(room),
                        onEditBed: (bed) => _editBed(room.id, bed),
                        onAssignBed: _assignBed,
                        onReleaseBed: _releaseBed,
                        onDeleteBed: _deleteBed,
                        userName: _userName,
                      ),
                    ),
                ],
              );
            },
          ),
      ],
    );
  }

  // Kept for compatibility with older navigation flows.
  // ignore: unused_element
  Widget _operatingRoomList() {
    final now = DateTime.now();
    final canManageInterventions = widget.user == null
        ? widget.canManage
        : widget.user!.role == StaffRole.administrator ||
              widget.user!.role == StaffRole.doctor ||
              widget.user!.role == StaffRole.secretary;
    final upcoming =
        _interventions.where((item) => item.end.isAfter(now)).toList()
          ..sort((left, right) => left.start.compareTo(right.start));
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      children: [
        if (_canManageOperatingRooms) ...[
          _addButton('Ajouter une salle', Icons.add, _editOperatingRoom),
        ],
        if (widget.user == null
            ? widget.canManage
            : widget.user!.role == StaffRole.administrator) ...[
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
              title: Text('${room.name} · ${room.number}'),
              subtitle: Text(
                '${_hospitalName(room.hospitalId)} · ${_serviceName(room.serviceId)} · ${room.status.label}',
              ),
              trailing: _canManageOperatingRooms
                  ? _actions(
                      onEdit: () => _editOperatingRoom(room),
                      onDelete: () => _deleteOperatingRoom(room),
                    )
                  : _canChangeThisOperatingRoom(room)
                  ? PopupMenuButton<OperatingRoomStatus>(
                      tooltip: 'Changer l’état de la salle',
                      onSelected: (status) =>
                          _setOperatingRoomStatus(room, status),
                      itemBuilder: (_) => [
                        for (final status in OperatingRoomStatus.values)
                          PopupMenuItem(
                            value: status,
                            child: Text(status.label),
                          ),
                      ],
                    )
                  : null,
            ),
          ),
        ),
        const SizedBox(height: 12),
        const Padding(
          padding: EdgeInsets.only(top: 12, bottom: 8),
          child: Text(
            'Interventions planifiées',
            style: TextStyle(
              color: AppColors.navy,
              fontSize: 17,
              fontWeight: FontWeight.w700,
            ),
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
              trailing: canManageInterventions
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

  Widget _operatingRoomListImproved() {
    final now = DateTime.now();
    final canManageInterventions = widget.user == null
        ? widget.canManage
        : widget.user!.role == StaffRole.administrator ||
              widget.user!.role == StaffRole.doctor ||
              widget.user!.role == StaffRole.secretary;
    final upcoming =
        _interventions.where((item) => item.end.isAfter(now)).toList()
          ..sort((left, right) => left.start.compareTo(right.start));

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 500;
            return Row(
              children: [
                if (_canManageOperatingRooms)
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _editOperatingRoom,
                      icon: const Icon(Icons.add, size: 20),
                      label: Text(compact ? 'Salle' : 'Ajouter une salle'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF526273),
                        side: const BorderSide(color: Color(0xFF7D8A98)),
                        minimumSize: const Size.fromHeight(56),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(28),
                        ),
                      ),
                    ),
                  ),
                if (_canManageOperatingRooms && canManageInterventions)
                  const SizedBox(width: 12),
                if (canManageInterventions)
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _editIntervention,
                      icon: const Icon(Icons.add, size: 20),
                      label: Text(
                        compact ? 'Intervention' : 'Ajouter une intervention',
                        overflow: TextOverflow.ellipsis,
                      ),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF159A9C),
                        foregroundColor: Colors.white,
                        minimumSize: const Size.fromHeight(56),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(28),
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
        const SizedBox(height: 22),
        LayoutBuilder(
          builder: (context, constraints) {
            const gap = 14.0;
            final columns = constraints.maxWidth >= 420 ? 2 : 1;
            final width =
                (constraints.maxWidth - gap * (columns - 1)) / columns;
            return Wrap(
              spacing: gap,
              runSpacing: gap,
              children: [
                for (final room in _operatingRooms)
                  SizedBox(
                    width: width,
                    child: _operatingRoomCardImproved(room),
                  ),
              ],
            );
          },
        ),
        const SizedBox(height: 28),
        const Text(
          'Interventions planifiées',
          style: TextStyle(
            color: AppColors.navy,
            fontSize: 21,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 12),
        if (upcoming.isEmpty)
          const _EmptyMessage(message: 'Aucune intervention planifiée.')
        else
          for (final item in upcoming)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _interventionCardImproved(item, canManageInterventions),
            ),
      ],
    );
  }

  Widget _operatingRoomCardImproved(OperatingRoom room) {
    final statusColor = switch (room.status) {
      OperatingRoomStatus.free => const Color(0xFF159447),
      OperatingRoomStatus.inProgress => const Color(0xFFD92D4F),
      OperatingRoomStatus.sterilization => const Color(0xFFE48A00),
      OperatingRoomStatus.maintenance => const Color(0xFF6B7280),
    };
    final statusBackground = switch (room.status) {
      OperatingRoomStatus.free => const Color(0xFFDDF7E7),
      OperatingRoomStatus.inProgress => const Color(0xFFFFE4EA),
      OperatingRoomStatus.sterilization => const Color(0xFFFFF0D2),
      OperatingRoomStatus.maintenance => const Color(0xFFE9EDF1),
    };

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 8, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE1E7EC)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x160F2537),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: const Color(0xFFE3F5F6),
              borderRadius: BorderRadius.circular(13),
            ),
            child: const Icon(
              Icons.medical_services_outlined,
              color: AppColors.navy,
              size: 30,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${room.name} · ${room.number}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.black,
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    _operatingRoomActions(room),
                  ],
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: statusBackground,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    room.status.label,
                    style: TextStyle(
                      color: statusColor,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _serviceName(room.serviceId),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF53616E),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _operatingRoomActions(OperatingRoom room) {
    if (_canManageOperatingRooms) {
      return _actions(
        onEdit: () => _editOperatingRoom(room),
        onDelete: () => _deleteOperatingRoom(room),
      );
    }
    if (!_canChangeThisOperatingRoom(room)) return const SizedBox.shrink();
    return PopupMenuButton<OperatingRoomStatus>(
      padding: EdgeInsets.zero,
      icon: const Icon(Icons.more_vert, color: Color(0xFF687581)),
      onSelected: (status) => _setOperatingRoomStatus(room, status),
      itemBuilder: (_) => [
        for (final status in OperatingRoomStatus.values)
          PopupMenuItem(value: status, child: Text(status.label)),
      ],
    );
  }

  Widget _interventionCardImproved(
    HospitalIntervention item,
    bool canManageInterventions,
  ) {
    final status = item.status.toLowerCase();
    final statusLabel = switch (status) {
      'confirmed' => 'Confirmé',
      'in_progress' || 'inProgress' => 'En cours',
      'cancelled' || 'canceled' => 'Annulée',
      _ => 'À planifier',
    };
    final statusColor = status == 'confirmed'
        ? const Color(0xFF159447)
        : status == 'in_progress' || status == 'inProgress'
        ? const Color(0xFF2379B8)
        : const Color(0xFFE2A400);
    final time = MaterialLocalizations.of(context)
        .formatTimeOfDay(TimeOfDay.fromDateTime(item.start.toLocal()));

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE1E7EC)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x140F2537),
            blurRadius: 8,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          SizedBox(
            width: 62,
            child: Text(
              time,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
          ),
          Container(width: 1, height: 58, color: const Color(0xFFD8DEE4)),
          const SizedBox(width: 12),
          const Icon(Icons.medical_services_outlined, color: Color(0xFF53616E)),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  item.surgeonName.isNotEmpty
                      ? item.surgeonName
                      : _userName(item.surgeonId),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Color(0xFF53616E)),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
            decoration: BoxDecoration(
              color: statusColor,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Text(
              statusLabel,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          if (canManageInterventions)
            PopupMenuButton<String>(
              padding: EdgeInsets.zero,
              icon: const Icon(Icons.more_vert, color: Color(0xFF687581)),
              onSelected: (action) {
                if (action == 'edit') _editIntervention(item);
                if (action == 'delete') _deleteIntervention(item);
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'edit', child: Text('Modifier')),
                PopupMenuItem(value: 'delete', child: Text('Annuler')),
              ],
            ),
        ],
      ),
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
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      children: [
        _summaryCard(
          'Panne ou maintenance à prévoir',
          '$due équipement(s)',
          Icons.build_outlined,
        ),
        const SizedBox(height: 12),
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
              trailing: _canManageEquipment
                  ? PopupMenuButton<String>(
                      onSelected: (action) {
                        if (action == 'edit') _editEquipment(item);
                        if (action == 'maintenance') _markMaintenance(item);
                        if (action == 'delete') _deleteEquipment(item);
                      },
                      itemBuilder: (_) => [
                        PopupMenuItem(value: 'edit', child: Text('Modifier')),
                        if (widget.user == null
                            ? widget.canManage
                            : widget.user!.role == StaffRole.administrator)
                          const PopupMenuItem(
                            value: 'delete',
                            child: Text('Supprimer'),
                          ),
                        const PopupMenuItem(
                          value: 'maintenance',
                          child: Text('Enregistrer une maintenance'),
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
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(48),
          ),
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
