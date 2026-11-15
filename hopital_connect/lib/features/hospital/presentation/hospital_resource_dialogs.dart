import 'package:flutter/material.dart';

import '../../services/domain/hospital_service.dart';
import '../../users/domain/staff_user.dart';
import '../domain/hospital_resources.dart';

class HospitalDialog extends StatefulWidget {
  const HospitalDialog({super.key, this.hospital, required this.services});

  final Hospital? hospital;
  final List<HospitalService> services;

  @override
  State<HospitalDialog> createState() => _HospitalDialogState();
}

class _HospitalDialogState extends State<HospitalDialog> {
  late final _name = TextEditingController(text: widget.hospital?.name ?? '');
  late final _address = TextEditingController(
    text: widget.hospital?.address ?? '',
  );
  late final _phone = TextEditingController(text: widget.hospital?.phone ?? '');
  late final _serviceIds = Set<String>.from(
    widget.hospital?.serviceIds ?? const [],
  );
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _name.dispose();
    _address.dispose();
    _phone.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.pop(
      context,
      Hospital(
        id: widget.hospital?.id ?? '',
        name: _name.text.trim(),
        address: _address.text.trim(),
        phone: _phone.text.trim(),
        isActive: widget.hospital?.isActive ?? true,
        serviceIds: _serviceIds.toList(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => _formDialog(
    context: context,
    title: widget.hospital == null ? 'Nouvel hôpital' : 'Modifier l’hôpital',
    formKey: _formKey,
    onSubmit: _submit,
    children: [
      _textField(_name, 'Nom', required: true),
      _textField(_address, 'Adresse'),
      _textField(_phone, 'Téléphone'),
      if (widget.services.isNotEmpty) ...[
        const SizedBox(height: 8),
        const Text('Services rattachés'),
        ...widget.services.map(
          (service) => CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(service.name),
            value: _serviceIds.contains(service.id),
            onChanged: (value) => setState(() {
              if (value == true) {
                _serviceIds.add(service.id);
              } else {
                _serviceIds.remove(service.id);
              }
            }),
          ),
        ),
      ],
    ],
  );
}

class RoomDialogResult {
  const RoomDialogResult({required this.room, this.firstBedNumber});

  final HospitalRoom room;
  final int? firstBedNumber;
}

class RoomDialog extends StatefulWidget {
  const RoomDialog({
    super.key,
    this.room,
    required this.hospitals,
    required this.services,
    this.initialHospitalId,
    this.initialServiceId,
    this.lockScope = false,
  });

  final HospitalRoom? room;
  final List<Hospital> hospitals;
  final List<HospitalService> services;
  final String? initialHospitalId;
  final String? initialServiceId;
  final bool lockScope;

  @override
  State<RoomDialog> createState() => _RoomDialogState();
}

class _RoomDialogState extends State<RoomDialog> {
  late String _hospitalId = _existingOrFirst(
    widget.hospitals.map((item) => item.id),
    _preferredHospitalId(),
  );
  late String _serviceId = _existingOrFirstOrEmpty(
    _servicesFor(
      widget.services,
      widget.hospitals,
      _hospitalId,
    ).map((item) => item.id),
    widget.room?.serviceId ?? widget.initialServiceId,
  );
  late RoomType _type = widget.room?.type ?? RoomType.single;
  late RoomStatus _status = widget.room?.status ?? RoomStatus.available;
  late final _number = TextEditingController(
    text: widget.room?.number.toString() ?? '',
  );
  late final _floor = TextEditingController(text: widget.room?.floor ?? '');
  late final _capacity = TextEditingController(
    text:
        widget.room?.type == RoomType.intensiveCare && widget.room!.capacity > 0
        ? '${widget.room!.capacity}'
        : '${_defaultCapacity(_type)}',
  );
  late final _firstBedNumber = TextEditingController(text: '1');
  final _formKey = GlobalKey<FormState>();

  String? _preferredHospitalId() {
    final room = widget.room;
    if (room != null) return room.hospitalId;
    final serviceId = widget.initialServiceId;
    if (serviceId != null) {
      for (final hospital in widget.hospitals) {
        if (hospital.id == widget.initialHospitalId &&
            hospital.serviceIds.contains(serviceId)) {
          return hospital.id;
        }
      }
      for (final hospital in widget.hospitals) {
        if (hospital.serviceIds.contains(serviceId)) return hospital.id;
      }
    }
    return widget.initialHospitalId;
  }

  @override
  void dispose() {
    _number.dispose();
    _floor.dispose();
    _capacity.dispose();
    _firstBedNumber.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    if (_serviceId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Associez un service à l’hôpital.')),
      );
      return;
    }
    Navigator.pop(
      context,
      RoomDialogResult(
        room: HospitalRoom(
          id: widget.room?.id ?? '',
          hospitalId: _hospitalId,
          serviceId: _serviceId.isEmpty ? null : _serviceId,
          number: int.parse(_number.text.trim()),
          floor: _floor.text.trim(),
          type: _type,
          status: _status,
          capacity: _type == RoomType.intensiveCare
              ? int.parse(_capacity.text.trim())
              : _defaultCapacity(_type),
        ),
        firstBedNumber: widget.room == null
            ? int.parse(_firstBedNumber.text.trim())
            : null,
      ),
    );
  }

  void _selectHospital(String id) {
    final serviceIds = _servicesFor(
      widget.services,
      widget.hospitals,
      id,
    ).map((item) => item.id).toList();
    setState(() {
      _hospitalId = id;
      if (!serviceIds.contains(_serviceId)) {
        _serviceId = serviceIds.isEmpty ? '' : serviceIds.first;
      }
    });
  }

  @override
  Widget build(BuildContext context) => _formDialog(
    context: context,
    title: widget.room == null ? 'Nouvelle chambre' : 'Modifier la chambre',
    formKey: _formKey,
    onSubmit: _submit,
    children: [
      _dropdown<String>(
        value: _hospitalId,
        label: 'Hôpital',
        items: widget.hospitals
            .map(
              (item) =>
                  DropdownMenuItem(value: item.id, child: Text(item.name)),
            )
            .toList(),
        onChanged: (value) => _selectHospital(value!),
        enabled: !widget.lockScope,
      ),
      _textField(
        _number,
        'Numéro',
        required: true,
        keyboardType: TextInputType.number,
        validator: (value) => _integerRangeValidator(value, 'Numéro'),
      ),
      _textField(_floor, 'Étage'),
      _dropdown<RoomType>(
        value: _type,
        label: 'Type',
        items: const [
          DropdownMenuItem(value: RoomType.single, child: Text('Simple')),
          DropdownMenuItem(value: RoomType.doubleRoom, child: Text('Double')),
          DropdownMenuItem(
            value: RoomType.intensiveCare,
            child: Text('Soins intensifs'),
          ),
        ],
        onChanged: (value) {
          if (value == null) return;
          setState(() {
            _type = value;
            _capacity.text = '${_defaultCapacity(value)}';
          });
        },
      ),
      _dropdown<RoomStatus>(
        value: _status,
        label: 'Statut',
        items: const [
          DropdownMenuItem(
            value: RoomStatus.available,
            child: Text('Disponible'),
          ),
          DropdownMenuItem(value: RoomStatus.full, child: Text('Pleine')),
          DropdownMenuItem(
            value: RoomStatus.maintenance,
            child: Text('En maintenance'),
          ),
        ],
        onChanged: (value) => setState(() => _status = value!),
      ),
      if (_servicesFor(
        widget.services,
        widget.hospitals,
        _hospitalId,
      ).isNotEmpty)
        _dropdown<String>(
          value: _serviceId,
          label: 'Service',
          items: _servicesFor(widget.services, widget.hospitals, _hospitalId)
              .map(
                (item) =>
                    DropdownMenuItem(value: item.id, child: Text(item.name)),
              )
              .toList(),
          onChanged: (value) => setState(() => _serviceId = value ?? ''),
          enabled: !widget.lockScope,
        ),
      if (_serviceId.isEmpty)
        const Padding(
          padding: EdgeInsets.only(bottom: 12),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text('Associez au moins un service à l’hôpital.'),
          ),
        ),
      _textField(
        _capacity,
        'Capacité indicative',
        keyboardType: TextInputType.number,
        enabled: _type == RoomType.intensiveCare,
        validator: (value) => _integerRangeValidator(value, 'Capacité'),
      ),
      if (_type != RoomType.intensiveCare)
        const Padding(
          padding: EdgeInsets.only(bottom: 12),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text('Fixée automatiquement selon le type de chambre.'),
          ),
        ),
      if (widget.room == null)
        _textField(
          _firstBedNumber,
          'Numéro du premier lit',
          required: true,
          keyboardType: TextInputType.number,
          validator: (value) =>
              _integerRangeValidator(value, 'Numéro du premier lit'),
        ),
    ],
  );
}

