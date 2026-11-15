// =============================================================================
// Export PDF du dossier médical (synthèse imprimable / partageable).
// Construit avec les packages `pdf` et `printing`, comme la fiche service.
// =============================================================================

import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../domain/medical_record.dart';
import '../presentation/widgets/record_ui.dart' show formatDay, formatDayTime;

abstract final class MedicalRecordPdf {
  static const _navy = PdfColor.fromInt(0xFF123047);
  static const _blue = PdfColor.fromInt(0xFF176B87);
  static const _mint = PdfColor.fromInt(0xFF36A98B);
  static const _red = PdfColor.fromInt(0xFFD64545);
  static const _light = PdfColor.fromInt(0xFFF4F7F8);
  static const _grey = PdfColor.fromInt(0xFF687B86);

  /// La police standard du PDF ne couvre que le jeu Latin-1 étendu :
  /// on remplace les quelques caractères hors de ce jeu.
  static String _t(String value) => value
      .replaceAll('₂', '2')
      .replaceAll('µ', 'u')
      .replaceAll('—', '-')
      .replaceAll('–', '-')
      .replaceAll('·', '-')
      .replaceAll('’', "'")
      .replaceAll('œ', 'oe')
      .replaceAll('Œ', 'Oe');

  static Future<void> open(PatientMedicalFile file) async {
    final bytes = await build(file);
    await Printing.layoutPdf(
      onLayout: (_) async => bytes,
      name: 'Dossier-${file.patient.displayName.replaceAll(' ', '-')}.pdf',
    );
  }

