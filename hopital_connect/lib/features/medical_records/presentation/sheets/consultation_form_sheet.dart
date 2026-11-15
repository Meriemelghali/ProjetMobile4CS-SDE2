import 'package:flutter/material.dart';

import '../../data/medical_record_service.dart';
import '../../domain/medical_record.dart';
import 'sheet_frame.dart';

/// Création ou modification d'une consultation (médecin).
class ConsultationFormSheet extends StatefulWidget {
  const ConsultationFormSheet({
    super.key,
    required this.patientId,
    required this.patientName,
    this.initial,
    this.service,
  });

  final String patientId;
  final String patientName;
  final Consultation? initial;
  final MedicalRecordService? service;

  @override
  State<ConsultationFormSheet> createState() => _ConsultationFormSheetState();
}

class _ConsultationFormSheetState extends State<ConsultationFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final _reason = TextEditingController(text: widget.initial?.reason);
  late final _symptoms = TextEditingController(text: widget.initial?.symptoms);
  late final _examination = TextEditingController(
    text: widget.initial?.examination,
  );
  late final _diagnosis = TextEditingController(
    text: widget.initial?.diagnosis,
  );
  late final _notes = TextEditingController(text: widget.initial?.notes);
  late DateTime _date = widget.initial?.date ?? DateTime.now();
  late DateTime? _followUp = widget.initial?.followUpAt;
  bool _saving = false;
  String? _error;

  static const _quickReasons = [
    'Contrôle',
    'Bilan annuel',
    'Douleur',
    'Fièvre',
    'Résultats biologiques',
    'Renouvellement',
  ];

  @override
  void dispose() {
    for (final c in [_reason, _symptoms, _examination, _diagnosis, _notes]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    final draft = ConsultationDraft(
      date: _date,
      reason: _reason.text.trim(),
      symptoms: _symptoms.text.trim(),
      examination: _examination.text.trim(),
      diagnosis: _diagnosis.text.trim(),
      notes: _notes.text.trim(),
      followUpAt: _followUp,
    );
    final service = widget.service ?? MedicalRecordService();
    try {
      final saved = widget.initial == null
          ? await service.addConsultation(widget.patientId, draft)
          : await service.updateConsultation(widget.initial!.id, draft);
      if (mounted) Navigator.pop(context, saved);
    } catch (error) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = errorMessage(error);
        });
      }
    }
  }

  Widget _area(
    TextEditingController controller,
    String hint, {
    int lines = 3,
  }) => TextFormField(
    controller: controller,
    minLines: lines,
    maxLines: lines + 3,
    textCapitalization: TextCapitalization.sentences,
    decoration: InputDecoration(hintText: hint),
  );

  @override
  Widget build(BuildContext context) => SheetFrame(
    formKey: _formKey,
    title: widget.initial == null
        ? 'Nouvelle consultation'
        : 'Modifier la consultation',
    subtitle: widget.patientName,
    icon: Icons.medical_information_outlined,
    submitLabel: widget.initial == null ? 'Enregistrer' : 'Mettre à jour',
    isSaving: _saving,
    error: _error,
    onSubmit: _submit,
    children: [
      const FieldLabel('Date et heure'),
      DateField(
        value: _date,
        withTime: true,
        lastDate: DateTime.now().add(const Duration(days: 1)),
        onChanged: (value) => setState(() => _date = value ?? _date),
      ),
      const FieldLabel('Motif *'),
      TextFormField(
        controller: _reason,
        textCapitalization: TextCapitalization.sentences,
        decoration: const InputDecoration(
          hintText: 'Ex. Douleur thoracique',
          prefixIcon: Icon(Icons.edit_note),
        ),
        validator: (value) =>
            (value ?? '').trim().isEmpty ? 'Le motif est obligatoire.' : null,
      ),
      const SizedBox(height: 8),
      Wrap(
        spacing: 8,
        runSpacing: 4,
        children: [
          for (final reason in _quickReasons)
            ActionChip(
              label: Text(reason),
              onPressed: () => setState(() => _reason.text = reason),
            ),
        ],
      ),
      const FieldLabel('Symptômes'),
      _area(_symptoms, 'Ce que décrit le patient'),
      const FieldLabel('Examen clinique'),
      _area(_examination, 'Observations, constantes notables'),
      const FieldLabel('Diagnostic'),
      _area(_diagnosis, 'Diagnostic retenu', lines: 2),
      const FieldLabel('Conduite à tenir / notes'),
      _area(_notes, 'Traitement, examens complémentaires…'),
      const FieldLabel('Prochain contrôle'),
      DateField(
        value: _followUp,
        clearable: true,
        placeholder: 'Aucun contrôle prévu',
        firstDate: DateTime.now(),
        onChanged: (value) => setState(() => _followUp = value),
      ),
    ],
  );
}