class BedDialog extends StatefulWidget {
  const BedDialog({
    super.key,
    this.bed,
    required this.roomId,
    this.statusOnly = false,
  });

  final HospitalBed? bed;
  final String roomId;
  final bool statusOnly;

  @override
  State<BedDialog> createState() => _BedDialogState();
}

class _BedDialogState extends State<BedDialog> {
  late BedStatus _status = widget.bed?.status ?? BedStatus.free;
  late final _number = TextEditingController(
    text: widget.bed?.number.toString() ?? '',
  );
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _number.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.pop(
      context,
      HospitalBed(
        id: widget.bed?.id ?? '',
        roomId: widget.roomId,
        number: int.parse(_number.text.trim()),
        status: widget.bed?.patientId == null ? _status : BedStatus.occupied,
        patientId: widget.bed?.patientId,
        assignedAt: widget.bed?.assignedAt,
      ),
    );
  }

  @override
  Widget build(BuildContext context) => _formDialog(
    context: context,
    title: widget.bed == null ? 'Nouveau lit' : 'Modifier le lit',
    formKey: _formKey,
    onSubmit: _submit,
    children: [
      if (!widget.statusOnly)
        _textField(
          _number,
          'Numéro du lit',
          required: true,
          keyboardType: TextInputType.number,
          validator: (value) => _integerRangeValidator(value, 'Numéro du lit'),
        ),
      if (widget.bed?.patientId == null)
        _dropdown<BedStatus>(
          value: _status,
          label: 'État',
          items: const [
            DropdownMenuItem(value: BedStatus.free, child: Text('Libre')),
            DropdownMenuItem(value: BedStatus.reserved, child: Text('Réservé')),
            DropdownMenuItem(
              value: BedStatus.cleaning,
              child: Text('En nettoyage'),
            ),
          ],
          onChanged: (value) => setState(() => _status = value!),
        ),
    ],
  );
}

