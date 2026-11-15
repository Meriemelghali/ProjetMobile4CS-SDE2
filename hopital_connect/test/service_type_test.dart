import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hopital_connect/features/dashboard/presentation/doctor_space_tabs.dart';
import 'package:hopital_connect/features/services/domain/hospital_service.dart';
import 'package:hopital_connect/features/services/presentation/service_form_dialog.dart';
import 'package:hopital_connect/features/auth/presentation/role_selection_page.dart';
import 'package:hopital_connect/features/users/domain/staff_role.dart';
import 'package:hopital_connect/features/users/domain/staff_user.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('service types expose the requested categories', () {
    expect(ServiceType.values.map((type) => type.label).toList(), [
      'Médical',
      'Chirurgical',
      'Urgence',
      'Soins intensifs',
      'Maternité',
      'Médico-technique',
      'Administratif',
      'Autre',
    ]);
  });

  test('service types keep parsing legacy categories', () {
    expect(ServiceType.fromString('radiologie'), ServiceType.medicoTechnical);
    expect(ServiceType.fromString('gynecologie'), ServiceType.maternity);
    expect(ServiceType.fromString('reanimation'), ServiceType.intensiveCare);
    expect(ServiceType.fromString('surgical'), ServiceType.surgical);
  });

  test('service JSON uses the API category identifiers', () {
    const service = HospitalService(
      id: '',
      name: 'Urgences',
      location: '',
      description: '',
      serviceType: ServiceType.emergency,
    );

    expect(service.toJson()['serviceType'], 'emergency');
  });

  test('service feature flags default to false for missing and null JSON', () {
    final missing = HospitalService.fromJson({
      '_id': 'pediatric',
      'name': 'Pédiatrie',
    });
    final nullValues = HospitalService.fromJson({
      '_id': 'pediatric',
      'name': 'Pédiatrie',
      'a_rdv': null,
      'a_operations': null,
      'a_gardes': null,
    });

    expect(missing.hasAppointments, isFalse);
    expect(missing.hasOperations, isFalse);
    expect(missing.hasOnCall, isFalse);
    expect(nullValues.hasOperations, isFalse);
  });

  test('service feature flags round-trip with the API field names', () {
    final service = HospitalService.fromJson({
      '_id': 'surgery',
      'name': 'Chirurgie',
      'a_rdv': true,
      'a_operations': true,
      'a_gardes': true,
    });

    expect(service.toJson(), containsPair('a_rdv', true));
    expect(service.toJson(), containsPair('a_operations', true));
    expect(service.toJson(), containsPair('a_gardes', true));
  });

  testWidgets('doctor with no services keeps the standard home sections', (
    tester,
  ) async {
    const user = StaffUser(
      id: 'doctor-1',
      displayName: 'Dr Ada',
      email: 'ada@example.test',
      role: StaffRole.doctor,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DoctorHomeTab(
            user: user,
            services: const [],
            appointments: const [],
            interventions: const [],
            shifts: const [],
            handovers: const [],
            onOpenPlanning: () {},
            onHandoverTap: (_) {},
          ),
        ),
      ),
    );

    expect(find.text('Aucun service attribué'), findsOneWidget);
    expect(find.text('RDV aujourd’hui'), findsOneWidget);
    expect(find.text('Opérations aujourd’hui'), findsNothing);
    expect(find.text('Prochain patient'), findsOneWidget);
    expect(find.text('Prochaine garde'), findsOneWidget);
  });

  testWidgets('doctor capabilities are the union of assigned services', (
    tester,
  ) async {
    const user = StaffUser(
      id: 'doctor-1',
      displayName: 'Dr Ada',
      email: 'ada@example.test',
      role: StaffRole.doctor,
      serviceIds: ['pediatric', 'surgery'],
    );
    const services = [
      HospitalService(
        id: 'pediatric',
        name: 'Pédiatrie',
        location: '',
        description: '',
      ),
      HospitalService(
        id: 'surgery',
        name: 'Chirurgie',
        location: '',
        description: '',
        hasOperations: true,
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DoctorHomeTab(
            user: user,
            services: services,
            appointments: const [],
            interventions: const [],
            shifts: const [],
            handovers: const [],
            onOpenPlanning: () {},
            onHandoverTap: (_) {},
          ),
        ),
      ),
    );

    expect(find.text('Opérations aujourd’hui'), findsOneWidget);
    expect(find.text('RDV aujourd’hui'), findsOneWidget);
  });

  test('service head assignment is serialized and role is parsed', () {
    const service = HospitalService(
      id: '',
      name: 'Urgences',
      location: '',
      description: '',
      headUserId: 'user-123',
    );

    expect(service.toJson()['headUserId'], 'user-123');
    expect(StaffRole.fromApiValue('service_head'), StaffRole.serviceHead);
    expect(
      StaffRole.fromApiValue('operating_room_manager'),
      StaffRole.operatingRoomManager,
    );
    expect(StaffRole.fromApiValue('secretary'), StaffRole.secretary);
    expect(
      StaffUser.fromJson({
        '_id': 'secretary-1',
        'username': 'Secretary',
        'email': 'secretary@example.test',
        'role': 'secretary',
      }).role,
      StaffRole.secretary,
    );
  });

  test('staff account parses all assigned roles', () {
    final user = StaffUser.fromJson({
      '_id': 'user-1',
      'username': 'Meriem',
      'email': 'meriem@example.test',
      'role': 'admin',
      'roles': ['admin', 'service_head', 'patient'],
      'hospitalId': 'hospital-1',
      'serviceId': 'service-1',
    });

    expect(user.assignedRoles, [
      StaffRole.administrator,
      StaffRole.serviceHead,
      StaffRole.patient,
    ]);
    expect(user.hospitalId, 'hospital-1');
    expect(user.serviceId, 'service-1');
  });

  testWidgets('multiple assigned roles are offered after login', (
    tester,
  ) async {
    final user = StaffUser(
      id: 'user-1',
      displayName: 'Meriem',
      email: 'meriem@example.test',
      role: StaffRole.administrator,
      roles: const [StaffRole.administrator, StaffRole.serviceHead],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: RoleSelectionPage(user: user, selectionToken: 'selection-token'),
      ),
    );

    expect(find.text('Administrateur'), findsOneWidget);
    expect(find.text('Responsable de service'), findsOneWidget);
    expect(find.text('Continuer'), findsOneWidget);
  });

  testWidgets('service head selector filters users by active role', (
    tester,
  ) async {
    final users = [
      const StaffUser(
        id: 'head-1',
        displayName: 'Chef actif',
        email: 'head@example.test',
        role: StaffRole.serviceHead,
      ),
      const StaffUser(
        id: 'doctor-1',
        displayName: 'Médecin',
        email: 'doctor@example.test',
        role: StaffRole.doctor,
      ),
      const StaffUser(
        id: 'head-2',
        displayName: 'Chef inactif',
        email: 'inactive@example.test',
        role: StaffRole.serviceHead,
        isActive: false,
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showDialog<void>(
                context: context,
                builder: (_) => ServiceFormDialog(users: users),
              ),
              child: const Text('Ouvrir'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Ouvrir'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();

    expect(find.text('Chef actif'), findsOneWidget);
    expect(find.text('Médecin'), findsNothing);
    expect(find.text('Chef inactif'), findsNothing);
  });
}
