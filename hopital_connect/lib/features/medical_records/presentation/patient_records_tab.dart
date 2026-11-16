// =============================================================================
// DOSSIERS PATIENTS — onglet des médecins et infirmiers
// Recherche instantanée, filtres, cartes animées et scan de carte d'urgence.
// =============================================================================

import 'dart:async';

import 'package:flutter/material.dart';

import '../../users/domain/staff_role.dart';
import '../data/medical_record_service.dart';
import '../domain/medical_record.dart';
import 'medical_record_page.dart';
import 'qr_scan_page.dart';
import 'sheets/sheet_frame.dart';
import 'widgets/record_ui.dart';

enum _PatientFilter { all, severeAllergy, recent, noRecord }

class PatientRecordsTab extends StatefulWidget {
  const PatientRecordsTab({
    super.key,
    required this.viewerRole,
    required this.viewerId,
    required this.viewerName,
    this.service,
  });

  final StaffRole viewerRole;
  final String viewerId;
  final String viewerName;
  final MedicalRecordService? service;

  @override
  State<PatientRecordsTab> createState() => _PatientRecordsTabState();
}

class _PatientRecordsTabState extends State<PatientRecordsTab> {
  late final MedicalRecordService _service =
      widget.service ?? MedicalRecordService();
  final _search = TextEditingController();
  Timer? _debounce;
  List<PatientSummary> _patients = const [];
  bool _loading = true;
  String? _error;
  _PatientFilter _filter = _PatientFilter.all;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = _patients.isEmpty;
      _error = null;
    });
    try {
      final patients = await _service.searchPatients(query: _search.text);
      if (!mounted) return;
      setState(() {
        _patients = patients;
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

  void _onSearchChanged(String _) {
    setState(() {});
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), _load);
  }

  List<PatientSummary> get _visible {
    final recentLimit = DateTime.now().subtract(const Duration(days: 30));
    return _patients.where((patient) {
      return switch (_filter) {
        _PatientFilter.all => true,
        _PatientFilter.severeAllergy => patient.hasSevereAllergy,
        _PatientFilter.recent =>
          patient.lastConsultationAt?.isAfter(recentLimit) ?? false,
        _PatientFilter.noRecord => !patient.hasRecord,
      };
    }).toList()..sort(_byActivity);
  }

  /// Patients suivis d'abord (dernière consultation la plus récente),
  /// puis dossiers existants, puis ordre alphabétique.
  static int _byActivity(PatientSummary a, PatientSummary b) {
    final lastA = a.lastConsultationAt;
    final lastB = b.lastConsultationAt;
    if (lastA != null || lastB != null) {
      if (lastA == null) return 1;
      if (lastB == null) return -1;
      final byDate = lastB.compareTo(lastA);
      if (byDate != 0) return byDate;
    }
    if (a.hasRecord != b.hasRecord) return a.hasRecord ? -1 : 1;
    return a.identity.displayName.toLowerCase().compareTo(
      b.identity.displayName.toLowerCase(),
    );
  }

  Future<void> _openRecord(String patientId, {PatientSummary? preview}) async {
    await Navigator.push(
      context,
      PageRouteBuilder<void>(
        transitionDuration: const Duration(milliseconds: 450),
        reverseTransitionDuration: const Duration(milliseconds: 350),
        pageBuilder: (_, _, _) => MedicalRecordPage(
          patientId: patientId,
          viewerRole: widget.viewerRole,
          viewerId: widget.viewerId,
          preview: preview,
          service: _service,
        ),
        transitionsBuilder: (_, animation, _, child) => FadeTransition(
          opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
          child: SlideTransition(
            position: Tween(begin: const Offset(0, 0.04), end: Offset.zero)
                .animate(
                  CurvedAnimation(
                    parent: animation,
                    curve: Curves.easeOutCubic,
                  ),
                ),
            child: child,
          ),
        ),
      ),
    );
    if (mounted) _load();
  }

  Future<void> _scan() async {
    final patientId = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const QrScanPage()),
    );
    if (patientId == null || !mounted) return;
    PatientSummary? preview;
    for (final patient in _patients) {
      if (patient.identity.id == patientId) preview = patient;
    }
    await _openRecord(patientId, preview: preview);
  }

  @override
  Widget build(BuildContext context) {
    final visible = _visible;
    final severe = _patients.where((p) => p.hasSevereAllergy).length;
    final withoutRecord = _patients.where((p) => !p.hasRecord).length;

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          FadeSlideIn(
            child: _HeroCard(
              viewerName: widget.viewerName,
              isDoctor: widget.viewerRole == StaffRole.doctor,
              total: _patients.length,
              severe: severe,
              withoutRecord: withoutRecord,
              onScan: _scan,
            ),
          ),
          const SizedBox(height: 16),
          FadeSlideIn(
            index: 1,
            child: TextField(
              controller: _search,
              onChanged: _onSearchChanged,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'Rechercher un patient (nom, e-mail)…',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _search.text.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () {
                          _search.clear();
                          _onSearchChanged('');
                        },
                      ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          FadeSlideIn(
            index: 2,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _filterChip('Tous', _PatientFilter.all, Icons.people_outline),
                  _filterChip(
                    'Allergie sévère',
                    _PatientFilter.severeAllergy,
                    Icons.warning_amber_rounded,
                  ),
                  _filterChip(
                    'Vus ce mois',
                    _PatientFilter.recent,
                    Icons.history,
                  ),
                  _filterChip(
                    'Dossier à créer',
                    _PatientFilter.noRecord,
                    Icons.note_add_outlined,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          if (_loading)
            for (var i = 0; i < 4; i++)
              const Padding(
                padding: EdgeInsets.only(bottom: 12),
                child: SkeletonBox(height: 96, radius: 22),
              )
          else if (_error != null)
            ErrorRetry(message: _error!, onRetry: _load)
          else if (visible.isEmpty)
            EmptyState(
              icon: Icons.person_search_outlined,
              title: 'Aucun patient trouvé',
              message: _search.text.isEmpty
                  ? 'Aucun patient ne correspond à ce filtre.'
                  : 'Essayez un autre nom ou une adresse e-mail.',
            )
          else
            for (final (index, patient) in visible.indexed)
              FadeSlideIn(
                key: ValueKey('${_filter.name}-${patient.identity.id}'),
                index: index + 3,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _PatientCard(
                    patient: patient,
                    onTap: () =>
                        _openRecord(patient.identity.id, preview: patient),
                  ),
                ),
              ),
        ],
      ),
    );
  }

  Widget _filterChip(String label, _PatientFilter filter, IconData icon) =>
      Padding(
        padding: const EdgeInsets.only(right: 8),
        child: FilterChip(
          avatar: Icon(icon, size: 18),
          label: Text(label),
          selected: _filter == filter,
          showCheckmark: false,
          onSelected: (_) => setState(() => _filter = filter),
        ),
      );
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({
    required this.viewerName,
    required this.isDoctor,
    required this.total,
    required this.severe,
    required this.withoutRecord,
    required this.onScan,
  });

  final String viewerName;
  final bool isDoctor;
  final int total;
  final int severe;
  final int withoutRecord;
  final VoidCallback onScan;

  @override
  Widget build(BuildContext context) {
    final hour = DateTime.now().hour;
    final greeting = hour < 12
        ? 'Bonjour'
        : (hour < 18 ? 'Bon après-midi' : 'Bonsoir');
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: RecordColors.headerGradient,
        borderRadius: BorderRadius.circular(26),
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
                      '$greeting${viewerName.isEmpty ? '' : ', ${isDoctor ? 'Dr ' : ''}$viewerName'}',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.8),
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Dossiers médicaux',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.4,
                      ),
                    ),
                  ],
                ),
              ),
              Material(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: onScan,
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    child: Column(
                      children: [
                        Icon(Icons.qr_code_scanner, color: Color(0xFF123047)),
                        SizedBox(height: 2),
                        Text(
                          'Scanner',
                          style: TextStyle(
                            color: Color(0xFF123047),
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              _HeroStat(
                value: '$total',
                label: 'Patients',
                icon: Icons.people_alt_outlined,
              ),
              _HeroStat(
                value: '$severe',
                label: 'Allergies sévères',
                icon: Icons.warning_amber_rounded,
                highlight: severe > 0,
              ),
              _HeroStat(
                value: '$withoutRecord',
                label: 'À compléter',
                icon: Icons.note_add_outlined,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroStat extends StatelessWidget {
  const _HeroStat({
    required this.value,
    required this.label,
    required this.icon,
    this.highlight = false,
  });

  final String value;
  final String label;
  final IconData icon;
  final bool highlight;

  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: highlight
            ? RecordColors.critical.withValues(alpha: 0.85)
            : Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.white, size: 18),
          const SizedBox(height: 6),
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: double.tryParse(value) ?? 0),
            duration: const Duration(milliseconds: 900),
            curve: Curves.easeOutCubic,
            builder: (context, animated, _) => Text(
              animated.round().toString(),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.8),
              fontSize: 11,
            ),
          ),
        ],
      ),
    ),
  );
}

