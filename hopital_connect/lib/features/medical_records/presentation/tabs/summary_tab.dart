import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/medical_record.dart';
import '../widgets/record_ui.dart';
import '../widgets/vitals_chart.dart';

/// Onglet « Synthèse » : alertes, dernières constantes, allergies,
/// pathologies, antécédents et vaccinations.
class SummaryTab extends StatelessWidget {
  const SummaryTab({
    super.key,
    required this.file,
    required this.onOpenVital,
    required this.onRefresh,
  });

  final PatientMedicalFile file;
  final ValueChanged<VitalKind> onOpenVital;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final record = file.record;
    final alerts = file.alertingVitals;
    final followUp = file.nextFollowUp;
    var index = 0;
    Widget animated(Widget child) => FadeSlideIn(index: index++, child: child);

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 110),
        children: [
          if (!record.exists)
            animated(
              const _Banner(
                icon: Icons.info_outline,
                color: AppColors.blue,
                title: 'Dossier à compléter',
                message: 'Aucune information médicale de fond n’a encore été saisie.',
              ),
            ),
          if (alerts.isNotEmpty)
            animated(
              _Banner(
                icon: Icons.warning_amber_rounded,
                color: RecordColors.critical,
                title: alerts.length == 1
                    ? '1 constante hors norme'
                    : '${alerts.length} constantes hors norme',
                message:
                    'Dernière mesure : ${alerts.map((k) => k.label).join(', ')}.',
              ),
            ),
          if (followUp != null)
            animated(
              _Banner(
                icon: Icons.event_available_outlined,
                color: RecordColors.normal,
                title:
                    'Prochain contrôle · ${relativeDay(followUp.followUpAt!)}',
                message:
                    '${formatDay(followUp.followUpAt!)} — suite à « ${followUp.reason} ».',
              ),
            ),
          animated(
            SectionTitle(
              icon: Icons.monitor_heart_outlined,
              title: 'Dernières constantes',
              trailing: file.vitals.isEmpty
                  ? null
                  : Text(
                      relativeDay(file.vitals.last.recordedAt),
                      style: const TextStyle(color: RecordColors.muted),
                    ),
            ),
          ),
          const SizedBox(height: 12),
          animated(
            file.vitals.isEmpty
                ? const RecordCard(
                    child: EmptyState(
                      icon: Icons.monitor_heart_outlined,
                      title: 'Aucune constante enregistrée',
                    ),
                  )
                : _VitalsGrid(file: file, onOpen: onOpenVital),
          ),
          const SizedBox(height: 22),
          animated(_AllergiesCard(allergies: record.allergies)),
          const SizedBox(height: 14),
          animated(
            _ListCard(
              icon: Icons.healing_outlined,
              color: const Color(0xFF7B5CD6),
              title: 'Pathologies chroniques',
              empty: 'Aucune pathologie chronique',
              items: [
                for (final c in record.chronicConditions)
                  (
                    c.name,
                    [
                      if (c.since != null) 'Depuis ${c.since!.year}',
                      if (c.notes.isNotEmpty) c.notes,
                    ].join(' · '),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          animated(_HistoryCard(history: record.history)),
          const SizedBox(height: 14),
          animated(
            _ListCard(
              icon: Icons.vaccines_outlined,
              color: RecordColors.normal,
              title: 'Vaccinations',
              empty: 'Aucune vaccination renseignée',
              items: [
                for (final v in record.vaccinations)
                  (v.name, v.date == null ? '' : formatDay(v.date!)),
              ],
            ),
          ),
          if (record.updatedAt != null) ...[
            const SizedBox(height: 18),
            Center(
              child: Text(
                'Dossier mis à jour le ${formatDay(record.updatedAt!)}',
                style: const TextStyle(color: RecordColors.muted, fontSize: 12),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({
    required this.icon,
    required this.color,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 14),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: color.withValues(alpha: 0.25)),
    ),
    child: Row(
      children: [
        Icon(icon, color: color),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(color: color, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 2),
              Text(
                message,
                style: const TextStyle(color: RecordColors.ink, height: 1.35),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _VitalsGrid extends StatelessWidget {
  const _VitalsGrid({required this.file, required this.onOpen});

  final PatientMedicalFile file;
  final ValueChanged<VitalKind> onOpen;

  @override
  Widget build(BuildContext context) {
    final kinds = VitalKind.values
        .where((kind) => file.latestVital(kind) != null)
        .toList();
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth > 560 ? 3 : 2;
        const spacing = 12.0;
        final width =
            (constraints.maxWidth - spacing * (columns - 1)) / columns;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final kind in kinds)
              SizedBox(
                width: width,
                child: _VitalTile(
                  kind: kind,
                  file: file,
                  onTap: () => onOpen(kind),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _VitalTile extends StatelessWidget {
  const _VitalTile({
    required this.kind,
    required this.file,
    required this.onTap,
  });

  final VitalKind kind;
  final PatientMedicalFile file;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final vital = file.latestVital(kind)!;
    final status = vital.statusOf(kind);
    final color = kind.hasRange ? RecordColors.status(status) : AppColors.blue;
    return RecordCard(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
      onTap: onTap,
      borderColor: status == VitalStatus.critical
          ? RecordColors.critical.withValues(alpha: 0.35)
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(vitalIcon(kind), color: color, size: 20),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  kind.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: RecordColors.muted,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: vital.display(kind),
                  style: const TextStyle(
                    color: RecordColors.ink,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
                ),
                TextSpan(
                  text: ' ${kind.unit}',
                  style: const TextStyle(
                    color: RecordColors.muted,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          VitalSparkline(kind: kind, vitals: file.vitals, color: color),
          const SizedBox(height: 6),
          if (kind.hasRange)
            StatusPill(label: vitalStatusLabel(status), color: color)
          else if (file.bmi != null)
            StatusPill(
              label: 'IMC ${file.bmi!.toStringAsFixed(1)}',
              color: AppColors.blue,
            ),
        ],
      ),
    );
  }
}

class _AllergiesCard extends StatelessWidget {
  const _AllergiesCard({required this.allergies});

  final List<Allergy> allergies;

  @override
  Widget build(BuildContext context) => RecordCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionTitle(
          icon: Icons.coronavirus_outlined,
          title: 'Allergies',
          color: RecordColors.critical,
          trailing: StatusPill(
            label: '${allergies.length}',
            color: allergies.isEmpty
                ? RecordColors.normal
                : RecordColors.critical,
          ),
        ),
        const SizedBox(height: 12),
        if (allergies.isEmpty)
          const Text(
            'Aucune allergie connue',
            style: TextStyle(color: RecordColors.muted),
          ),
        for (final allergy in allergies)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              children: [
                Container(
                  width: 4,
                  height: 36,
                  decoration: BoxDecoration(
                    color: RecordColors.severity(allergy.severity),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        allergy.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: RecordColors.ink,
                        ),
                      ),
                      Text(
                        allergy.declaredByPatient
                            ? 'Déclarée par le patient'
                            : (allergy.reaction.isEmpty
                                  ? '—'
                                  : allergy.reaction),
                        style: const TextStyle(
                          color: RecordColors.muted,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                StatusPill(
                  label: allergy.severity?.label ?? 'À qualifier',
                  color: RecordColors.severity(allergy.severity),
                ),
              ],
            ),
          ),
      ],
    ),
  );
}

class _ListCard extends StatelessWidget {
  const _ListCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.empty,
    required this.items,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String empty;
  final List<(String, String)> items;

  @override
  Widget build(BuildContext context) => RecordCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionTitle(icon: icon, title: title, color: color),
        const SizedBox(height: 10),
        if (items.isEmpty)
          Text(empty, style: const TextStyle(color: RecordColors.muted)),
        for (final (name, detail) in items)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Icon(Icons.circle, size: 8, color: color),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: RecordColors.ink,
                        ),
                      ),
                      if (detail.isNotEmpty)
                        Text(
                          detail,
                          style: const TextStyle(
                            color: RecordColors.muted,
                            fontSize: 12,
                            height: 1.35,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    ),
  );
}

class _HistoryCard extends StatelessWidget {
  const _HistoryCard({required this.history});

  final MedicalHistory history;

  @override
  Widget build(BuildContext context) {
    Widget group(String label, IconData icon, List<String> items) => Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: RecordColors.muted),
              const SizedBox(width: 6),
              Text(
                label,
                style: const TextStyle(
                  color: RecordColors.muted,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          if (items.isEmpty)
            const Text('—', style: TextStyle(color: RecordColors.muted))
          else
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final item in items)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF2F6F8),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      item,
                      style: const TextStyle(
                        color: RecordColors.ink,
                        fontSize: 12.5,
                      ),
                    ),
                  ),
              ],
            ),
        ],
      ),
    );

    return RecordCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionTitle(
            icon: Icons.history_edu_outlined,
            title: 'Antécédents',
            color: Color(0xFF2C7DA0),
          ),
          group(
            'Médicaux',
            Icons.medical_information_outlined,
            history.medical,
          ),
          group('Chirurgicaux', Icons.content_cut, history.surgical),
          group('Familiaux', Icons.family_restroom, history.family),
        ],
      ),
    );
  }
}
