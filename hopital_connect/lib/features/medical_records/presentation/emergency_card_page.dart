import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../data/medical_record_service.dart';
import '../domain/medical_record.dart';
import '../utils/medical_record_pdf.dart';
import 'widgets/record_ui.dart';

/// Préfixe des QR codes : seul l'identifiant est encodé, jamais de donnée
/// médicale. L'ouverture du dossier reste soumise aux droits de l'API.
const emergencyQrPrefix = 'hopitalconnect://record/';

String emergencyQrPayload(String patientId) => '$emergencyQrPrefix$patientId';

String? patientIdFromQr(String raw) {
  final value = raw.trim();
  if (!value.startsWith(emergencyQrPrefix)) return null;
  final id = value.substring(emergencyQrPrefix.length);
  return RegExp(r'^[a-fA-F0-9]{24}$').hasMatch(id) ? id : null;
}

/// Carte d'urgence du patient, recto (infos vitales) / verso (QR code),
/// retournée en 3D au toucher.
class EmergencyCardPage extends StatefulWidget {
  const EmergencyCardPage({super.key, required this.file});

  final PatientMedicalFile file;

  @override
  State<EmergencyCardPage> createState() => _EmergencyCardPageState();
}

class _EmergencyCardPageState extends State<EmergencyCardPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _flip = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 650),
  );

  @override
  void dispose() {
    _flip.dispose();
    super.dispose();
  }

  void _toggle() => _flip.status == AnimationStatus.completed
      ? _flip.reverse()
      : _flip.forward();

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFF0B1F2E),
    appBar: AppBar(
      backgroundColor: Colors.transparent,
      foregroundColor: Colors.white,
      title: const Text('Carte d’urgence'),
      actions: [
        IconButton(
          tooltip: 'Exporter le dossier en PDF',
          onPressed: () => MedicalRecordPdf.open(widget.file),
          icon: const Icon(Icons.picture_as_pdf_outlined),
        ),
      ],
    ),
    body: SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              children: [
                GestureDetector(
                  onTap: _toggle,
                  child: AnimatedBuilder(
                    animation: _flip,
                    builder: (context, _) {
                      final t = Curves.easeInOutCubic.transform(_flip.value);
                      final angle = t * math.pi;
                      final showBack = angle > math.pi / 2;
                      return Transform(
                        alignment: Alignment.center,
                        transform: Matrix4.identity()
                          ..setEntry(3, 2, 0.0012)
                          ..rotateY(angle),
                        child: showBack
                            ? Transform(
                                alignment: Alignment.center,
                                transform: Matrix4.identity()..rotateY(math.pi),
                                child: _CardBack(file: widget.file),
                              )
                            : _CardFront(file: widget.file),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 22),
                FilledButton.tonalIcon(
                  onPressed: _toggle,
                  icon: const Icon(Icons.flip),
                  label: AnimatedBuilder(
                    animation: _flip,
                    builder: (context, _) => Text(
                      _flip.value > 0.5
                          ? 'Voir les informations'
                          : 'Afficher le QR code',
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Présentez cette carte aux secours. Le QR code ne contient '
                  'aucune donnée médicale : seul un professionnel connecté et '
                  'autorisé peut ouvrir le dossier.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Color(0xFF9FB3BF), height: 1.4),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class _CardShell extends StatelessWidget {
  const _CardShell({required this.child, this.gradient, this.color});

  final Widget child;
  final Gradient? gradient;
  final Color? color;

  @override
  Widget build(BuildContext context) => AspectRatio(
    aspectRatio: 0.66,
    child: Container(
      decoration: BoxDecoration(
        gradient: gradient,
        color: color,
        borderRadius: BorderRadius.circular(28),
        boxShadow: const [
          BoxShadow(
            color: Color(0x66000000),
            blurRadius: 40,
            offset: Offset(0, 20),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: child,
    ),
  );
}

class _CardFront extends StatelessWidget {
  const _CardFront({required this.file});

  final PatientMedicalFile file;

  @override
  Widget build(BuildContext context) {
    final record = file.record;
    final patient = file.patient;
    final allergies = [...record.allergies]
      ..sort((a, b) => (b.isSevere ? 1 : 0) - (a.isSevere ? 1 : 0));
    return _CardShell(
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFB3262E), Color(0xFF7A1C3B), Color(0xFF123047)],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -40,
            top: -40,
            child: Icon(
              Icons.add,
              size: 220,
              color: Colors.white.withValues(alpha: 0.06),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.emergency, color: Colors.white),
                    const SizedBox(width: 8),
                    Text(
                      'CARTE D’URGENCE MÉDICALE',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.2,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 22),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            patient.displayName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 26,
                              fontWeight: FontWeight.w800,
                              height: 1.1,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            [
                              if (patient.age != null) '${patient.age} ans',
                              if (patient.birthDate != null)
                                formatDay(patient.birthDate!),
                            ].join(' · '),
                            style: const TextStyle(color: Color(0xFFF2D7DA)),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        children: [
                          const Text(
                            'GROUPE',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF7A1C3B),
                            ),
                          ),
                          Text(
                            record.bloodType.label,
                            style: const TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFFB3262E),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 22),
                _label('ALLERGIES'),
                const SizedBox(height: 8),
                if (allergies.isEmpty)
                  const Text(
                    'Aucune allergie connue',
                    style: TextStyle(color: Colors.white),
                  ),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final allergy in allergies.take(5))
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: allergy.isSevere
                              ? Colors.white
                              : Colors.white.withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          allergy.isSevere ? '⚠ ${allergy.name}' : allergy.name,
                          style: TextStyle(
                            color: allergy.isSevere
                                ? const Color(0xFFB3262E)
                                : Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 18),
                _label('PATHOLOGIES'),
                const SizedBox(height: 6),
                Text(
                  record.chronicConditions.isEmpty
                      ? 'Aucune'
                      : record.chronicConditions
                            .take(3)
                            .map((c) => c.name)
                            .join('\n'),
                  style: const TextStyle(color: Colors.white, height: 1.4),
                ),
                const Spacer(),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.22),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.phone_in_talk, color: Colors.white),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _label('CONTACT D’URGENCE'),
                            const SizedBox(height: 2),
                            Text(
                              patient.emergencyContact.isEmpty
                                  ? 'Non renseigné'
                                  : patient.emergencyContact,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Center(
                  child: Text(
                    'Touchez la carte pour la retourner',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.6),
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _label(String text) => Text(
    text,
    style: TextStyle(
      color: Colors.white.withValues(alpha: 0.65),
      fontSize: 10,
      fontWeight: FontWeight.w800,
      letterSpacing: 1.1,
    ),
  );
}

class _CardBack extends StatelessWidget {
  const _CardBack({required this.file});

  final PatientMedicalFile file;

  @override
  Widget build(BuildContext context) => _CardShell(
    color: Colors.white,
    child: Padding(
      padding: const EdgeInsets.all(26),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: RecordColors.headerGradient,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.local_hospital,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                'HôpitalConnect',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                  color: RecordColors.ink,
                ),
              ),
            ],
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: RecordColors.line, width: 2),
            ),
            child: QrImageView(
              data: emergencyQrPayload(file.patient.id),
              size: 210,
              eyeStyle: const QrEyeStyle(
                eyeShape: QrEyeShape.circle,
                color: Color(0xFF123047),
              ),
              dataModuleStyle: const QrDataModuleStyle(
                dataModuleShape: QrDataModuleShape.circle,
                color: Color(0xFF176B87),
              ),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            file.patient.displayName,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 18,
              color: RecordColors.ink,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Professionnel de santé : scannez ce code\ndepuis l’onglet Dossiers de l’application.',
            textAlign: TextAlign.center,
            style: TextStyle(color: RecordColors.muted, height: 1.4),
          ),
          const Spacer(),
          Text(
            'ID ${file.patient.id.substring(file.patient.id.length - 8).toUpperCase()}',
            style: const TextStyle(
              color: RecordColors.muted,
              letterSpacing: 2,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    ),
  );
}

/// Ouvre la carte d'urgence du patient connecté (bouton « Urgences » de
/// l'accueil patient). Charge le dossier, puis affiche la carte.
Future<void> openMyEmergencyCard(
  BuildContext context, {
  MedicalRecordService? service,
}) async {
  final messenger = ScaffoldMessenger.of(context);
  final navigator = Navigator.of(context);
  try {
    final file = await (service ?? MedicalRecordService()).mine();
    await navigator.push(
      MaterialPageRoute<void>(builder: (_) => EmergencyCardPage(file: file)),
    );
  } catch (_) {
    messenger.showSnackBar(
      const SnackBar(
        content: Text(
          'Carte d’urgence indisponible. En cas d’urgence, appelez le 190 (SAMU).',
        ),
      ),
    );
  }
}