class OperatingRoomDialog extends StatefulWidget {
  const OperatingRoomDialog({
    super.key,
    this.operatingRoom,
    this.initialNumber = 1,
    required this.hospitals,
    required this.services,
    this.lockHospital = false,
  });

  final OperatingRoom? operatingRoom;
  final int initialNumber;
  final List<Hospital> hospitals;
  final List<HospitalService> services;
  final bool lockHospital;

  @override
  State<OperatingRoomDialog> createState() => _OperatingRoomDialogState();
}

class _OperatingRoomDialogState extends State<OperatingRoomDialog> {
  late String _hospitalId = _existingOrFirst(
    widget.hospitals.map((item) => item.id),
    widget.operatingRoom?.hospitalId,
  );
  late String _serviceId = _existingOrEmpty(
    _servicesFor(
      widget.services,
      widget.hospitals,
      _hospitalId,
    ).map((item) => item.id),
    widget.operatingRoom?.serviceId,
  );
  late OperatingRoomStatus _status =
      widget.operatingRoom?.status ?? OperatingRoomStatus.free;
  late final _name = TextEditingController(
    text: widget.operatingRoom?.name ?? '',
  );
  late final _number = TextEditingController(
    text: '${widget.operatingRoom?.number ?? widget.initialNumber}',
  );
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _name.dispose();
    _number.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.pop(
      context,
      OperatingRoom(
        id: widget.operatingRoom?.id ?? '',
        hospitalId: _hospitalId,
        name: _name.text.trim(),
        number: int.parse(_number.text.trim()),
        serviceId: _serviceId.isEmpty ? null : _serviceId,
        status: _status,
      ),
    );
  }

  void _selectHospital(String id) {
    final serviceIds = _servicesFor(
      widget.services,
      widget.hospitals,
      id,
    ).map((item) => item.id);
    setState(() {
      _hospitalId = id;
      if (!serviceIds.contains(_serviceId)) _serviceId = '';
    });
  }

  @override
  Widget build(BuildContext context) => _formDialog(
    context: context,
    title: widget.operatingRoom == null
        ? 'Nouvelle salle d’opération'
        : 'Modifier la salle',
    formKey: _formKey,
    onSubmit: _submit,
    children: [
      _dropdown<String>(
        value: _hospitalId,
        label: 'Hôpital',
        items: widget.hospitals
            .map(
              (item) =>
                  DropdownMenuItem(value: item.id, child: Text(item.name)),
            )
            .toList(),
        onChanged: (value) => _selectHospital(value!),
        enabled: !widget.lockHospital,
      ),
      _textField(_name, 'Nom', required: true),
      _textField(
        _number,
        'Numéro',
        required: true,
        keyboardType: TextInputType.number,
        validator: (value) => _positiveIntegerValidator(value, 'Numéro'),
      ),
      _dropdown<OperatingRoomStatus>(
        value: _status,
        label: 'État',
        items: const [
          DropdownMenuItem(
            value: OperatingRoomStatus.free,
            child: Text('Libre'),
          ),
          DropdownMenuItem(
            value: OperatingRoomStatus.inProgress,
            child: Text('Intervention en cours'),
          ),
          DropdownMenuItem(
            value: OperatingRoomStatus.sterilization,
            child: Text('En stérilisation'),
          ),
          DropdownMenuItem(
            value: OperatingRoomStatus.maintenance,
            child: Text('En maintenance'),
          ),
        ],
        onChanged: (value) => setState(() => _status = value!),
      ),
      if (_servicesFor(
        widget.services,
        widget.hospitals,
        _hospitalId,
      ).isNotEmpty)
        _dropdown<String>(
          value: _serviceId,
          label: 'Service (facultatif)',
          items: [
            const DropdownMenuItem(value: '', child: Text('Aucun')),
            ..._servicesFor(widget.services, widget.hospitals, _hospitalId).map(
              (item) =>
                  DropdownMenuItem(value: item.id, child: Text(item.name)),
            ),
          ],
          onChanged: (value) => setState(() => _serviceId = value ?? ''),
        ),
    ],
  );
}

