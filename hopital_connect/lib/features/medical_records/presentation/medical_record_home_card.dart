import 'package:flutter/material.dart';

import '../../users/domain/staff_role.dart';
import '../data/medical_record_service.dart';
import '../domain/medical_record.dart';
import 'emergency_card_page.dart';
import 'medical_record_page.dart';
import 'widgets/record_ui.dart';

/// Carte « Mon dossier médical » de l'accueil patient : aperçu (groupe
/// sanguin, allergies, dernière tension) et accès au dossier / carte d'urgence.
class MedicalRecordHomeCard extends StatefulWidget {
  const MedicalRecordHomeCard({
    super.key,
    required this.patientId,
    this.isArabic = false,
    this.service,
    this.onOpen,
  });

  /// Ouvre le dossier (dans l'accueil patient : bascule sur l'onglet
  /// « Mon dossier »). Par défaut, le dossier s'ouvre en plein écran.
  final VoidCallback? onOpen;

  final String patientId;
  final bool isArabic;
  final MedicalRecordService? service;

  @override
  State<MedicalRecordHomeCard> createState() => _MedicalRecordHomeCardState();
}

class _MedicalRecordHomeCardState extends State<MedicalRecordHomeCard> {
  late final MedicalRecordService _service =
      widget.service ?? MedicalRecordService();
  PatientMedicalFile? _file;
  bool _failed = false;

  String _text(String fr, String ar) => widget.isArabic ? ar : fr;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final file = await _service.mine();
      if (mounted) setState(() => _file = file);
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  Future<void> _openRecord() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MedicalRecordPage(
          viewerRole: StaffRole.patient,
          viewerId: widget.patientId,
          initialFile: _file,
          service: _service,
        ),
      ),
    );
    _load();
  }

  String _treatmentSummary(PatientMedicalFile file) {
    final treatments = file.record.currentTreatments;
    if (treatments.isEmpty) {
      return _text('Aucun traitement en cours', 'لا يوجد علاج حالياً');
    }
    final first = treatments.first.name;
    return treatments.length == 1 ? first : '$first +${treatments.length - 1}';
  }

  String _lastConsultation(PatientMedicalFile file) {
    if (file.consultations.isNotEmpty) {
      final last = file.consultations.first;
      return '${formatDay(last.date)} · ${last.reason}';
    }
    final now = DateTime.now();
    final past = file.appointments.where((a) => a.startAt.isBefore(now));
    if (past.isEmpty) {
      return _text('Aucune consultation passée', 'لا توجد استشارة سابقة');
    }
    final last = past.first;
    return '${formatDay(last.startAt)} · Dr ${last.doctor.name}';
  }

  void _openCard() {
    if (_file == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => EmergencyCardPage(file: _file!)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final file = _file;
    final pressure = file?.latestVital(VitalKind.bloodPressure);
    final severe = file?.record.severeAllergies ?? const [];
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: RecordColors.headerGradient,
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33123047),
            blurRadius: 22,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.folder_shared_outlined,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _text('Mon dossier médical', 'ملفي الطبي'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (file != null)
                BloodTypeBadgeOnDark(type: file.record.bloodType),
            ],
          ),
          const SizedBox(height: 14),
          if (file == null && !_failed)
            const LinearProgressIndicator(
              color: Colors.white,
              backgroundColor: Colors.white24,
            )
          else if (_failed)
            Text(
              _text(
                'Dossier indisponible pour le moment.',
                'الملف غير متاح حالياً.',
              ),
              style: const TextStyle(color: Colors.white70),
            )
          else ...[
            Row(
              children: [
                _Fact(
                  label: _text('Allergies', 'الحساسية'),
                  value: '${file!.record.allergies.length}',
                  alert: severe.isNotEmpty,
                ),
                _Fact(
                  label: _text('Tension', 'الضغط'),
                  value: pressure?.display(VitalKind.bloodPressure) ?? '—',
                  alert:
                      pressure?.statusOf(VitalKind.bloodPressure) ==
                      VitalStatus.critical,
                ),
                _Fact(
                  label: _text('Consultations', 'الاستشارات'),
                  value: '${file.consultations.length}',
                ),
              ],
            ),
            if (severe.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                '⚠ ${severe.map((a) => a.name).join(', ')}',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
            const SizedBox(height: 12),
            _Line(
              icon: Icons.medication_outlined,
              label: _text('Traitement en cours', 'العلاج الحالي'),
              value: _treatmentSummary(file),
            ),
            _Line(
              icon: Icons.history,
              label: _text('Dernière consultation', 'آخر استشارة'),
              value: _lastConsultation(file),
            ),
          ],
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFF123047),
                  ),
                  onPressed: file == null
                      ? null
                      : (widget.onOpen ?? _openRecord),
                  icon: const Icon(Icons.open_in_new, size: 18),
                  label: Text(_text('Ouvrir', 'فتح')),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white54),
                  ),
                  onPressed: file == null ? null : _openCard,
                  icon: const Icon(Icons.emergency, size: 18),
                  label: Text(_text('Carte d’urgence', 'بطاقة الطوارئ')),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class BloodTypeBadgeOnDark extends StatelessWidget {
  const BloodTypeBadgeOnDark({super.key, required this.type});

  final BloodType type;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.water_drop, size: 14, color: Color(0xFFC0392B)),
        const SizedBox(width: 3),
        Text(
          type.label,
          style: const TextStyle(
            color: Color(0xFFC0392B),
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    ),
  );
}

class _Line extends StatelessWidget {
  const _Line({required this.icon, required this.label, required this.value});

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 6),
    child: Row(
      children: [
        Icon(icon, size: 16, color: Colors.white70),
        const SizedBox(width: 8),
        Text(
          '$label : ',
          style: const TextStyle(color: Colors.white70, fontSize: 12.5),
        ),
        Expanded(
          child: Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 12.5,
            ),
          ),
        ),
      ],
    ),
  );
}

class _Fact extends StatelessWidget {
  const _Fact({required this.label, required this.value, this.alert = false});

  final String label;
  final String value;
  final bool alert;

  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      margin: const EdgeInsetsDirectional.only(end: 8),
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
      decoration: BoxDecoration(
        color: alert
            ? RecordColors.critical.withValues(alpha: 0.85)
            : Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FittedBox(
            child: Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white70, fontSize: 11),
          ),
        ],
      ),
    ),
  );
}