  static Future<Uint8List> build(PatientMedicalFile file) async {
    final doc = pw.Document(
      title: _t('Dossier médical - ${file.patient.displayName}'),
      author: 'HôpitalConnect',
    );
    final record = file.record;
    final generatedAt = DateTime.now();

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(36, 32, 36, 32),
        header: (context) => context.pageNumber == 1
            ? _header(file, generatedAt)
            : pw.Container(
                padding: const pw.EdgeInsets.only(bottom: 8),
                child: pw.Text(
                  _t('Dossier médical - ${file.patient.displayName}'),
                  style: const pw.TextStyle(color: _grey, fontSize: 9),
                ),
              ),
        footer: (context) => pw.Container(
          padding: const pw.EdgeInsets.only(top: 8),
          decoration: const pw.BoxDecoration(
            border: pw.Border(top: pw.BorderSide(color: _light)),
          ),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                _t(
                  'Document de démonstration - données fictives - confidentiel',
                ),
                style: const pw.TextStyle(color: _grey, fontSize: 8),
              ),
              pw.Text(
                'Page ${context.pageNumber}/${context.pagesCount}',
                style: const pw.TextStyle(color: _grey, fontSize: 8),
              ),
            ],
          ),
        ),
        build: (context) => [
          pw.SizedBox(height: 14),
          _keyFacts(file),
          if (record.severeAllergies.isNotEmpty) ...[
            pw.SizedBox(height: 12),
            pw.Container(
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(
                color: const PdfColor.fromInt(0xFFFDECEC),
                border: pw.Border.all(color: _red),
                borderRadius: pw.BorderRadius.circular(6),
              ),
              child: pw.Text(
                _t(
                  'ALERTE ALLERGIE SÉVÈRE : ${record.severeAllergies.map((a) => a.name).join(', ')}',
                ),
                style: pw.TextStyle(
                  color: _red,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ),
          ],
          _section('Allergies'),
          record.allergies.isEmpty
              ? _muted('Aucune allergie connue')
              : _table(
                  ['Allergène', 'Sévérité', 'Réaction'],
                  [
                    for (final a in record.allergies)
                      [
                        a.name,
                        a.severity?.label ?? 'Déclarée par le patient',
                        a.reaction,
                      ],
                  ],
                ),
          _section('Pathologies chroniques'),
          record.chronicConditions.isEmpty
              ? _muted('Aucune pathologie chronique')
              : _bullets([
                  for (final c in record.chronicConditions)
                    [
                      c.name,
                      if (c.since != null) 'depuis ${c.since!.year}',
                      if (c.notes.isNotEmpty) c.notes,
                    ].join(' - '),
                ]),
          _section('Traitements en cours'),
          record.currentTreatments.isEmpty
              ? _muted('Aucun traitement en cours')
              : _table(
                  ['Médicament', 'Posologie', 'Depuis'],
                  [
                    for (final t in record.currentTreatments)
                      [
                        t.name,
                        t.posology,
                        t.startedAt == null ? '' : formatDay(t.startedAt!),
                      ],
                  ],
                ),
          _section('Antécédents'),
          _bullets([
            'Médicaux : ${_join(record.history.medical)}',
            'Chirurgicaux : ${_join(record.history.surgical)}',
            'Familiaux : ${_join(record.history.family)}',
          ]),
          _section('Vaccinations'),
          record.vaccinations.isEmpty
              ? _muted('Aucune vaccination renseignée')
              : _bullets([
                  for (final v in record.vaccinations)
                    v.date == null
                        ? v.name
                        : '${v.name} (${formatDay(v.date!)})',
                ]),
          _section('Dernières constantes'),
          _vitalsTable(file),
          _section('Consultations récentes'),
          if (file.consultations.isEmpty) _muted('Aucune consultation'),
          for (final c in file.consultations.take(6)) _consultation(c),
        ],
      ),
    );
    return doc.save();
  }

  static String _join(List<String> items) =>
      items.isEmpty ? '-' : items.join(', ');

  static pw.Widget _header(PatientMedicalFile file, DateTime generatedAt) {
    final patient = file.patient;
    return pw.Container(
      padding: const pw.EdgeInsets.all(18),
      decoration: pw.BoxDecoration(
        gradient: const pw.LinearGradient(colors: [_navy, _blue]),
        borderRadius: pw.BorderRadius.circular(10),
      ),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  _t('HÔPITALCONNECT · DOSSIER MÉDICAL'),
                  style: pw.TextStyle(
                    color: _mint,
                    fontSize: 9,
                    fontWeight: pw.FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
                pw.SizedBox(height: 6),
                pw.Text(
                  _t(patient.displayName),
                  style: pw.TextStyle(
                    color: PdfColors.white,
                    fontSize: 22,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 4),
                pw.Text(
                  _t(
                    [
                      if (patient.age != null) '${patient.age} ans',
                      if (patient.birthDate != null)
                        'né(e) le ${formatDay(patient.birthDate!)}',
                      if (patient.insurance.isNotEmpty) patient.insurance,
                    ].join(' - '),
                  ),
                  style: const pw.TextStyle(
                    color: PdfColors.white,
                    fontSize: 10,
                  ),
                ),
                if (patient.emergencyContact.isNotEmpty)
                  pw.Text(
                    _t('Contact d\'urgence : ${patient.emergencyContact}'),
                    style: const pw.TextStyle(
                      color: PdfColors.white,
                      fontSize: 10,
                    ),
                  ),
              ],
            ),
          ),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: pw.BoxDecoration(
                  color: PdfColors.white,
                  borderRadius: pw.BorderRadius.circular(8),
                ),
                child: pw.Text(
                  file.record.bloodType.label,
                  style: pw.TextStyle(
                    color: _red,
                    fontSize: 18,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
              pw.SizedBox(height: 8),
              pw.Text(
                _t('Édité le ${formatDayTime(generatedAt)}'),
                style: const pw.TextStyle(color: PdfColors.white, fontSize: 8),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static pw.Widget _keyFacts(PatientMedicalFile file) {
    final facts = [
      (
        'Taille',
        file.record.heightCm == null
            ? '-'
            : '${file.record.heightCm!.round()} cm',
      ),
      ('IMC', file.bmi?.toStringAsFixed(1) ?? '-'),
      ('Consultations', '${file.consultations.length}'),
      ('Allergies', '${file.record.allergies.length}'),
    ];
    return pw.Row(
      children: [
        for (final (label, value) in facts)
          pw.Expanded(
            child: pw.Container(
              margin: const pw.EdgeInsets.symmetric(horizontal: 3),
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(
                color: _light,
                borderRadius: pw.BorderRadius.circular(8),
              ),
              child: pw.Column(
                children: [
                  pw.Text(
                    label,
                    style: const pw.TextStyle(color: _grey, fontSize: 9),
                  ),
                  pw.SizedBox(height: 3),
                  pw.Text(
                    value,
                    style: pw.TextStyle(
                      fontSize: 14,
                      fontWeight: pw.FontWeight.bold,
                      color: _navy,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  static pw.Widget _section(String title) => pw.Padding(
    padding: const pw.EdgeInsets.only(top: 16, bottom: 6),
    child: pw.Row(
      children: [
        pw.Container(width: 4, height: 14, color: _blue),
        pw.SizedBox(width: 6),
        pw.Text(
          _t(title.toUpperCase()),
          style: pw.TextStyle(
            color: _navy,
            fontSize: 11,
            fontWeight: pw.FontWeight.bold,
            letterSpacing: 0.8,
          ),
        ),
      ],
    ),
  );

  static pw.Widget _muted(String text) =>
      pw.Text(_t(text), style: const pw.TextStyle(color: _grey, fontSize: 10));

  static pw.Widget _bullets(List<String> items) => pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      for (final item in items)
        pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 3),
          child: pw.Bullet(
            text: _t(item),
            style: const pw.TextStyle(fontSize: 10),
            bulletColor: _blue,
          ),
        ),
    ],
  );

  static pw.Widget _table(List<String> headers, List<List<String>> rows) =>
      pw.TableHelper.fromTextArray(
        headers: headers.map(_t).toList(),
        data: rows.map((row) => row.map(_t).toList()).toList(),
        headerStyle: pw.TextStyle(
          color: PdfColors.white,
          fontSize: 9,
          fontWeight: pw.FontWeight.bold,
        ),
        headerDecoration: const pw.BoxDecoration(color: _blue),
        cellStyle: const pw.TextStyle(fontSize: 9),
        oddRowDecoration: const pw.BoxDecoration(color: _light),
        cellPadding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
        border: null,
      );

  static pw.Widget _vitalsTable(PatientMedicalFile file) {
    final rows = <List<String>>[];
    for (final kind in VitalKind.values) {
      final vital = file.latestVital(kind);
      if (vital == null) continue;
      final status = vital.statusOf(kind);
      rows.add([
        kind.label,
        '${vital.display(kind)} ${kind.unit}',
        kind.hasRange
            ? switch (status) {
                VitalStatus.critical => 'Hors norme',
                VitalStatus.warning => 'A surveiller',
                _ => 'Normal',
              }
            : '-',
        formatDay(vital.recordedAt),
      ]);
    }
    if (rows.isEmpty) return _muted('Aucune constante enregistrée');
    return _table(['Constante', 'Valeur', 'Statut', 'Date'], rows);
  }

  static pw.Widget _consultation(Consultation c) => pw.Container(
    margin: const pw.EdgeInsets.only(bottom: 8),
    padding: const pw.EdgeInsets.all(10),
    decoration: pw.BoxDecoration(
      border: pw.Border.all(color: _light, width: 1.2),
      borderRadius: pw.BorderRadius.circular(6),
    ),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              _t(c.reason),
              style: pw.TextStyle(
                fontWeight: pw.FontWeight.bold,
                fontSize: 11,
                color: _navy,
              ),
            ),
            pw.Text(
              _t(formatDay(c.date)),
              style: const pw.TextStyle(color: _grey, fontSize: 9),
            ),
          ],
        ),
        if (c.doctor.name.isNotEmpty)
          pw.Text(
            _t('Dr ${c.doctor.name}'),
            style: const pw.TextStyle(color: _grey, fontSize: 9),
          ),
        if (c.diagnosis.isNotEmpty) ...[
          pw.SizedBox(height: 4),
          pw.Text(
            _t('Diagnostic : ${c.diagnosis}'),
            style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
          ),
        ],
        if (c.notes.isNotEmpty)
          pw.Text(_t(c.notes), style: const pw.TextStyle(fontSize: 9.5)),
      ],
    ),
  );
}
