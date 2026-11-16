import 'package:flutter/material.dart';

import '../../domain/medical_record.dart';
import '../widgets/record_ui.dart';

/// Onglet « Traitements » : traitements en cours et ordonnances.
class TreatmentsTab extends StatelessWidget {
  const TreatmentsTab({super.key, required this.file, required this.onRefresh});

  final PatientMedicalFile file;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final treatments = file.record.currentTreatments;
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 110),
        children: [
          SectionTitle(
            icon: Icons.medication_outlined,
            title: 'Traitements en cours',
            color: RecordColors.prescription,
            trailing: StatusPill(
              label: '${treatments.length}',
              color: RecordColors.prescription,
            ),
          ),
          const SizedBox(height: 12),
          if (treatments.isEmpty)
            const RecordCard(
              child: EmptyState(
                icon: Icons.medication_outlined,
                title: 'Aucun traitement en cours',
              ),
            ),
          for (final (index, treatment) in treatments.indexed)
            FadeSlideIn(
              index: index,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: RecordCard(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF8F74E8), Color(0xFF6A4CC9)],
                          ),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(
                          Icons.medication,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              treatment.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                color: RecordColors.ink,
                              ),
                            ),
                            if (treatment.posology.isNotEmpty)
                              Text(
                                treatment.posology,
                                style: const TextStyle(
                                  color: RecordColors.muted,
                                ),
                              ),
                          ],
                        ),
                      ),
                      if (treatment.startedAt != null)
                        Text(
                          'Depuis\n${formatShortDay(treatment.startedAt!)} ${treatment.startedAt!.year}',
                          textAlign: TextAlign.right,
                          style: const TextStyle(
                            color: RecordColors.muted,
                            fontSize: 11,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          const SizedBox(height: 18),
          const SectionTitle(
            icon: Icons.receipt_long_outlined,
            title: 'Ordonnances',
            color: RecordColors.prescription,
          ),
          const SizedBox(height: 12),
          if (file.prescriptions.isEmpty)
            const RecordCard(
              child: EmptyState(
                icon: Icons.receipt_long_outlined,
                title: 'Aucune ordonnance',
                message:
                    'Les ordonnances émises via la pharmacie apparaissent ici.',
              ),
            ),
          for (final prescription in file.prescriptions)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: RecordCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            formatDay(prescription.createdAt),
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              color: RecordColors.ink,
                            ),
                          ),
                        ),
                        StatusPill(
                          label: prescription.statusLabel,
                          color: RecordColors.prescription,
                        ),
                      ],
                    ),
                    if (prescription.doctor.name.isNotEmpty)
                      Text(
                        'Dr ${prescription.doctor.name}',
                        style: const TextStyle(color: RecordColors.muted),
                      ),
                    const Divider(height: 20),
                    for (final line in prescription.medications)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 3),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.check_circle_outline,
                              size: 16,
                              color: RecordColors.prescription,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text('${line.name} — ${line.dosage}'),
                            ),
                            Text(
                              '×${line.quantity}',
                              style: const TextStyle(color: RecordColors.muted),
                            ),
                          ],
                        ),
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
