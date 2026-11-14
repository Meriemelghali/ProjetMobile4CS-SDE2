import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hopital_connect/app.dart';
import 'package:hopital_connect/features/appointments/domain/appointment.dart';
import 'package:hopital_connect/features/appointments/presentation/patient_home_tab.dart';
import 'package:hopital_connect/features/dashboard/presentation/doctor_space_tabs.dart';
import 'package:hopital_connect/features/users/domain/staff_role.dart';
import 'package:hopital_connect/features/users/domain/staff_user.dart';

void main() {
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
    expect(find.text('Créer un compte patient'), findsOneWidget);
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

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DoctorPlanningTab(
            appointments: [appointment],
            shifts: const [],
          ),
        ),
      ),
    );

    expect(find.textContaining('Test patient'), findsOneWidget);
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