class EquipmentDialog extends StatefulWidget {
  const EquipmentDialog({
    super.key,
    this.equipment,
    required this.hospitals,
    required this.services,
    required this.operatingRooms,
    this.lockHospital = false,
    this.lockTarget = false,
  });

  final HospitalEquipment? equipment;
  final List<Hospital> hospitals;
  final List<HospitalService> services;
  final List<OperatingRoom> operatingRooms;
  final bool lockHospital;
  final bool lockTarget;

  @override
  State<EquipmentDialog> createState() => _EquipmentDialogState();
}

class _EquipmentDialogState extends State<EquipmentDialog> {
  late String _hospitalId = _existingOrFirst(
    widget.hospitals.map((item) => item.id),
    widget.equipment?.hospitalId,
  );
  List<HospitalService> get _hospitalServices =>
      _servicesFor(widget.services, widget.hospitals, _hospitalId);
  List<OperatingRoom> get _hospitalOperatingRooms => widget.operatingRooms
      .where((room) => room.hospitalId == _hospitalId)
      .toList();
  late String _targetType = _initialTargetType();
  late String _targetId = _targetType == 'service'
      ? _existingOrEmpty(
          _hospitalServices.map((item) => item.id),
          widget.equipment?.serviceId,
        )
      : _existingOrEmpty(
          _hospitalOperatingRooms.map((item) => item.id),
          widget.equipment?.operatingRoomId,
        );
  late EquipmentStatus _status =
      widget.equipment?.status ?? EquipmentStatus.functional;
  late DateTime? _lastMaintenance = widget.equipment?.lastMaintenanceAt;
  late DateTime? _maintenanceDue = widget.equipment?.maintenanceDueAt;
  late final _name = TextEditingController(text: widget.equipment?.name ?? '');
  late final _type = TextEditingController(text: widget.equipment?.type ?? '');
  late final _serial = TextEditingController(
    text: widget.equipment?.serialNumber ?? '',
  );
  final _formKey = GlobalKey<FormState>();

