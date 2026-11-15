// =============================================================================
// DOSSIER MÉDICAL — écran principal d'un patient
// En-tête animé, bandeau d'allergie, 4 onglets et actions selon le rôle :
//   médecin  → consultation, constantes, édition du dossier
//   infirmier → constantes
//   patient  → lecture seule + carte d'urgence
// =============================================================================

import 'package:flutter/material.dart';

import '../../users/domain/staff_role.dart';
import '../data/medical_record_service.dart';
import '../domain/medical_record.dart';
import '../utils/medical_record_pdf.dart';
import 'emergency_card_page.dart';
import 'sheets/consultation_form_sheet.dart';
import 'sheets/record_edit_sheet.dart';
import 'sheets/sheet_frame.dart';
import 'sheets/vitals_form_sheet.dart';
import 'tabs/history_tab.dart';
import 'tabs/summary_tab.dart';
import 'tabs/treatments_tab.dart';
import 'tabs/vitals_tab.dart';
import 'widgets/record_ui.dart';

String patientHeroTag(String patientId) => 'patient-avatar-$patientId';

class MedicalRecordPage extends StatefulWidget {
  const MedicalRecordPage({
    super.key,
    this.patientId,
    required this.viewerRole,
    required this.viewerId,
    this.preview,
    this.service,
    this.initialFile,
    this.embedded = false,
    this.initialTab = 0,
    this.tabRequest = 0,
  });

  /// Affiché comme onglet du tableau de bord (pas de bouton retour, en-tête
  /// non épinglé pour ne pas doubler la barre du tableau de bord).
  final bool embedded;

  /// Onglet à afficher : 0 Synthèse, 1 Historique, 2 Constantes, 3 Traitements.
  final int initialTab;

  /// Incrémenté par le parent pour (re)demander l'affichage de [initialTab].
  final int tabRequest;

  /// `null` : dossier du patient connecté (`GET /medical-records/me`).
  final String? patientId;
  final StaffRole viewerRole;
  final String viewerId;

  /// Résumé connu avant le chargement (animation Hero, nom immédiat).
  final PatientSummary? preview;
  final MedicalRecordService? service;

  /// Dossier déjà chargé (tests, navigation).
  final PatientMedicalFile? initialFile;

  @override
  State<MedicalRecordPage> createState() => _MedicalRecordPageState();
}

