import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hopital_connect/core/session/app_session.dart';
import 'package:hopital_connect/features/medical_records/domain/medical_record.dart';
import 'package:hopital_connect/features/medical_records/presentation/emergency_card_page.dart';
import 'package:hopital_connect/features/medical_records/presentation/medical_record_page.dart';
import 'package:hopital_connect/features/splash/splash_page.dart';
import 'package:hopital_connect/features/users/domain/staff_role.dart';
import 'package:hopital_connect/features/medical_records/utils/medical_record_pdf.dart';

const _patientId = '65f1a2b3c4d5e6f708192a3b';

Map<String, dynamic> _fileJson() {
  final now = DateTime.now().toUtc();
  String daysAgo(int days) =>
      now.subtract(Duration(days: days)).toIso8601String();
  return {
    'patient': {
      '_id': _patientId,
      'displayName': 'Yasmine Ben Salah',
      'email': 'patient.yasmine.demo@demo.test',
      'birthDate': '1992-05-12T00:00:00.000Z',
      'emergencyContact': 'Hichem · +216 20 000 102',
      'insurance': 'CNAM',
    },
    'record': {
      'exists': true,
      'bloodType': 'A+',
      'heightCm': 165,
      'allergies': [
        {
          'name': 'Pénicilline',
          'severity': 'severe',
          'reaction': 'Œdème',
          'source': 'record',
        },
        {'name': 'Pollen', 'severity': null, 'source': 'patient'},
      ],
      'chronicConditions': [
        {'name': 'Asthme allergique', 'since': '2006-01-01T00:00:00.000Z'},
      ],
      'history': {
        'medical': ['Bronchiolite'],
        'surgical': ['Appendicectomie'],
        'family': [],
      },
      'currentTreatments': [
        {
          'name': 'Salbutamol',
          'dosage': '2 bouffées',
          'frequency': 'Si besoin',
        },
      ],
      'vaccinations': [
        {'name': 'Grippe', 'date': daysAgo(60)},
      ],
      'updatedAt': daysAgo(2),
    },
    'consultations': [
      {
        '_id': 'c1',
        'date': daysAgo(40),
        'reason': 'Bilan annuel',
        'diagnosis': 'Asthme contrôlé',
        'doctor': {'_id': 'd1', 'name': 'Karim Haddad'},
        'followUpAt': now.add(const Duration(days: 20)).toIso8601String(),
      },
      {
        '_id': 'c2',
        'date': daysAgo(120),
        'reason': 'Crise d’asthme',
        'doctor': {'_id': 'd1', 'name': 'Karim Haddad'},
      },
    ],
    'vitals': [
      {
        '_id': 'v2',
        'recordedAt': daysAgo(3),
        'systolic': 118,
        'diastolic': 76,
        'heartRate': 130,
        'spo2': 97,
        'weightKg': 61,
        'recordedBy': {'_id': 'n1', 'name': 'Sarra Mansour'},
      },
      {
        '_id': 'v1',
        'recordedAt': daysAgo(30),
        'systolic': 120,
        'diastolic': 78,
        'heartRate': 74,
        'spo2': 98,
        'weightKg': 61.4,
        'recordedBy': {'_id': 'n1', 'name': 'Sarra Mansour'},
      },
    ],
    'prescriptions': [],
    'appointments': [
      {
        '_id': 'a1',
        'startAt': daysAgo(41),
        'status': 'accepted',
        'reason': 'Bilan',
        'doctor': {'_id': 'd1', 'name': 'Karim Haddad'},
      },
    ],
  };
}

