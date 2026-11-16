import 'package:flutter/material.dart';

import '../../../core/network/api_client.dart';
import '../../appointments/domain/appointment.dart';
import '../data/pharmacy_service.dart';
import '../domain/pharmacy_models.dart';

class DoctorPrescriptionsTab extends StatefulWidget {
  const DoctorPrescriptionsTab({super.key, required this.appointments});

  final List<Appointment> appointments;

  @override
  State<DoctorPrescriptionsTab> createState() => _DoctorPrescriptionsTabState();
}

class _DoctorPrescriptionsTabState extends State<DoctorPrescriptionsTab> {
  final _service = PharmacyService();
  List<Medication> _medications = const [];
  bool _loading = true;
  String? _error;

  List<Appointment> get _eligibleAppointments => widget.appointments
      .where(
        (item) =>
            item.status == AppointmentStatus.inProgress ||
            item.status == AppointmentStatus.completed,
      )
      .toList();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final medications = await _service.medications();
      if (!mounted) return;
      setState(() {
        _medications = medications;
        _loading = false;
        _error = null;
      });
    } on ApiException catch (error) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = error.message;
        });
      }
    }
  }

  Future<void> _create() async {
    final draft = await showDialog<_PrescriptionDraft>(
      context: context,
      builder: (_) => _PrescriptionDialog(
        appointments: _eligibleAppointments,
        medications: _medications,
      ),
    );
    if (draft == null) return;
    try {
      await _service.createPrescription({
        'appointmentId': draft.appointmentId,
        'medications': draft.medications
            .map(
              (item) => {
                'medicationId': item.medicationId,
                'quantity': item.quantity,
              },
            )
            .toList(),
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ordonnance envoyée à la pharmacie.')),
        );
      }
    } on ApiException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.message)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: FilledButton.icon(
          onPressed: _load,
          icon: const Icon(Icons.refresh),
          label: Text(_error!),
        ),
      );
    }
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text(
          'Ordonnances',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        const Text(
          'Créez une ordonnance depuis une consultation en cours ou terminée.',
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: _eligibleAppointments.isEmpty || _medications.isEmpty
              ? null
              : _create,
          icon: const Icon(Icons.add),
          label: const Text('Écrire une ordonnance'),
        ),
        if (_eligibleAppointments.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 24),
            child: Text('Aucune consultation en cours ou terminée.'),
          ),
        if (_medications.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 12),
            child: Text('Aucun médicament disponible dans le catalogue.'),
          ),
      ],
    );
  }
}

class _PrescriptionDraft {
  const _PrescriptionDraft({
    required this.appointmentId,
    required this.medications,
  });

  final String appointmentId;
  final List<_PrescriptionMedicationDraft> medications;
}

class _PrescriptionMedicationDraft {
  const _PrescriptionMedicationDraft({
    required this.medicationId,
    required this.quantity,
  });

  final String medicationId;
  final int quantity;
}

class _PrescriptionDialog extends StatefulWidget {
  const _PrescriptionDialog({
    required this.appointments,
    required this.medications,
  });

  final List<Appointment> appointments;
  final List<Medication> medications;

  @override
  State<_PrescriptionDialog> createState() => _PrescriptionDialogState();
}

class _PrescriptionDialogState extends State<_PrescriptionDialog> {
  late String _appointmentId = widget.appointments.first.id;
  late final List<_MedicationLineState> _lines = [
    _MedicationLineState(widget.medications.first.id),
  ];

  @override
  void dispose() {
    for (final line in _lines) {
      line.dispose();
    }
    super.dispose();
  }

  void _addLine() {
    final available = widget.medications.where(
      (medication) => !_lines.any((line) => line.medicationId == medication.id),
    );
    if (available.isEmpty) return;
    final medication = available.first;
    setState(() => _lines.add(_MedicationLineState(medication.id)));
  }

  void _removeLine(int index) {
    if (_lines.length == 1) return;
    final line = _lines.removeAt(index);
    line.dispose();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Nouvelle ordonnance'),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DropdownButtonFormField<String>(
            initialValue: _appointmentId,
            decoration: const InputDecoration(labelText: 'Consultation'),
            items: widget.appointments
                .map(
                  (item) => DropdownMenuItem(
                    value: item.id,
                    child: Text(
                      '${item.patientName} · ${item.startAt.day}/${item.startAt.month}',
                    ),
                  ),
                )
                .toList(),
            onChanged: (value) => setState(() => _appointmentId = value!),
          ),
          const SizedBox(height: 12),
          ..._lines.asMap().entries.map((entry) {
            final index = entry.key;
            final line = entry.value;
            final selectedIds = _lines
                .where((item) => item != line)
                .map((item) => item.medicationId)
                .toSet();
            final options = widget.medications
                .where((medication) => !selectedIds.contains(medication.id))
                .toList();
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: line.medicationId,
                      decoration: InputDecoration(
                        labelText: 'Médicament ${index + 1}',
                      ),
                      items: options
                          .map(
                            (item) => DropdownMenuItem(
                              value: item.id,
                              child: Text('${item.name} ${item.dosage}'),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => line.medicationId = value);
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 90,
                    child: TextField(
                      controller: line.quantity,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Quantité'),
                    ),
                  ),
                  IconButton(
                    onPressed: _lines.length == 1
                        ? null
                        : () => _removeLine(index),
                    icon: const Icon(Icons.delete_outline),
                    tooltip: 'Supprimer',
                  ),
                ],
              ),
            );
          }),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: _lines.length == widget.medications.length
                  ? null
                  : _addLine,
              icon: const Icon(Icons.add),
              label: const Text('Ajouter un médicament'),
            ),
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Annuler'),
      ),
      FilledButton(
        onPressed: () {
          final medications = <_PrescriptionMedicationDraft>[];
          for (final line in _lines) {
            final quantity = int.tryParse(line.quantity.text);
            if (quantity == null || quantity <= 0) return;
            medications.add(
              _PrescriptionMedicationDraft(
                medicationId: line.medicationId,
                quantity: quantity,
              ),
            );
          }
          Navigator.pop(
            context,
            _PrescriptionDraft(
              appointmentId: _appointmentId,
              medications: medications,
            ),
          );
        },
        child: const Text('Envoyer'),
      ),
    ],
  );
}

class _MedicationLineState {
  _MedicationLineState(this.medicationId);

  String medicationId;
  final quantity = TextEditingController(text: '1');

  void dispose() => quantity.dispose();
}