  String _initialTargetType() {
    if (widget.equipment?.serviceId != null &&
        _hospitalServices.any(
          (service) => service.id == widget.equipment!.serviceId,
        )) {
      return 'service';
    }
    if (widget.equipment?.operatingRoomId != null &&
        _hospitalOperatingRooms.any(
          (room) => room.id == widget.equipment!.operatingRoomId,
        )) {
      return 'operatingRoom';
    }
    return _hospitalServices.isNotEmpty ? 'service' : 'operatingRoom';
  }

  @override
  void dispose() {
    _name.dispose();
    _type.dispose();
    _serial.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    if (_targetId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Choisissez une affectation valide.')),
      );
      return;
    }
    Navigator.pop(
      context,
      HospitalEquipment(
        id: widget.equipment?.id ?? '',
        hospitalId: _hospitalId,
        name: _name.text.trim(),
        type: _type.text.trim(),
        serialNumber: _serial.text.trim(),
        status: _status,
        lastMaintenanceAt: _lastMaintenance,
        maintenanceDueAt: _maintenanceDue,
        serviceId: _targetType == 'service' ? _targetId : null,
        operatingRoomId: _targetType == 'operatingRoom' ? _targetId : null,
      ),
    );
  }

  void _selectHospital(String id) {
    setState(() {
      _hospitalId = id;
      final serviceIds = _hospitalServices.map((item) => item.id);
      final operatingRoomIds = _hospitalOperatingRooms.map((item) => item.id);
      if (_targetType == 'service' && serviceIds.isEmpty) {
        _targetType = 'operatingRoom';
      } else if (_targetType == 'operatingRoom' && operatingRoomIds.isEmpty) {
        _targetType = 'service';
      }
      final targetIds = _targetType == 'service'
          ? serviceIds
          : operatingRoomIds;
      _targetId = targetIds.contains(_targetId)
          ? _targetId
          : (targetIds.isEmpty ? '' : targetIds.first);
    });
  }

  Future<void> _selectDate({required bool due}) async {
    final initial = due ? _maintenanceDue : _lastMaintenance;
    final selected = await showDatePicker(
      context: context,
      initialDate: initial ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (selected == null) return;
    setState(() {
      if (due) {
        _maintenanceDue = selected;
      } else {
        _lastMaintenance = selected;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final serviceItems = _hospitalServices;
    final operatingRoomItems = _hospitalOperatingRooms;
    final targets = _targetType == 'service'
        ? serviceItems
              .map(
                (item) =>
                    DropdownMenuItem(value: item.id, child: Text(item.name)),
              )
              .toList()
        : operatingRoomItems
              .map(
                (item) =>
                    DropdownMenuItem(value: item.id, child: Text(item.name)),
              )
              .toList();
    final targetTypes = [
      if (serviceItems.isNotEmpty)
        const DropdownMenuItem(value: 'service', child: Text('Service')),
      if (operatingRoomItems.isNotEmpty)
        const DropdownMenuItem(
          value: 'operatingRoom',
          child: Text('Salle d’opération'),
        ),
    ];
    return _formDialog(
      context: context,
      title: widget.equipment == null
          ? 'Nouveau matériel'
          : 'Modifier le matériel',
      formKey: _formKey,
      onSubmit: _submit,
      children: [
        _dropdown<String>(
          value: _hospitalId,
          label: 'Hôpital',
          items: widget.hospitals
              .map(
                (item) =>
                    DropdownMenuItem(value: item.id, child: Text(item.name)),
              )
              .toList(),
          onChanged: (value) => _selectHospital(value!),
          enabled: !widget.lockHospital,
        ),
        _textField(_name, 'Nom', required: true),
        _textField(_type, 'Type (scanner, respirateur, ECG…)', required: true),
        _textField(_serial, 'Numéro de série', required: true),
        if (targetTypes.isNotEmpty)
          _dropdown<String>(
            value: _targetType,
            label: 'Affectation',
            items: targetTypes,
            enabled: !widget.lockTarget,
            onChanged: (value) => setState(() {
              _targetType = value!;
              final ids = _targetType == 'service'
                  ? serviceItems.map((item) => item.id)
                  : operatingRoomItems.map((item) => item.id);
              _targetId = ids.isEmpty ? '' : ids.first;
            }),
          )
        else
          const Text('Aucun service ou bloc rattaché à cet hôpital.'),
        if (targets.isEmpty)
          const Text('Aucune cible disponible pour ce type d’affectation.')
        else
          _dropdown<String>(
            value: _targetId,
            label: _targetType == 'service' ? 'Service' : 'Salle d’opération',
            items: targets,
            onChanged: (value) => setState(() => _targetId = value!),
            enabled: !widget.lockTarget,
          ),
        _dropdown<EquipmentStatus>(
          value: _status,
          label: 'État',
          items: const [
            DropdownMenuItem(
              value: EquipmentStatus.functional,
              child: Text('Fonctionnel'),
            ),
            DropdownMenuItem(
              value: EquipmentStatus.broken,
              child: Text('En panne'),
            ),
            DropdownMenuItem(
              value: EquipmentStatus.maintenance,
              child: Text('En maintenance'),
            ),
          ],
          onChanged: (value) => setState(() => _status = value!),
        ),
        _dateButton(
          label: 'Dernière maintenance',
          value: _lastMaintenance,
          onPressed: () => _selectDate(due: false),
          onClear: () => setState(() => _lastMaintenance = null),
        ),
        _dateButton(
          label: 'Maintenance à prévoir',
          value: _maintenanceDue,
          onPressed: () => _selectDate(due: true),
          onClear: () => setState(() => _maintenanceDue = null),
        ),
      ],
    );
  }
}

class MaintenanceDialog extends StatefulWidget {
  const MaintenanceDialog({super.key, required this.equipment});

  final HospitalEquipment equipment;

  @override
  State<MaintenanceDialog> createState() => _MaintenanceDialogState();
}

class _MaintenanceDialogState extends State<MaintenanceDialog> {
  late DateTime _completed =
      widget.equipment.lastMaintenanceAt ?? DateTime.now();
  late DateTime? _due = widget.equipment.maintenanceDueAt;

  Future<void> _selectDate({required bool due}) async {
    final selected = await showDatePicker(
      context: context,
      initialDate: due ? (_due ?? DateTime.now()) : _completed,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (selected == null) return;
    setState(() {
      if (due) {
        _due = selected;
      } else {
        _completed = selected;
      }
    });
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Enregistrer la maintenance'),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _dateButton(
          label: 'Maintenance effectuée',
          value: _completed,
          onPressed: () => _selectDate(due: false),
        ),
        _dateButton(
          label: 'Prochaine échéance',
          value: _due,
          onPressed: () => _selectDate(due: true),
          onClear: () => setState(() => _due = null),
        ),
      ],
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Annuler'),
      ),
      FilledButton(
        onPressed: () =>
            Navigator.pop(context, (completed: _completed, due: _due)),
        child: const Text('Enregistrer'),
      ),
    ],
  );
}