class _PatientCard extends StatelessWidget {
  const _PatientCard({required this.patient, required this.onTap});

  final PatientSummary patient;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final identity = patient.identity;
    return RecordCard(
      padding: const EdgeInsets.all(14),
      onTap: onTap,
      borderColor: patient.hasSevereAllergy
          ? RecordColors.critical.withValues(alpha: 0.3)
          : null,
      child: Row(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              PatientAvatar(
                initials: identity.initials,
                heroTag: patientHeroTag(identity.id),
              ),
              if (patient.hasSevereAllergy)
                Positioned(
                  right: -3,
                  bottom: -3,
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: const BoxDecoration(
                      color: RecordColors.critical,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.priority_high,
                      size: 12,
                      color: Colors.white,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  identity.displayName,
                  style: const TextStyle(
                    color: RecordColors.ink,
                    fontWeight: FontWeight.w800,
                    fontSize: 15.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  [
                    if (identity.age != null) '${identity.age} ans',
                    patient.lastConsultationAt == null
                        ? 'Aucune consultation'
                        : 'Vu ${relativeDay(patient.lastConsultationAt!).toLowerCase()}',
                  ].join(' · '),
                  style: const TextStyle(
                    color: RecordColors.muted,
                    fontSize: 12.5,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    BloodTypeBadge(type: patient.bloodType),
                    if (patient.allergyCount > 0)
                      StatusPill(
                        icon: Icons.coronavirus_outlined,
                        label:
                            '${patient.allergyCount} allergie${patient.allergyCount > 1 ? 's' : ''}',
                        color: patient.hasSevereAllergy
                            ? RecordColors.critical
                            : RecordColors.warning,
                      ),
                    if (patient.chronicConditionCount > 0)
                      StatusPill(
                        icon: Icons.healing_outlined,
                        label: '${patient.chronicConditionCount} patho.',
                        color: RecordColors.prescription,
                      ),
                    if (!patient.hasRecord)
                      const StatusPill(
                        icon: Icons.note_add_outlined,
                        label: 'À créer',
                        color: RecordColors.muted,
                      ),
                  ],
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: RecordColors.muted),
        ],
      ),
    );
  }
}
