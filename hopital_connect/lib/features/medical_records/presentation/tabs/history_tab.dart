import 'package:flutter/material.dart';

import '../../domain/medical_record.dart';
import '../widgets/record_ui.dart';

/// Onglet « Historique » : chronologie animée des consultations,
/// ordonnances et rendez-vous, filtrable par type.
class HistoryTab extends StatefulWidget {
  const HistoryTab({
    super.key,
    required this.file,
    required this.onOpenConsultation,
    required this.onRefresh,
  });

  final PatientMedicalFile file;
  final ValueChanged<Consultation> onOpenConsultation;
  final Future<void> Function() onRefresh;

  @override
  State<HistoryTab> createState() => _HistoryTabState();
}

class _HistoryTabState extends State<HistoryTab> {
  TimelineKind? _filter;

  static Color _color(TimelineKind kind) => switch (kind) {
    TimelineKind.consultation => RecordColors.consultation,
    TimelineKind.prescription => RecordColors.prescription,
    TimelineKind.appointment => RecordColors.appointment,
  };

  static IconData _icon(TimelineKind kind) => switch (kind) {
    TimelineKind.consultation => Icons.medical_information_outlined,
    TimelineKind.prescription => Icons.receipt_long_outlined,
    TimelineKind.appointment => Icons.event_outlined,
  };

  @override
  Widget build(BuildContext context) {
    final all = widget.file.timeline;
    final entries = _filter == null
        ? all
        : all.where((entry) => entry.kind == _filter).toList();
    int count(TimelineKind kind) => all.where((e) => e.kind == kind).length;

    return RefreshIndicator(
      onRefresh: widget.onRefresh,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 110),
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _chip('Tout', all.length, null),
                _chip(
                  'Consultations',
                  count(TimelineKind.consultation),
                  TimelineKind.consultation,
                ),
                _chip(
                  'Ordonnances',
                  count(TimelineKind.prescription),
                  TimelineKind.prescription,
                ),
                _chip(
                  'Rendez-vous',
                  count(TimelineKind.appointment),
                  TimelineKind.appointment,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (entries.isEmpty)
            const EmptyState(
              icon: Icons.timeline,
              title: 'Rien à afficher',
              message: 'Aucun événement pour ce filtre.',
            ),
          for (final (index, entry) in entries.indexed)
            FadeSlideIn(
              key: ValueKey(
                '${_filter?.name}-${entry.kind.name}-${entry.date}',
              ),
              index: index,
              child: _TimelineTile(
                entry: entry,
                color: _color(entry.kind),
                icon: _icon(entry.kind),
                isFirst: index == 0,
                isLast: index == entries.length - 1,
                onTap: entry.consultation == null
                    ? null
                    : () => widget.onOpenConsultation(entry.consultation!),
              ),
            ),
        ],
      ),
    );
  }

  Widget _chip(String label, int count, TimelineKind? kind) => Padding(
    padding: const EdgeInsets.only(right: 8),
    child: ChoiceChip(
      label: Text('$label · $count'),
      selected: _filter == kind,
      onSelected: (_) => setState(() => _filter = kind),
    ),
  );
}

class _TimelineTile extends StatelessWidget {
  const _TimelineTile({
    required this.entry,
    required this.color,
    required this.icon,
    required this.isFirst,
    required this.isLast,
    this.onTap,
  });

  final TimelineEntry entry;
  final Color color;
  final IconData icon;
  final bool isFirst;
  final bool isLast;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => IntrinsicHeight(
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          width: 52,
          child: Column(
            children: [
              Expanded(
                flex: 0,
                child: Container(
                  width: 2,
                  height: 18,
                  color: isFirst ? Colors.transparent : RecordColors.line,
                ),
              ),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: color.withValues(alpha: 0.35),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Icon(icon, size: 16, color: Colors.white),
              ),
              Expanded(
                child: Container(
                  width: 2,
                  color: isLast ? Colors.transparent : RecordColors.line,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: RecordCard(
              padding: const EdgeInsets.all(14),
              onTap: onTap,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          formatDay(entry.date),
                          style: TextStyle(
                            color: color,
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      if (entry.badge.isNotEmpty)
                        StatusPill(label: entry.badge, color: color),
                      if (onTap != null)
                        const Icon(
                          Icons.chevron_right,
                          color: RecordColors.muted,
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    entry.title,
                    style: const TextStyle(
                      color: RecordColors.ink,
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                    ),
                  ),
                  if (entry.subtitle.isNotEmpty)
                    Text(
                      entry.subtitle,
                      style: const TextStyle(
                        color: RecordColors.muted,
                        fontSize: 12.5,
                      ),
                    ),
                  if (entry.details.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        entry.details,
                        style: const TextStyle(
                          color: RecordColors.ink,
                          height: 1.35,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ],
    ),
  );
}
