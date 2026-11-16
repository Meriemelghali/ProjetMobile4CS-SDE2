// =============================================================================
// Graphique des constantes vitales (fl_chart) : bande de normalité,
// points hors norme colorés, info-bulle au toucher, animation au changement.
// =============================================================================

import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/medical_record.dart';
import 'record_ui.dart';

class VitalsChart extends StatelessWidget {
  const VitalsChart({
    super.key,
    required this.kind,
    required this.vitals,
    this.height = 230,
  });

  final VitalKind kind;

  /// Mesures triées de la plus ancienne à la plus récente.
  final List<VitalSign> vitals;
  final double height;

  static const _day = Duration.millisecondsPerDay;

  double _x(DateTime date) => date.millisecondsSinceEpoch / _day;

  @override
  Widget build(BuildContext context) {
    final points = vitals.where((v) => v.valueOf(kind) != null).toList();
    if (points.length < 2) {
      return SizedBox(
        height: height,
        child: const EmptyState(
          icon: Icons.show_chart,
          title: 'Pas assez de mesures',
          message:
              'Au moins deux mesures sont nécessaires pour tracer la courbe.',
        ),
      );
    }

    final isPressure = kind == VitalKind.bloodPressure;
    final primary = [
      for (final v in points) FlSpot(_x(v.recordedAt), v.valueOf(kind)!),
    ];
    final secondary = isPressure
        ? [
            for (final v in points)
              if (v.diastolic != null) FlSpot(_x(v.recordedAt), v.diastolic!),
          ]
        : const <FlSpot>[];

    final values = [...primary, ...secondary].map((s) => s.y);
    var minY = values.reduce(math.min);
    var maxY = values.reduce(math.max);
    if (kind.hasRange) {
      minY = math.min(minY, kind.normalMin);
      maxY = math.max(maxY, kind.normalMax);
      if (kind == VitalKind.spo2) maxY = 100;
    }
    final padding = math.max(
      (maxY - minY) * 0.15,
      kind == VitalKind.glucose ? 0.05 : 1,
    );
    minY -= padding;
    maxY += padding;
    if (kind == VitalKind.spo2) maxY = math.min(maxY, 101);

    final minX = primary.first.x;
    final maxX = primary.last.x;
    final spanDays = math.max(maxX - minX, 1);

    FlDotPainter dotFor(FlSpot spot, bool isDiastolic) {
      final status = isDiastolic
          ? classifyDiastolic(spot.y)
          : kind.classify(spot.y);
      final color = status == VitalStatus.normal
          ? (isDiastolic ? const Color(0xFF7FB8C9) : AppColors.blue)
          : RecordColors.status(status);
      return FlDotCirclePainter(
        radius: status == VitalStatus.normal ? 3.5 : 5.5,
        color: Colors.white,
        strokeWidth: status == VitalStatus.normal ? 2.5 : 3.5,
        strokeColor: color,
      );
    }

    LineChartBarData line(
      List<FlSpot> spots,
      Color color, {
      bool isDiastolic = false,
    }) => LineChartBarData(
      spots: spots,
      isCurved: true,
      curveSmoothness: 0.28,
      preventCurveOverShooting: true,
      color: color,
      barWidth: 3,
      isStrokeCapRound: true,
      dotData: FlDotData(
        getDotPainter: (spot, _, _, _) => dotFor(spot, isDiastolic),
      ),
      belowBarData: BarAreaData(
        show: !isDiastolic,
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [color.withValues(alpha: 0.22), color.withValues(alpha: 0)],
        ),
      ),
    );

