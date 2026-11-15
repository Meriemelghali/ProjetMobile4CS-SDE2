import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hopital_connect/features/planning/domain/shift.dart';
import 'package:hopital_connect/features/planning/presentation/planning_tab.dart';
import 'package:hopital_connect/features/services/domain/hospital_service.dart';
import 'package:hopital_connect/features/users/domain/staff_role.dart';
import 'package:hopital_connect/features/users/domain/staff_user.dart';

void main() {
  testWidgets(
    'shift dialog offers doctors only and follows the selected specialty',
    (tester) async {
      const doctors = [
        StaffUser(
          id: 'cardiology-doctor',
          displayName: 'Dr Cardio',
          email: 'cardio@example.test',
          role: StaffRole.doctor,
          specialty: 'Cardiologie',
        ),
        StaffUser(
          id: 'neurology-doctor',
          displayName: 'Dr Neuro',
          email: 'neuro@example.test',
          role: StaffRole.doctor,
          specialty: 'Neurologie',
        ),
        StaffUser(
          id: 'administrator',
          displayName: 'Admin',
          email: 'admin@example.test',
          role: StaffRole.administrator,
        ),
      ];
      const services = [
        HospitalService(
          id: 'cardiology-service',
          name: 'Cardiologie',
          location: '',
          description: '',
          serviceType: ServiceType.medical,
        ),
        HospitalService(
          id: 'neurology-service',
          name: 'Neurologie',
          location: '',
          description: '',
          serviceType: ServiceType.medical,
        ),
      ];
      Shift? savedShift;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => FilledButton(
                onPressed: () async {
                  savedShift = await showDialog<Shift>(
                    context: context,
                    builder: (_) => const NewShiftDialog(
                      services: services,
                      users: doctors,
                    ),
                  );
                },
                child: const Text('Ouvrir'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Ouvrir'));
      await tester.pumpAndSettle();
      expect(
        find.byType(DropdownButtonFormField<HospitalService>),
        findsNothing,
      );
      expect(find.text('Cardiologie'), findsOneWidget);

      await tester.tap(find.byType(DropdownButtonFormField<StaffUser>));
      await tester.pumpAndSettle();
      expect(find.text('Admin · Administrateur'), findsNothing);
      await tester.tap(find.text('Dr Neuro · Neurologie'));
      await tester.pumpAndSettle();
      expect(find.text('Neurologie'), findsOneWidget);

      await tester.tap(find.text('Enregistrer'));
      await tester.pumpAndSettle();
      expect(savedShift?.userId, 'neurology-doctor');
      expect(savedShift?.serviceId, 'neurology-service');
    },
  );
}
