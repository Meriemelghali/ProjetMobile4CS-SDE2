import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/medical_record_service.dart';
import '../../domain/medical_record.dart';
import '../widgets/record_ui.dart';
import 'sheet_frame.dart';

/// Saisie des constantes (médecin ou infirmier) avec indicateur
/// normal / à surveiller / hors norme mis à jour pendant la frappe.
class VitalsFormSheet extends StatefulWidget {
  const VitalsFormSheet({
    super.key,
    required this.patientId,
    required this.patientName,
    this.service,
  });

  final String patientId;
  final String patientName;
  final MedicalRecordService? service;

  @override
  State<VitalsFormSheet> createState() => _VitalsFormSheetState();
}

class _VitalsFormSheetState extends State<VitalsFormSheet> {
  final _systolic = TextEditingController();
  final _diastolic = TextEditingController();
  final _heartRate = TextEditingController();
  final _temperature = TextEditingController();
  final _spo2 = TextEditingController();
  final _weight = TextEditingController();
  final _glucose = TextEditingController();
  final _notes = TextEditingController();
  DateTime _recordedAt = DateTime.now();
  bool _saving = false;
  String? _error;

  List<TextEditingController> get _controllers => [
    _systolic,
    _diastolic,
    _heartRate,
    _temperature,
    _spo2,
    _weight,
    _glucose,
    _notes,
  ];

  @override
  void dispose() {
    for (final controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  double? _value(TextEditingController controller) =>
      double.tryParse(controller.text.trim().replaceAll(',', '.'));

  Future<void> _submit() async {
    final draft = VitalDraft(
      recordedAt: _recordedAt,
      systolic: _value(_systolic),
      diastolic: _value(_diastolic),
      heartRate: _value(_heartRate),
      temperature: _value(_temperature),
      spo2: _value(_spo2),
      weightKg: _value(_weight),
      glucose: _value(_glucose),
      notes: _notes.text,
    );
    if (draft.isEmpty) {
      setState(() => _error = 'Saisissez au moins une mesure.');
      return;
    }
    if ((draft.systolic == null) != (draft.diastolic == null)) {
      setState(
        () => _error = 'La tension nécessite la systolique et la diastolique.',
      );
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final vital = await (widget.service ?? MedicalRecordService()).addVitals(
        widget.patientId,
        draft,
      );
      if (mounted) Navigator.pop(context, vital);
    } catch (error) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = errorMessage(error);
        });
      }
    }
  }

  Widget _measure({
    required VitalKind kind,
    required TextEditingController controller,
    String? label,
    String? hint,
    VitalStatus? Function(double value)? classify,
  }) {
    final value = _value(controller);
    final status = value == null ? null : (classify ?? kind.classify)(value);
    final color = RecordColors.status(status);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        onChanged: (_) => setState(() {}),
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: [
          FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
        ],
        decoration: InputDecoration(
          labelText: label ?? kind.label,
          hintText: hint,
          prefixIcon: Icon(vitalIcon(kind), color: color),
          suffixIcon: Padding(
            padding: const EdgeInsets.only(right: 10),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  kind.unit,
                  style: const TextStyle(color: RecordColors.muted),
                ),
                if (status != null && kind.hasRange) ...[
                  const SizedBox(width: 8),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ],
            ),
          ),
          helperText: status == null || !kind.hasRange
              ? null
              : vitalStatusLabel(status),
          helperStyle: TextStyle(color: color, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => SheetFrame(
    title: 'Nouvelles constantes',
    subtitle: widget.patientName,
    icon: Icons.monitor_heart_outlined,
    submitLabel: 'Enregistrer les mesures',
    isSaving: _saving,
    error: _error,
    onSubmit: _submit,
    children: [
      const FieldLabel('Moment de la mesure'),
      DateField(
        value: _recordedAt,
        withTime: true,
        lastDate: DateTime.now(),
        onChanged: (value) =>
            setState(() => _recordedAt = value ?? _recordedAt),
      ),
      const FieldLabel('Tension artérielle'),
      Row(
        children: [
          Expanded(
            child: _measure(
              kind: VitalKind.bloodPressure,
              controller: _systolic,
              label: 'Systolique',
              hint: '120',
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _measure(
              kind: VitalKind.bloodPressure,
              controller: _diastolic,
              label: 'Diastolique',
              hint: '80',
              classify: classifyDiastolic,
            ),
          ),
        ],
      ),
      const FieldLabel('Autres constantes'),
      _measure(kind: VitalKind.heartRate, controller: _heartRate, hint: '72'),
      _measure(
        kind: VitalKind.temperature,
        controller: _temperature,
        hint: '36.8',
      ),
      _measure(kind: VitalKind.spo2, controller: _spo2, hint: '98'),
      _measure(kind: VitalKind.glucose, controller: _glucose, hint: '0.95'),
      _measure(kind: VitalKind.weight, controller: _weight, hint: '70.5'),
      const FieldLabel('Observation'),
      TextField(
        controller: _notes,
        maxLines: 3,
        decoration: const InputDecoration(hintText: 'Contexte de la mesure…'),
      ),
    ],
  );
}
