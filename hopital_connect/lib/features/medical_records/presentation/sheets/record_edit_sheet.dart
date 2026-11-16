import 'package:flutter/material.dart';

import '../../data/medical_record_service.dart';
import '../../domain/medical_record.dart';
import '../widgets/record_ui.dart';
import 'sheet_frame.dart';

/// Édition des informations de fond du dossier (médecin).
class RecordEditSheet extends StatefulWidget {
  const RecordEditSheet({
    super.key,
    required this.patientId,
    required this.patientName,
    required this.record,
    this.service,
  });

  final String patientId;
  final String patientName;
  final MedicalRecord record;
  final MedicalRecordService? service;

  @override
  State<RecordEditSheet> createState() => _RecordEditSheetState();
}

class _RecordEditSheetState extends State<RecordEditSheet> {
  late BloodType _bloodType = widget.record.bloodType;
  late final _height = TextEditingController(
    text: widget.record.heightCm?.round().toString() ?? '',
  );
  late final List<Allergy> _allergies = widget.record.allergies
      .where((allergy) => !allergy.declaredByPatient)
      .toList();
  late final List<ChronicCondition> _conditions = [
    ...widget.record.chronicConditions,
  ];
  late final List<String> _medical = [...widget.record.history.medical];
  late final List<String> _surgical = [...widget.record.history.surgical];
  late final List<String> _family = [...widget.record.history.family];
  late final List<Treatment> _treatments = [...widget.record.currentTreatments];
  late final List<Vaccination> _vaccinations = [...widget.record.vaccinations];
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _height.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final heightText = _height.text.trim();
    final height = heightText.isEmpty ? null : double.tryParse(heightText);
    if (heightText.isNotEmpty &&
        (height == null || height < 30 || height > 260)) {
      setState(
        () => _error = 'La taille doit être comprise entre 30 et 260 cm.',
      );
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final record = MedicalRecord(
      bloodType: _bloodType,
      heightCm: height,
      allergies: _allergies,
      chronicConditions: _conditions,
      history: MedicalHistory(
        medical: _medical,
        surgical: _surgical,
        family: _family,
      ),
      currentTreatments: _treatments,
      vaccinations: _vaccinations,
    );
    try {
      final saved = await (widget.service ?? MedicalRecordService())
          .updateRecord(widget.patientId, record);
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

  // --- Dialogues d'ajout ----------------------------------------------------

  Future<Map<String, String>?> _ask(
    String title,
    List<String> fields, {
    List<String> required = const [],
  }) {
    final controllers = {for (final f in fields) f: TextEditingController()};
    return showDialog<Map<String, String>>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final field in fields)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: TextField(
                  controller: controllers[field],
                  autofocus: field == fields.first,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(labelText: field),
                ),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () {
              final values = {
                for (final entry in controllers.entries)
                  entry.key: entry.value.text.trim(),
              };
              if (required.any((field) => values[field]!.isEmpty)) return;
              Navigator.pop(context, values);
            },
            child: const Text('Ajouter'),
          ),
        ],
      ),
    );
  }

  Future<void> _addAllergy() async {
    final values = await _ask(
      'Nouvelle allergie',
      ['Allergène', 'Réaction'],
      required: ['Allergène'],
    );
    if (values == null) return;
    setState(
      () => _allergies.add(
        Allergy(
          name: values['Allergène']!,
          reaction: values['Réaction']!,
          severity: AllergySeverity.moderate,
        ),
      ),
    );
  }

  Future<void> _addCondition() async {
    final values = await _ask(
      'Pathologie chronique',
      ['Pathologie', 'Notes'],
      required: ['Pathologie'],
    );
    if (values == null) return;
    setState(
      () => _conditions.add(
        ChronicCondition(name: values['Pathologie']!, notes: values['Notes']!),
      ),
    );
  }

  Future<void> _addTreatment() async {
    final values = await _ask(
      'Traitement en cours',
      ['Médicament', 'Dosage', 'Fréquence'],
      required: ['Médicament'],
    );
    if (values == null) return;
    setState(
      () => _treatments.add(
        Treatment(
          name: values['Médicament']!,
          dosage: values['Dosage']!,
          frequency: values['Fréquence']!,
          startedAt: DateTime.now(),
        ),
      ),
    );
  }

  Future<void> _addVaccination() async {
    final values = await _ask('Vaccination', ['Vaccin'], required: ['Vaccin']);
    if (values == null) return;
    setState(
      () => _vaccinations.add(
        Vaccination(name: values['Vaccin']!, date: DateTime.now()),
      ),
    );
  }

  Future<void> _addHistory(List<String> target, String title) async {
    final values = await _ask(title, ['Élément'], required: ['Élément']);
    if (values == null) return;
    setState(() => target.add(values['Élément']!));
  }

  // --- Construction ---------------------------------------------------------

  Widget _sectionHeader(String title, VoidCallback onAdd) => Padding(
    padding: const EdgeInsets.only(top: 18, bottom: 8),
    child: Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              color: RecordColors.ink,
            ),
          ),
        ),
        TextButton.icon(
          onPressed: onAdd,
          icon: const Icon(Icons.add_circle_outline, size: 18),
          label: const Text('Ajouter'),
        ),
      ],
    ),
  );

  Widget _removableTile({
    required String title,
    String subtitle = '',
    required VoidCallback onRemove,
    Widget? extra,
  }) => Container(
    margin: const EdgeInsets.only(bottom: 8),
    padding: const EdgeInsets.fromLTRB(14, 10, 4, 10),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: RecordColors.line),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  if (subtitle.isNotEmpty)
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: RecordColors.muted,
                        fontSize: 12,
                      ),
                    ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Retirer',
              onPressed: onRemove,
              icon: const Icon(Icons.delete_outline, color: RecordColors.muted),
            ),
          ],
        ),
        ?extra,
      ],
    ),
  );

  Widget _chips(List<String> items) => items.isEmpty
      ? const Text('Aucun élément', style: TextStyle(color: RecordColors.muted))
      : Wrap(
          spacing: 8,
          runSpacing: 6,
          children: [
            for (final item in items)
              InputChip(
                label: Text(item),
                onDeleted: () => setState(() => items.remove(item)),
              ),
          ],
        );

  @override
  Widget build(BuildContext context) => SheetFrame(
    title: 'Modifier le dossier',
    subtitle: widget.patientName,
    icon: Icons.edit_document,
    submitLabel: 'Enregistrer le dossier',
    isSaving: _saving,
    error: _error,
    onSubmit: _submit,
    children: [
      const FieldLabel('Groupe sanguin'),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final type in BloodType.values)
            ChoiceChip(
              label: Text(type == BloodType.unknown ? 'Inconnu' : type.label),
              selected: _bloodType == type,
              selectedColor: RecordColors.bloodType(type)
                  .withValues(alpha: 0.15),
              onSelected: (_) => setState(() => _bloodType = type),
            ),
        ],
      ),
      const FieldLabel('Taille'),
      TextField(
        controller: _height,
        keyboardType: TextInputType.number,
        decoration: const InputDecoration(
          prefixIcon: Icon(Icons.height),
          suffixText: 'cm',
        ),
      ),
      _sectionHeader('Allergies', _addAllergy),
      if (_allergies.isEmpty)
        const Text(
          'Aucune allergie connue',
          style: TextStyle(color: RecordColors.muted),
        ),
      for (final (index, allergy) in _allergies.indexed)
        _removableTile(
          title: allergy.name,
          subtitle: allergy.reaction,
          onRemove: () => setState(() => _allergies.removeAt(index)),
          extra: Padding(
            padding: const EdgeInsets.only(top: 8, right: 10),
            child: SegmentedButton<AllergySeverity>(
              showSelectedIcon: false,
              segments: [
                for (final severity in AllergySeverity.values)
                  ButtonSegment(value: severity, label: Text(severity.label)),
              ],
              selected: {allergy.severity ?? AllergySeverity.moderate},
              onSelectionChanged: (value) => setState(
                () => _allergies[index] = Allergy(
                  name: allergy.name,
                  reaction: allergy.reaction,
                  severity: value.first,
                ),
              ),
            ),
          ),
        ),
      _sectionHeader('Pathologies chroniques', _addCondition),
      if (_conditions.isEmpty)
        const Text(
          'Aucune pathologie',
          style: TextStyle(color: RecordColors.muted),
        ),
      for (final (index, condition) in _conditions.indexed)
        _removableTile(
          title: condition.name,
          subtitle: condition.notes,
          onRemove: () => setState(() => _conditions.removeAt(index)),
        ),
      _sectionHeader('Traitements en cours', _addTreatment),
      if (_treatments.isEmpty)
        const Text(
          'Aucun traitement',
          style: TextStyle(color: RecordColors.muted),
        ),
      for (final (index, treatment) in _treatments.indexed)
        _removableTile(
          title: treatment.name,
          subtitle: treatment.posology,
          onRemove: () => setState(() => _treatments.removeAt(index)),
        ),
      _sectionHeader(
        'Antécédents médicaux',
        () => _addHistory(_medical, 'Antécédent médical'),
      ),
      _chips(_medical),
      _sectionHeader(
        'Antécédents chirurgicaux',
        () => _addHistory(_surgical, 'Antécédent chirurgical'),
      ),
      _chips(_surgical),
      _sectionHeader(
        'Antécédents familiaux',
        () => _addHistory(_family, 'Antécédent familial'),
      ),
      _chips(_family),
      _sectionHeader('Vaccinations', _addVaccination),
      if (_vaccinations.isEmpty)
        const Text(
          'Aucune vaccination',
          style: TextStyle(color: RecordColors.muted),
        ),
      for (final (index, vaccination) in _vaccinations.indexed)
        _removableTile(
          title: vaccination.name,
          subtitle: vaccination.date == null
              ? ''
              : formatDay(vaccination.date!),
          onRemove: () => setState(() => _vaccinations.removeAt(index)),
        ),
    ],
  );
}