void main() {
  group('domain', () {
    test('parses the full medical file and derives key facts', () {
      final file = PatientMedicalFile.fromJson(_fileJson());

      expect(file.patient.displayName, 'Yasmine Ben Salah');
      expect(file.patient.initials, 'YB');
      expect(file.record.bloodType, BloodType.aPositive);
      expect(file.record.severeAllergies.single.name, 'Pénicilline');
      expect(file.record.allergies.last.declaredByPatient, isTrue);
      // Les constantes sont triées de la plus ancienne à la plus récente.
      expect(file.vitals.first.id, 'v1');
      expect(file.latestVital(VitalKind.heartRate)!.heartRate, 130);
      expect(file.alertingVitals, [VitalKind.heartRate]);
      expect(file.bmi, closeTo(22.4, 0.1));
      expect(file.nextFollowUp?.id, 'c1');
      expect(file.timeline.map((e) => e.kind), [
        TimelineKind.consultation,
        TimelineKind.appointment,
        TimelineKind.consultation,
      ]);
    });

    test('classifies vital signs into normal, warning and critical', () {
      expect(VitalKind.heartRate.classify(72), VitalStatus.normal);
      expect(VitalKind.heartRate.classify(110), VitalStatus.warning);
      expect(VitalKind.heartRate.classify(130), VitalStatus.critical);
      expect(VitalKind.spo2.classify(93), VitalStatus.warning);
      expect(VitalKind.spo2.classify(89), VitalStatus.critical);
      expect(VitalKind.temperature.classify(38.0), VitalStatus.warning);
      expect(VitalKind.weight.classify(140), VitalStatus.normal);
      expect(classifyDiastolic(104), VitalStatus.critical);

      final vital = VitalSign(
        id: 'x',
        recordedAt: DateTime(2026),
        recordedBy: const PersonRef(id: '', name: ''),
        systolic: 128,
        diastolic: 95,
      );
      // La diastolique « à surveiller » l'emporte sur une systolique normale.
      expect(vital.statusOf(VitalKind.bloodPressure), VitalStatus.warning);
      expect(vital.display(VitalKind.bloodPressure), '128/95');
    });

    test('record updates exclude patient-declared allergies', () {
      final file = PatientMedicalFile.fromJson(_fileJson());
      final json = file.record.toUpdateJson();
      final allergies = json['allergies']! as List;
      expect(allergies, hasLength(1));
      expect((allergies.single as Map)['name'], 'Pénicilline');
      expect(json['bloodType'], 'A+');
    });

    test('vital drafts only send filled measurements', () {
      final draft = VitalDraft(recordedAt: DateTime.utc(2026), heartRate: 80);
      expect(draft.isEmpty, isFalse);
      expect(draft.toJson().keys, ['recordedAt', 'heartRate']);
      expect(VitalDraft(recordedAt: DateTime.utc(2026)).isEmpty, isTrue);
    });

    test('PDF export produces a document with French accents', () async {
      final bytes = await MedicalRecordPdf.build(
        PatientMedicalFile.fromJson(_fileJson()),
      );
      expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
      expect(bytes.length, greaterThan(3000));
    });

    test('emergency QR codes carry only a valid record identifier', () {
      final payload = emergencyQrPayload(_patientId);
      expect(patientIdFromQr(payload), _patientId);
      expect(patientIdFromQr('https://example.test'), isNull);
      expect(patientIdFromQr('hopitalconnect://record/not-an-id'), isNull);
    });
  });

  group('widgets', () {
    Future<void> pumpRecord(WidgetTester tester, StaffRole role) async {
      tester.view.physicalSize = const Size(1000, 2000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          home: MedicalRecordPage(
            patientId: _patientId,
            viewerRole: role,
            viewerId: 'd1',
            initialFile: PatientMedicalFile.fromJson(_fileJson()),
          ),
        ),
      );
      await tester.pump(const Duration(seconds: 2));
    }

    testWidgets('record page shows the severe allergy banner and tabs', (
      tester,
    ) async {
      await pumpRecord(tester, StaffRole.doctor);

      expect(find.text('ALLERGIE SÉVÈRE'), findsOneWidget);
      expect(find.text('Synthèse'), findsOneWidget);
      expect(find.text('Historique'), findsOneWidget);
      expect(find.text('Constantes'), findsOneWidget);
      expect(find.text('Traitements'), findsOneWidget);
      expect(find.text('1 constante hors norme'), findsOneWidget);
      expect(find.text('Ajouter'), findsOneWidget);
    });

    testWidgets('nurses can only add vitals and patients see their card', (
      tester,
    ) async {
      await pumpRecord(tester, StaffRole.nurse);
      expect(
        find.widgetWithText(FloatingActionButton, 'Constantes'),
        findsOneWidget,
      );
      expect(find.text('Ajouter'), findsNothing);

      await pumpRecord(tester, StaffRole.patient);
      expect(find.text('Carte d’urgence'), findsOneWidget);
    });

    testWidgets('embedded patient record opens the tab asked by the home', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1000, 2000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      Widget page(int tab, int request) => MaterialApp(
        home: MedicalRecordPage(
          embedded: true,
          viewerRole: StaffRole.patient,
          viewerId: _patientId,
          initialFile: PatientMedicalFile.fromJson(_fileJson()),
          initialTab: tab,
          tabRequest: request,
        ),
      );
      await tester.pumpWidget(page(0, 0));
      await tester.pump(const Duration(seconds: 1));
      expect(find.byType(BackButton), findsNothing);
      expect(find.text('Dernières constantes'), findsOneWidget);

      // « Mes ordonnances » sur l'accueil → onglet Traitements.
      await tester.pumpWidget(page(3, 1));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('Traitements en cours'), findsOneWidget);
    });

    testWidgets('emergency card flips to reveal the QR code', (tester) async {
      tester.view.physicalSize = const Size(1000, 2000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          home: EmergencyCardPage(
            file: PatientMedicalFile.fromJson(_fileJson()),
          ),
        ),
      );
      expect(find.text('CARTE D’URGENCE MÉDICALE'), findsOneWidget);
      await tester.tap(find.text('Afficher le QR code'));
      await tester.pumpAndSettle();
      expect(find.text('CARTE D’URGENCE MÉDICALE'), findsNothing);
      expect(find.textContaining('scannez ce code'), findsOneWidget);
    });

    testWidgets('splash screen opens the login page without a session', (
      tester,
    ) async {
      AppSession? received;
      await tester.pumpWidget(
        MaterialApp(
          home: SplashPage(
            minimumDuration: const Duration(milliseconds: 300),
            restoreSession: () async => null,
            destinationBuilder: (session) {
              received = session;
              return const Scaffold(body: Text('Connexion'));
            },
          ),
        ),
      );
      expect(find.text('HôpitalConnect'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(milliseconds: 700));
      expect(find.text('Connexion'), findsOneWidget);
      expect(received, isNull);
    });
  });
}