    return SizedBox(
      height: height,
      child: LineChart(
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeOutCubic,
        LineChartData(
          minX: minX,
          maxX: maxX,
          minY: minY,
          maxY: maxY,
          clipData: const FlClipData.all(),
          rangeAnnotations: RangeAnnotations(
            horizontalRangeAnnotations: [
              if (kind.hasRange)
                HorizontalRangeAnnotation(
                  y1: kind.normalMin,
                  y2: math.min(kind.normalMax, maxY),
                  color: RecordColors.normal.withValues(alpha: 0.09),
                ),
              if (isPressure)
                HorizontalRangeAnnotation(
                  y1: 60,
                  y2: 89,
                  color: const Color(0xFF7FB8C9).withValues(alpha: 0.08),
                ),
            ],
          ),
          gridData: FlGridData(
            drawVerticalLine: false,
            getDrawingHorizontalLine: (_) =>
                const FlLine(color: Color(0xFFEDF2F4), strokeWidth: 1),
          ),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(),
            rightTitles: const AxisTitles(),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 40,
                getTitlesWidget: (value, meta) {
                  if (value == meta.min || value == meta.max) {
                    return const SizedBox.shrink();
                  }
                  return SideTitleWidget(
                    meta: meta,
                    child: Text(
                      kind.format(value),
                      style: const TextStyle(
                        color: RecordColors.muted,
                        fontSize: 10,
                      ),
                    ),
                  );
                },
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 28,
                interval: math.max(spanDays / 4, 1).toDouble(),
                getTitlesWidget: (value, meta) {
                  // fl_chart ajoute toujours les bornes : on masque celles
                  // qui chevaucheraient l'étiquette d'intervalle voisine.
                  final gap = meta.appliedInterval * 0.6;
                  final nearMin = value != meta.min && value - meta.min < gap;
                  final nearMax = value != meta.max && meta.max - value < gap;
                  if (value == meta.min || nearMin || nearMax) {
                    return const SizedBox.shrink();
                  }
                  final date = DateTime.fromMillisecondsSinceEpoch(
                    (value * _day).round(),
                  );
                  return SideTitleWidget(
                    meta: meta,
                    child: Text(
                      formatShortDay(date),
                      style: const TextStyle(
                        color: RecordColors.muted,
                        fontSize: 10,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipColor: (_) => RecordColors.ink,
              tooltipBorderRadius: BorderRadius.circular(12),
              fitInsideHorizontally: true,
              fitInsideVertically: true,
              getTooltipItems: (spots) => spots.map((spot) {
                final date = DateTime.fromMillisecondsSinceEpoch(
                  (spot.x * _day).round(),
                );
                final isDiastolic = isPressure && spot.barIndex == 1;
                final label = isPressure
                    ? (isDiastolic ? 'Diastolique' : 'Systolique')
                    : kind.label;
                return LineTooltipItem(
                  '${kind.format(spot.y)} ${kind.unit}\n',
                  const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                  children: [
                    TextSpan(
                      text: '$label · ${formatShortDay(date)}',
                      style: const TextStyle(
                        color: Color(0xFFB8C7CF),
                        fontWeight: FontWeight.w500,
                        fontSize: 11,
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
          lineBarsData: [
            line(primary, AppColors.blue),
            if (secondary.length >= 2)
              line(secondary, const Color(0xFF7FB8C9), isDiastolic: true),
          ],
        ),
      ),
    );
  }
}

/// Mini-courbe sans axes pour les tuiles de synthèse.
class VitalSparkline extends StatelessWidget {
  const VitalSparkline({
    super.key,
    required this.kind,
    required this.vitals,
    required this.color,
  });

  final VitalKind kind;
  final List<VitalSign> vitals;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final values = vitals
        .map((v) => v.valueOf(kind))
        .whereType<double>()
        .toList();
    if (values.length < 2) return const SizedBox(height: 28);
    final recent = values.length > 8
        ? values.sublist(values.length - 8)
        : values;
    return SizedBox(
      height: 28,
      child: LineChart(
        LineChartData(
          lineTouchData: const LineTouchData(enabled: false),
          gridData: const FlGridData(show: false),
          titlesData: const FlTitlesData(show: false),
          borderData: FlBorderData(show: false),
          lineBarsData: [
            LineChartBarData(
              spots: [
                for (var i = 0; i < recent.length; i++)
                  FlSpot(i.toDouble(), recent[i]),
              ],
              isCurved: true,
              preventCurveOverShooting: true,
              color: color,
              barWidth: 2,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                color: color.withValues(alpha: 0.12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
