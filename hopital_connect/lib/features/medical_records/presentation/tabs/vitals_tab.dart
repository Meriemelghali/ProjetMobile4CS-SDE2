import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/medical_record.dart';
import '../widgets/record_ui.dart';
import '../widgets/vitals_chart.dart';

enum VitalRange {
  month('1M', 30),
  quarter('3M', 90),
  half('6M', 182),
  all('Tout', null);

  const VitalRange(this.label, this.days);
  final String label;
  final int? days;
}

/// Onglet « Constantes » : choix de la mesure, période, graphique,
/// statistiques et liste des dernières valeurs.
class VitalsTab extends StatefulWidget {
  const VitalsTab({
    super.key,
    required this.file,
    required this.selected,
    required this.onSelect,
    required this.onRefresh,
  });

  final PatientMedicalFile file;
  final VitalKind selected;
  final ValueChanged<VitalKind> onSelect;
  final Future<void> Function() onRefresh;

  @override
  State<VitalsTab> createState() => _VitalsTabState();
}

class _VitalsTabState extends State<VitalsTab> {
  VitalRange _range = VitalRange.half;

  @override
  Widget build(BuildContext context) {
    final kind = widget.selected;
    final cutoff = _range.days == null
        ? null
        : DateTime.now().subtract(Duration(days: _range.days!));
    final vitals = widget.file.vitals
        .where((v) => cutoff == null || v.recordedAt.isAfter(cutoff))
        .toList();
    final measured = vitals.where((v) => v.valueOf(kind) != null).toList();
    final values = measured.map((v) => v.valueOf(kind)!).toList();
    final outOfRange = measured
        .where((v) => v.statusOf(kind) != VitalStatus.normal)
        .length;

    return RefreshIndicator(
      onRefresh: widget.onRefresh,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 110),
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final item in VitalKind.values)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      avatar: Icon(
                        vitalIcon(item),
                        size: 18,
                        color: item == kind
                            ? AppColors.blue
                            : RecordColors.muted,
                      ),
                      label: Text(item.label),
                      selected: item == kind,
                      onSelected: (_) => widget.onSelect(item),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          RecordCard(
            padding: const EdgeInsets.fromLTRB(12, 16, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(left: 6),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              kind.label,
                              style: const TextStyle(
                                color: RecordColors.ink,
                                fontWeight: FontWeight.w800,
                                fontSize: 17,
                              ),
                            ),
                            Text(
                              kind.hasRange
                                  ? 'Zone normale : ${kind.format(kind.normalMin)}–${kind.format(kind.normalMax)} ${kind.unit}'
                                  : 'Évolution en ${kind.unit}',
                              style: const TextStyle(
                                color: RecordColors.muted,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      SegmentedButton<VitalRange>(
                        showSelectedIcon: false,
                        style: const ButtonStyle(
                          visualDensity: VisualDensity.compact,
                        ),
                        segments: [
                          for (final range in VitalRange.values)
                            ButtonSegment(
                              value: range,
                              label: Text(range.label),
                            ),
                        ],
                        selected: {_range},
                        onSelectionChanged: (value) =>
                            setState(() => _range = value.first),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                VitalsChart(kind: kind, vitals: vitals),
                if (kind == VitalKind.bloodPressure)
                  const Padding(
                    padding: EdgeInsets.only(top: 8, left: 6),
                    child: Row(
                      children: [
                        _Legend(color: AppColors.blue, label: 'Systolique'),
                        SizedBox(width: 16),
                        _Legend(color: Color(0xFF7FB8C9), label: 'Diastolique'),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          if (values.isNotEmpty)
            Row(
              children: [
                _Stat(
                  label: 'Dernière',
                  value: measured.last.display(kind)!,
                  unit: kind.unit,
                ),
                _Stat(
                  label: 'Min',
                  value: kind.format(values.reduce(math.min)),
                  unit: kind.unit,
                ),
                _Stat(
                  label: 'Max',
                  value: kind.format(values.reduce(math.max)),
                  unit: kind.unit,
                ),
                _Stat(
                  label: 'Hors norme',
                  value: kind.hasRange ? '$outOfRange' : '—',
                  unit: kind.hasRange ? '/${values.length}' : '',
                  color: outOfRange > 0 && kind.hasRange
                      ? RecordColors.critical
                      : null,
                ),
              ],
            ),
          const SizedBox(height: 20),
          const SectionTitle(icon: Icons.list_alt_rounded, title: 'Mesures'),
          const SizedBox(height: 10),
          if (measured.isEmpty)
            const EmptyState(
              icon: Icons.monitor_heart_outlined,
              title: 'Aucune mesure sur la période',
            ),
          for (final (index, vital) in measured.reversed.take(12).indexed)
            FadeSlideIn(
              index: index,
              child: _MeasureRow(vital: vital, kind: kind),
            ),
        ],
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Container(
        width: 12,
        height: 4,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
      const SizedBox(width: 6),
      Text(
        label,
        style: const TextStyle(color: RecordColors.muted, fontSize: 12),
      ),
    ],
  );
}

class _Stat extends StatelessWidget {
  const _Stat({
    required this.label,
    required this.value,
    required this.unit,
    this.color,
  });

  final String label;
  final String value;
  final String unit;
  final Color? color;

  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: RecordColors.line),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: const TextStyle(color: RecordColors.muted, fontSize: 11),
          ),
          const SizedBox(height: 4),
          FittedBox(
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: value,
                    style: TextStyle(
                      color: color ?? RecordColors.ink,
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                  ),
                  TextSpan(
                    text: ' $unit',
                    style: const TextStyle(
                      color: RecordColors.muted,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class _MeasureRow extends StatelessWidget {
  const _MeasureRow({required this.vital, required this.kind});

  final VitalSign vital;
  final VitalKind kind;

  @override
  Widget build(BuildContext context) {
    final status = vital.statusOf(kind);
    final color = kind.hasRange ? RecordColors.status(status) : AppColors.blue;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: RecordColors.line),
      ),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  formatDayTime(vital.recordedAt),
                  style: const TextStyle(
                    color: RecordColors.ink,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (vital.recordedBy.name.isNotEmpty)
                  Text(
                    'Par ${vital.recordedBy.name}',
                    style: const TextStyle(
                      color: RecordColors.muted,
                      fontSize: 12,
                    ),
                  ),
              ],
            ),
          ),
          Text(
            '${vital.display(kind)} ${kind.unit}',
            style: TextStyle(color: color, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}