class InterventionDialog extends StatefulWidget {
  const InterventionDialog({
    super.key,
    this.intervention,
    required this.doctors,
    required this.patients,
    required this.operatingRooms,
    required this.equipment,
  });

  final HospitalIntervention? intervention;
  final List<StaffUser> doctors;
  final List<StaffUser> patients;
  final List<OperatingRoom> operatingRooms;
  final List<HospitalEquipment> equipment;

  @override
  State<InterventionDialog> createState() => _InterventionDialogState();
}

class _InterventionDialogState extends State<InterventionDialog> {
  late String _doctorId = _existingOrFirst(
    widget.doctors.map((item) => item.id),
    widget.intervention?.surgeonId,
  );
  late String _patientId = _existingOrFirst(
    widget.patients.map((item) => item.id),
    widget.intervention?.patientId,
  );
  late String _roomId = _existingOrFirst(
    widget.operatingRooms.map((item) => item.id),
    widget.intervention?.operatingRoomId,
  );
  late String _status = widget.intervention?.status ?? 'planned';
  late DateTime _start =
      widget.intervention?.start ??
      DateTime.now().add(const Duration(hours: 1));
  late DateTime _end =
      widget.intervention?.end ?? DateTime.now().add(const Duration(hours: 2));
  late final Set<String> _equipmentIds = Set<String>.from(
    widget.intervention?.equipmentIds ?? const [],
  );
  late final _title = TextEditingController(
    text: widget.intervention?.title ?? '',
  );
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  Future<DateTime?> _pickDateTime(DateTime initial) async {
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
    );
    if (date == null || !mounted) return null;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (time == null) return null;
    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    if (!_end.isAfter(_start)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('La fin doit être après le début.')),
      );
      return;
    }
    Navigator.pop(
      context,
      HospitalIntervention(
        id: widget.intervention?.id ?? '',
        surgeonId: _doctorId,
        patientId: _patientId,
        operatingRoomId: _roomId,
        title: _title.text.trim(),
        start: _start,
        end: _end,
        equipmentIds: _equipmentIds.toList(),
        status: _status,
      ),
    );
  }

  @override
  Widget build(BuildContext context) => _formDialog(
    context: context,
    title: widget.intervention == null
        ? 'Planifier une intervention'
        : 'Modifier l’intervention',
    formKey: _formKey,
    onSubmit: _submit,
    children: [
      _textField(_title, 'Intervention', required: true),
      _dropdown<String>(
        value: _doctorId,
        label: 'Chirurgien',
        items: widget.doctors
            .map(
              (item) => DropdownMenuItem(
                value: item.id,
                child: Text(item.displayName),
              ),
            )
            .toList(),
        onChanged: (value) => setState(() => _doctorId = value!),
      ),
      _dropdown<String>(
        value: _patientId,
        label: 'Patient (compte de démonstration)',
        items: widget.patients
            .map(
              (item) => DropdownMenuItem(
                value: item.id,
                child: Text(item.displayName),
              ),
            )
            .toList(),
        onChanged: (value) => setState(() => _patientId = value!),
      ),
      _dropdown<String>(
        value: _roomId,
        label: 'Salle d’opération',
        items: widget.operatingRooms
            .map(
              (item) =>
                  DropdownMenuItem(value: item.id, child: Text(item.name)),
            )
            .toList(),
        onChanged: (value) => setState(() => _roomId = value!),
      ),
      _dateButton(
        label: 'Début',
        value: _start,
        includeTime: true,
        onPressed: () async {
          final value = await _pickDateTime(_start);
          if (value != null) setState(() => _start = value);
        },
      ),
      _dateButton(
        label: 'Fin',
        value: _end,
        includeTime: true,
        onPressed: () async {
          final value = await _pickDateTime(_end);
          if (value != null) setState(() => _end = value);
        },
      ),
      _dropdown<String>(
        value: _status,
        label: 'Statut',
        items: const [
          DropdownMenuItem(value: 'planned', child: Text('Planifiée')),
          DropdownMenuItem(value: 'cancelled', child: Text('Annulée')),
          DropdownMenuItem(value: 'completed', child: Text('Terminée')),
        ],
        onChanged: (value) => setState(() => _status = value!),
      ),
      if (widget.equipment.isNotEmpty) ...[
        const SizedBox(height: 8),
        const Text('Matériel nécessaire'),
        ...widget.equipment
            .where((item) {
              final room = widget.operatingRooms.firstWhere(
                (candidate) => candidate.id == _roomId,
              );
              return item.status == EquipmentStatus.functional &&
                  (item.maintenanceDueAt == null ||
                      item.maintenanceDueAt!.isAfter(_start)) &&
                  (item.operatingRoomId == _roomId ||
                      (item.serviceId != null &&
                          item.serviceId == room.serviceId));
            })
            .map(
              (item) => CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(item.name),
                subtitle: Text(item.serialNumber),
                value: _equipmentIds.contains(item.id),
                onChanged: (value) => setState(() {
                  if (value == true) {
                    _equipmentIds.add(item.id);
                  } else {
                    _equipmentIds.remove(item.id);
                  }
                }),
              ),
            ),
      ],
    ],
  );
}