class _MedicalRecordPageState extends State<MedicalRecordPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(
    length: 4,
    vsync: this,
    initialIndex: widget.initialTab.clamp(0, 3),
  );
  late final MedicalRecordService _service =
      widget.service ?? MedicalRecordService();
  late PatientMedicalFile? _file = widget.initialFile;
  bool _loading = false;
  String? _error;
  VitalKind _vitalKind = VitalKind.bloodPressure;

  bool get _isDoctor => widget.viewerRole == StaffRole.doctor;
  bool get _canAddVitals => _isDoctor || widget.viewerRole == StaffRole.nurse;
  bool get _isPatient => widget.viewerRole == StaffRole.patient;

  @override
  void initState() {
    super.initState();
    if (_file == null) _load();
    _tabs.addListener(() {
      if (!_tabs.indexIsChanging) setState(() {});
    });
  }

  @override
  void didUpdateWidget(covariant MedicalRecordPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.tabRequest != widget.tabRequest) {
      _tabs.animateTo(widget.initialTab.clamp(0, 3));
    }
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = _file == null;
      _error = null;
    });
    try {
      final file = widget.patientId == null
          ? await _service.mine()
          : await _service.byPatient(widget.patientId!);
      if (!mounted) return;
      setState(() {
        _file = file;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = errorMessage(error);
        _loading = false;
      });
    }
  }

  void _toast(String message, {IconData icon = Icons.check_circle}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          content: Row(
            children: [
              Icon(icon, color: Colors.white),
              const SizedBox(width: 10),
              Expanded(child: Text(message)),
            ],
          ),
        ),
      );
  }

  // --- Actions --------------------------------------------------------------

  Future<void> _addConsultation({Consultation? initial}) async {
    final file = _file!;
    final saved = await showRecordSheet<Consultation>(
      context,
      ConsultationFormSheet(
        patientId: file.patient.id,
        patientName: file.patient.displayName,
        initial: initial,
        service: _service,
      ),
    );
    if (saved == null) return;
    _toast(
      initial == null ? 'Consultation enregistrée' : 'Consultation mise à jour',
    );
    _tabs.animateTo(1);
    await _load();
  }

  Future<void> _addVitals() async {
    final file = _file!;
    final saved = await showRecordSheet<VitalSign>(
      context,
      VitalsFormSheet(
        patientId: file.patient.id,
        patientName: file.patient.displayName,
        service: _service,
      ),
    );
    if (saved == null) return;
    final critical = VitalKind.values.where(
      (kind) => saved.statusOf(kind) == VitalStatus.critical,
    );
    _toast(
      critical.isEmpty
          ? 'Constantes enregistrées'
          : 'Enregistré · attention : ${critical.map((k) => k.label).join(', ')} hors norme',
      icon: critical.isEmpty ? Icons.check_circle : Icons.warning_amber_rounded,
    );
    _tabs.animateTo(2);
    await _load();
  }

  Future<void> _editRecord() async {
    final file = _file!;
    final saved = await showRecordSheet<MedicalRecord>(
      context,
      RecordEditSheet(
        patientId: file.patient.id,
        patientName: file.patient.displayName,
        record: file.record,
        service: _service,
      ),
    );
    if (saved == null) return;
    _toast('Dossier mis à jour');
    await _load();
  }

  void _openEmergencyCard() => Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => EmergencyCardPage(file: _file!)),
  );

  Future<void> _exportPdf() async {
    try {
      await MedicalRecordPdf.open(_file!);
    } catch (_) {
      if (mounted) _toast('Export PDF impossible', icon: Icons.error_outline);
    }
  }

  void _openConsultation(Consultation consultation) {
    final canEdit = _isDoctor && consultation.doctor.id == widget.viewerId;
    showRecordSheet<void>(
      context,
      _ConsultationDetail(
        consultation: consultation,
        onEdit: canEdit
            ? () {
                Navigator.pop(context);
                _addConsultation(initial: consultation);
              }
            : null,
      ),
    );
  }

  void _openDoctorActions() => showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (context) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _ActionTile(
              icon: Icons.medical_information_outlined,
              color: RecordColors.consultation,
              title: 'Nouvelle consultation',
              subtitle: 'Motif, examen, diagnostic, suivi',
              onTap: () {
                Navigator.pop(context);
                _addConsultation();
              },
            ),
            _ActionTile(
              icon: Icons.monitor_heart_outlined,
              color: RecordColors.critical,
              title: 'Saisir des constantes',
              subtitle: 'Tension, pouls, température, SpO₂…',
              onTap: () {
                Navigator.pop(context);
                _addVitals();
              },
            ),
            _ActionTile(
              icon: Icons.edit_document,
              color: RecordColors.prescription,
              title: 'Modifier le dossier',
              subtitle: 'Groupe sanguin, allergies, antécédents, traitements',
              onTap: () {
                Navigator.pop(context);
                _editRecord();
              },
            ),
          ],
        ),
      ),
    ),
  );

  Widget? _fab() {
    if (_file == null) return null;
    if (_isDoctor) {
      return FloatingActionButton.extended(
        onPressed: _openDoctorActions,
        icon: const Icon(Icons.add),
        label: const Text('Ajouter'),
      );
    }
    if (_canAddVitals) {
      return FloatingActionButton.extended(
        onPressed: _addVitals,
        icon: const Icon(Icons.monitor_heart_outlined),
        label: const Text('Constantes'),
      );
    }
    if (_isPatient) {
      return FloatingActionButton.extended(
        backgroundColor: RecordColors.critical,
        foregroundColor: Colors.white,
        onPressed: _openEmergencyCard,
        icon: const Icon(Icons.emergency),
        label: const Text('Carte d’urgence'),
      );
    }
    return null;
  }

  // --- Construction ---------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final file = _file;
    final name =
        file?.patient.displayName ??
        widget.preview?.identity.displayName ??
        'Mon dossier médical';
    final patientId = widget.patientId ?? file?.patient.id;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7F8),
      floatingActionButton: _fab(),
      body: NestedScrollView(
        headerSliverBuilder: (context, _) => [
          SliverAppBar(
            pinned: !widget.embedded,
            stretch: true,
            automaticallyImplyLeading: !widget.embedded,
            expandedHeight: 268,
            foregroundColor: Colors.white,
            backgroundColor: const Color(0xFF123047),
            title: widget.embedded
                ? null
                : Text(
                    name,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
            actions: [
              if (file != null) ...[
                IconButton(
                  tooltip: 'Carte d’urgence',
                  onPressed: _openEmergencyCard,
                  icon: const Icon(Icons.qr_code_2),
                ),
                IconButton(
                  tooltip: 'Exporter en PDF',
                  onPressed: _exportPdf,
                  icon: const Icon(Icons.picture_as_pdf_outlined),
                ),
              ],
            ],
            flexibleSpace: FlexibleSpaceBar(
              collapseMode: CollapseMode.parallax,
              background: _Header(
                name: name,
                patientId: patientId,
                file: file,
                preview: widget.preview,
              ),
            ),
          ),
          if (file != null && file.record.severeAllergies.isNotEmpty)
            SliverToBoxAdapter(
              child: _AllergyAlert(allergies: file.record.severeAllergies),
            ),
          SliverPersistentHeader(
            pinned: true,
            delegate: _TabBarDelegate(
              TabBar(
                controller: _tabs,
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                labelStyle: const TextStyle(fontWeight: FontWeight.w700),
                tabs: const [
                  Tab(
                    icon: Icon(Icons.dashboard_outlined, size: 20),
                    text: 'Synthèse',
                  ),
                  Tab(icon: Icon(Icons.timeline, size: 20), text: 'Historique'),
                  Tab(
                    icon: Icon(Icons.show_chart, size: 20),
                    text: 'Constantes',
                  ),
                  Tab(
                    icon: Icon(Icons.medication_outlined, size: 20),
                    text: 'Traitements',
                  ),
                ],
              ),
            ),
          ),
        ],
        body: _body(file),
      ),
    );
  }

  Widget _body(PatientMedicalFile? file) {
    if (_error != null && file == null) {
      return ListView(
        children: [ErrorRetry(message: _error!, onRetry: _load)],
      );
    }
    if (_loading || file == null) return const _LoadingSkeleton();
    return TabBarView(
      controller: _tabs,
      children: [
        SummaryTab(
          file: file,
          onRefresh: _load,
          onOpenVital: (kind) {
            setState(() => _vitalKind = kind);
            _tabs.animateTo(2);
          },
        ),
        HistoryTab(
          file: file,
          onRefresh: _load,
          onOpenConsultation: _openConsultation,
        ),
        VitalsTab(
          file: file,
          selected: _vitalKind,
          onRefresh: _load,
          onSelect: (kind) => setState(() => _vitalKind = kind),
        ),
        TreatmentsTab(file: file, onRefresh: _load),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.name,
    required this.patientId,
    required this.file,
    required this.preview,
  });

  final String name;
  final String? patientId;
  final PatientMedicalFile? file;
  final PatientSummary? preview;

  @override
  Widget build(BuildContext context) {
    final identity = file?.patient ?? preview?.identity;
    final bloodType =
        file?.record.bloodType ?? preview?.bloodType ?? BloodType.unknown;
    final height = file?.record.heightCm;
    final bmi = file?.bmi;
    final chips = <(IconData, String)>[
      if (identity?.age != null) (Icons.cake_outlined, '${identity!.age} ans'),
      if (height != null) (Icons.height, '${height.round()} cm'),
      if (bmi != null)
        (Icons.monitor_weight_outlined, 'IMC ${bmi.toStringAsFixed(1)}'),
      if (file != null)
        (
          Icons.medical_information_outlined,
          '${file!.consultations.length} consult.',
        ),
      if (identity?.insurance.isNotEmpty ?? false)
        (Icons.verified_user_outlined, identity!.insurance),
    ];

    return Container(
      decoration: const BoxDecoration(gradient: RecordColors.headerGradient),
      child: Stack(
        children: [
          Positioned(
            right: -60,
            top: -30,
            child: Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.05),
              ),
            ),
          ),
          Positioned(
            left: -40,
            bottom: -70,
            child: Container(
              width: 180,
              height: 180,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.04),
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 60, 20, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Row(
                    children: [
                      PatientAvatar(
                        initials: initialsOf(name),
                        size: 72,
                        onDark: true,
                        heroTag: patientId == null
                            ? null
                            : patientHeroTag(patientId!),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.4,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              identity?.email ?? '',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.75),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          children: [
                            const Icon(
                              Icons.water_drop,
                              color: Color(0xFFC0392B),
                              size: 18,
                            ),
                            Text(
                              bloodType.label,
                              style: const TextStyle(
                                color: Color(0xFFC0392B),
                                fontWeight: FontWeight.w900,
                                fontSize: 18,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final (icon, label) in chips)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.18),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(icon, size: 14, color: Colors.white),
                              const SizedBox(width: 5),
                              Text(
                                label,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Bandeau rouge pulsé pour les allergies sévères.
class _AllergyAlert extends StatefulWidget {
  const _AllergyAlert({required this.allergies});

  final List<Allergy> allergies;

  @override
  State<_AllergyAlert> createState() => _AllergyAlertState();
}

class _AllergyAlertState extends State<_AllergyAlert>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.fromLTRB(16, 14, 16, 0),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        colors: [Color(0xFFD64545), Color(0xFFB3262E)],
      ),
      borderRadius: BorderRadius.circular(18),
      boxShadow: [
        BoxShadow(
          color: RecordColors.critical.withValues(alpha: 0.3),
          blurRadius: 18,
          offset: const Offset(0, 8),
        ),
      ],
    ),
    child: Row(
      children: [
        ScaleTransition(
          scale: Tween(
            begin: 0.85,
            end: 1.1,
          ).animate(CurvedAnimation(parent: _pulse, curve: Curves.easeInOut)),
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.warning_rounded, color: Colors.white),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'ALLERGIE SÉVÈRE',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                widget.allergies
                    .map(
                      (a) => a.reaction.isEmpty
                          ? a.name
                          : '${a.name} (${a.reaction})',
                    )
                    .join(' · '),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _TabBarDelegate extends SliverPersistentHeaderDelegate {
  const _TabBarDelegate(this.tabBar);

  final TabBar tabBar;

  @override
  double get minExtent => tabBar.preferredSize.height + 1;

  @override
  double get maxExtent => tabBar.preferredSize.height + 1;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) => Container(
    decoration: const BoxDecoration(
      color: Color(0xFFF4F7F8),
      border: Border(bottom: BorderSide(color: RecordColors.line)),
    ),
    child: tabBar,
  );

  @override
  bool shouldRebuild(_TabBarDelegate oldDelegate) =>
      oldDelegate.tabBar != tabBar;
}

class _LoadingSkeleton extends StatelessWidget {
  const _LoadingSkeleton();

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(16),
    physics: const NeverScrollableScrollPhysics(),
    children: const [
      SkeletonBox(height: 70, radius: 18),
      SizedBox(height: 16),
      Row(
        children: [
          Expanded(child: SkeletonBox(height: 130, radius: 22)),
          SizedBox(width: 12),
          Expanded(child: SkeletonBox(height: 130, radius: 22)),
        ],
      ),
      SizedBox(height: 12),
      Row(
        children: [
          Expanded(child: SkeletonBox(height: 130, radius: 22)),
          SizedBox(width: 12),
          Expanded(child: SkeletonBox(height: 130, radius: 22)),
        ],
      ),
      SizedBox(height: 16),
      SkeletonBox(height: 160, radius: 22),
    ],
  );
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => ListTile(
    onTap: onTap,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    leading: Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Icon(icon, color: color),
    ),
    title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
    subtitle: Text(subtitle),
    trailing: const Icon(Icons.chevron_right),
  );
}

class _ConsultationDetail extends StatelessWidget {
  const _ConsultationDetail({required this.consultation, this.onEdit});

  final Consultation consultation;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    Widget block(String title, String text, IconData icon) => text.isEmpty
        ? const SizedBox.shrink()
        : Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: RecordCard(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SectionTitle(icon: icon, title: title),
                  const SizedBox(height: 8),
                  Text(text, style: const TextStyle(height: 1.45)),
                ],
              ),
            ),
          );

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.88,
      ),
      decoration: const BoxDecoration(
        color: Color(0xFFF7FAFB),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
        children: [
          Center(
            child: Container(
              width: 42,
              height: 5,
              decoration: BoxDecoration(
                color: const Color(0xFFD3DDE1),
                borderRadius: BorderRadius.circular(99),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            formatDayTime(consultation.date),
            style: const TextStyle(
              color: RecordColors.consultation,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            consultation.reason,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: RecordColors.ink,
            ),
          ),
          if (consultation.doctor.name.isNotEmpty)
            Text(
              [
                'Dr ${consultation.doctor.name}',
                if (consultation.doctor.specialty.isNotEmpty)
                  consultation.doctor.specialty,
              ].join(' · '),
              style: const TextStyle(color: RecordColors.muted),
            ),
          const SizedBox(height: 16),
          if (consultation.diagnosis.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                gradient: RecordColors.headerGradient,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.assignment_turned_in_outlined,
                    color: Colors.white,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      consultation.diagnosis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          block(
            'Symptômes',
            consultation.symptoms,
            Icons.record_voice_over_outlined,
          ),
          block('Examen clinique', consultation.examination, Icons.search),
          block(
            'Conduite à tenir',
            consultation.notes,
            Icons.playlist_add_check,
          ),
          if (consultation.followUpAt != null)
            StatusPill(
              icon: Icons.event_available,
              label: 'Contrôle prévu le ${formatDay(consultation.followUpAt!)}',
              color: RecordColors.normal,
            ),
          if (onEdit != null) ...[
            const SizedBox(height: 18),
            OutlinedButton.icon(
              onPressed: onEdit,
              icon: const Icon(Icons.edit_outlined),
              label: const Text('Modifier cette consultation'),
            ),
          ],
        ],
      ),
    );
  }
}
