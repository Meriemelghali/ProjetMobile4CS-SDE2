import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hopital_connect/app.dart';
import 'package:hopital_connect/features/appointments/domain/appointment.dart';
import 'package:hopital_connect/features/appointments/presentation/patient_home_tab.dart';
import 'package:hopital_connect/features/dashboard/presentation/dashboard_page.dart';
import 'package:hopital_connect/features/dashboard/presentation/doctor_space_tabs.dart';
import 'package:hopital_connect/features/hospital/domain/hospital_resources.dart';
import 'package:hopital_connect/features/planning/domain/shift.dart';
import 'package:hopital_connect/features/services/domain/hospital_service.dart';
import 'package:hopital_connect/features/transmissions/domain/handover.dart';
import 'package:hopital_connect/features/users/domain/staff_role.dart';
import 'package:hopital_connect/features/users/domain/staff_user.dart';

void main() {
  testWidgets('service head home lists every managed service', (tester) async {
    const user = StaffUser(
      id: 'head-id',
      displayName: 'Responsable',
      email: 'head@example.test',
      role: StaffRole.serviceHead,
      serviceId: 'legacy-assignment',
    );
    const services = [
      HospitalService(
        id: 'cardiology',
        name: 'Cardiologie',
        location: '',
        description: '',
        headUserId: 'head-id',
      ),
      HospitalService(
        id: 'pediatrics',
        name: 'Pédiatrie',
        location: '',
        description: '',
        headUserId: 'head-id',
      ),
      HospitalService(
        id: 'legacy-assignment',
        name: 'Médecine générale',
        location: '',
        description: '',
      ),
      HospitalService(
        id: 'unrelated',
        name: 'Urgences',
        location: '',
        description: '',
        headUserId: 'another-head',
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: HomeTab(
            user: user,
            services: services,
            nextShift: null,
            latestHandover: null,
            onHandoverTap: (_) {},
          ),
        ),
      ),
    );

    expect(
      find.text('Cardiologie, Pédiatrie, Médecine générale'),
      findsOneWidget,
    );
    expect(find.text('Aucun service attribué'), findsNothing);
  });

  test('appointment updates and secretary service assignments deserialize', () {
    expect(
      AppointmentStatus.fromApiValue('proposed'),
      AppointmentStatus.proposed,
    );
    expect(
      AppointmentStatus.fromApiValue('rejected'),
      AppointmentStatus.rejected,
    );

    final secretary = StaffUser.fromJson({
      '_id': 'secretary-id',
      'username': 'Secrétaire',
      'email': 'secretary@example.test',
      'role': 'secretary',
      'serviceId': 'service-one',
      'serviceIds': ['service-one', 'service-two'],
    });

    expect(secretary.serviceIds, ['service-one', 'service-two']);
  });

  testWidgets('affiche le formulaire de connexion', (tester) async {
    await tester.pumpWidget(const HopitalConnectApp());

    expect(find.text('Connexion'), findsOneWidget);
    expect(find.text('Adresse e-mail'), findsOneWidget);
    expect(find.text('Mot de passe'), findsOneWidget);
    expect(find.text('Rôle de démonstration'), findsNothing);
    expect(find.text('Créer un compte'), findsOneWidget);

    await tester.tap(find.text('Créer un compte'));
    await tester.pumpAndSettle();

    expect(find.text('Créer un compte'), findsOneWidget);
    expect(find.text('Inscription'), findsOneWidget);
  });

  testWidgets('patient home exposes only the patient account', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PatientHomeTab(
            user: const StaffUser(
              id: 'patient-id',
              displayName: 'Test Patient',
              email: 'patient@example.test',
              role: StaffRole.patient,
            ),
            appointments: const [],
            onBookAppointment: _noop,
            onOpenAppointments: _noop,
            onOpenFollowUps: _noopFollowUps,
            onOpenProfile: _noop,
            onShowAppointmentDetails: _noopAppointment,
            onEditAppointment: _noopAppointment,
            onCancelAppointment: _noopAppointment,
            onOpenDirections: _noopNullableAppointment,
            onContactHospital: _noopNullableAppointment,
            onEmergency: _noop,
          ),
        ),
      ),
    );

    expect(find.text('Test'), findsOneWidget);
    expect(find.text('Planning'), findsNothing);
    expect(find.text('Transmissions'), findsNothing);
  });

  testWidgets(
    'doctor home keeps its non-operation sections without a service',
    (tester) async {
      final now = DateTime.now();
      final appointment = Appointment(
        id: 'appointment-id',
        patientId: 'patient-id',
        patientName: 'Test patient',
        doctorId: 'doctor-id',
        doctorName: 'Dr Test',
        serviceName: 'Pédiatrie',
        serviceLocation: 'Bâtiment A',
        servicePhone: '',
        serviceEmail: '',
        startAt: now.add(const Duration(minutes: 30)),
        reason: 'Consultation',
        status: AppointmentStatus.accepted,
      );
      final shift = Shift(
        id: 'shift-id',
        userId: 'doctor-id',
        serviceId: 'service-id',
        start: now.add(const Duration(days: 1)),
        end: now.add(const Duration(days: 1, hours: 8)),
        role: 'doctor',
      );
      final handover = Handover(
        id: 'handover-id',
        serviceId: 'service-id',
        authorId: 'author-id',
        title: 'Transmission récente',
        message: 'À lire',
        createdAt: now,
        author: 'Dr Auteur',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DoctorHomeTab(
              user: const StaffUser(
                id: 'doctor-id',
                displayName: 'Dr Test',
                email: 'doctor@example.test',
                role: StaffRole.doctor,
              ),
              services: const [],
              appointments: [appointment],
              interventions: const [],
              shifts: [shift],
              handovers: [handover],
              onOpenPlanning: _noop,
              onHandoverTap: _noopHandover,
            ),
          ),
        ),
      );

      expect(find.text('Aucun service attribué'), findsOneWidget);
      expect(find.text('RDV aujourd’hui'), findsOneWidget);
      expect(find.textContaining('Test patient'), findsOneWidget);
      expect(find.text('Prochaine garde'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.textContaining('Garde à venir'),
        250,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.textContaining('Garde à venir'), findsOneWidget);
      expect(find.textContaining('transmission non lue'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('À retenir'),
        250,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('À retenir'), findsOneWidget);
      expect(find.text('Transmission récente'), findsOneWidget);
      expect(find.text('Opérations aujourd’hui'), findsNothing);
      expect(find.textContaining('Opération prévue demain'), findsNothing);
    },
  );

  testWidgets('doctor planning displays appointments without edit actions', (
    tester,
  ) async {
    final appointment = Appointment(
      id: 'appointment-id',
      patientId: 'patient-id',
      patientName: 'Test patient',
      doctorId: 'doctor-id',
      doctorName: 'Dr Test',
      serviceName: 'Cardiologie',
      serviceLocation: 'Bâtiment A',
      servicePhone: '',
      serviceEmail: '',
      startAt: DateTime.now().add(const Duration(minutes: 30)),
      reason: 'Consultation',
      status: AppointmentStatus.accepted,
    );
    final operation = HospitalIntervention(
      id: 'intervention-id',
      surgeonId: 'doctor-id',
      patientId: 'patient-id',
      operatingRoomId: 'or-id',
      title: 'Opération non autorisée',
      start: DateTime.now().add(const Duration(minutes: 45)),
      end: DateTime.now().add(const Duration(hours: 1)),
      equipmentIds: const [],
      serviceId: 'surgery-id',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DoctorPlanningTab(
            appointments: [appointment],
            interventions: [operation],
            shifts: const [],
            hasService: false,
            hasOperations: false,
            operationServiceIds: const {},
          ),
        ),
      ),
    );

    expect(find.textContaining('Test patient'), findsOneWidget);
    expect(find.text('1 RDV'), findsOneWidget);
    expect(find.text('Opérations'), findsNothing);
    expect(find.textContaining('Opération non autorisée'), findsNothing);
    expect(find.textContaining('lecture seule'), findsOneWidget);
    await tester.tap(find.textContaining('Test patient'));
    await tester.pumpAndSettle();
    expect(find.text('Rendez-vous · lecture seule'), findsOneWidget);
    expect(find.text('Modifier'), findsNothing);
  });
}

void _noop() {}
void _noopFollowUps(Object _) {}
void _noopAppointment(Object _) {}
void _noopNullableAppointment(Object? _) {}
void _noopHandover(Handover _) {}