class PatientPickerDialog extends StatefulWidget {
  const PatientPickerDialog({super.key, required this.patients});

  final List<StaffUser> patients;

  @override
  State<PatientPickerDialog> createState() => _PatientPickerDialogState();
}

class _PatientPickerDialogState extends State<PatientPickerDialog> {
  String? _selectedId;

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Affecter un patient au lit'),
    content: DropdownButtonFormField<String>(
      initialValue: _selectedId,
      decoration: const InputDecoration(labelText: 'Patient'),
      items: widget.patients
          .map(
            (patient) => DropdownMenuItem(
              value: patient.id,
              child: Text(patient.displayName),
            ),
          )
          .toList(),
      onChanged: (value) => setState(() => _selectedId = value),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Annuler'),
      ),
      FilledButton(
        onPressed: _selectedId == null
            ? null
            : () => Navigator.pop(context, _selectedId),
        child: const Text('Affecter'),
      ),
    ],
  );
}

Widget _formDialog({
  required BuildContext context,
  required String title,
  required GlobalKey<FormState> formKey,
  required VoidCallback onSubmit,
  required List<Widget> children,
}) => AlertDialog(
  title: Text(title),
  content: SizedBox(
    width: 460,
    child: Form(
      key: formKey,
      child: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, children: children),
      ),
    ),
  ),
  actions: [
    TextButton(
      onPressed: () => Navigator.pop(context),
      child: const Text('Annuler'),
    ),
    FilledButton(onPressed: onSubmit, child: const Text('Enregistrer')),
  ],
);

Widget _textField(
  TextEditingController controller,
  String label, {
  bool required = false,
  bool enabled = true,
  TextInputType? keyboardType,
  String? Function(String?)? validator,
}) => Padding(
  padding: const EdgeInsets.only(bottom: 12),
  child: TextFormField(
    controller: controller,
    enabled: enabled,
    keyboardType: keyboardType,
    decoration: InputDecoration(labelText: label),
    validator:
        validator ??
        (required
            ? (value) => value == null || value.trim().isEmpty
                  ? 'Champ obligatoire'
                  : null
            : null),
  ),
);

Widget _dropdown<T>({
  required T value,
  required String label,
  required List<DropdownMenuItem<T>> items,
  required ValueChanged<T?> onChanged,
  bool enabled = true,
}) => Padding(
  padding: const EdgeInsets.only(bottom: 12),
  child: DropdownButtonFormField<T>(
    initialValue: value,
    decoration: InputDecoration(labelText: label),
    items: items,
    onChanged: enabled ? onChanged : null,
    validator: (selected) => selected == null ? 'Choisissez une valeur' : null,
  ),
);

Widget _dateButton({
  required String label,
  required DateTime? value,
  required VoidCallback onPressed,
  bool includeTime = false,
  VoidCallback? onClear,
}) => Padding(
  padding: const EdgeInsets.only(bottom: 12),
  child: Row(
    children: [
      Expanded(
        child: OutlinedButton.icon(
          onPressed: onPressed,
          icon: const Icon(Icons.calendar_today_outlined),
          label: Text(
            value == null
                ? label
                : '$label : ${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}'
                      '${includeTime ? ' à ${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}' : ''}',
          ),
        ),
      ),
      if (onClear != null && value != null)
        IconButton(
          tooltip: 'Effacer la date',
          onPressed: onClear,
          icon: const Icon(Icons.close),
        ),
    ],
  ),
);

String _existingOrFirst(Iterable<String> values, String? preferred) {
  if (preferred != null && values.contains(preferred)) return preferred;
  return values.first;
}

String _existingOrEmpty(Iterable<String> values, String? preferred) {
  if (preferred != null && values.contains(preferred)) return preferred;
  return '';
}

String _existingOrFirstOrEmpty(Iterable<String> values, String? preferred) {
  final candidates = values.toList();
  if (preferred != null && candidates.contains(preferred)) return preferred;
  return candidates.isEmpty ? '' : candidates.first;
}

String? _integerRangeValidator(
  String? value,
  String label, {
  bool optional = false,
}) {
  final normalized = value?.trim() ?? '';
  if (optional && normalized.isEmpty) return null;
  final number = int.tryParse(normalized);
  if (number == null || number < 1 || number > 500) {
    return '$label doit être un entier entre 1 et 500.';
  }
  return null;
}

String? _positiveIntegerValidator(String? value, String label) {
  final number = int.tryParse(value?.trim() ?? '');
  if (number == null || number < 1) {
    return '$label doit être un entier positif.';
  }
  return null;
}

int _defaultCapacity(RoomType type) => type == RoomType.doubleRoom ? 2 : 1;

List<HospitalService> _servicesFor(
  List<HospitalService> services,
  List<Hospital> hospitals,
  String hospitalId,
) {
  final hospital = hospitals.where((item) => item.id == hospitalId);
  if (hospital.isEmpty) return const [];
  final serviceIds = hospital.first.serviceIds.toSet();
  return services.where((service) => serviceIds.contains(service.id)).toList();
}
