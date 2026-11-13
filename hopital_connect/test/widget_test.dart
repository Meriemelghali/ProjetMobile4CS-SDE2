import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hopital_connect/app.dart';
import 'package:hopital_connect/features/dashboard/presentation/dashboard_page.dart';
import 'package:hopital_connect/features/users/domain/staff_role.dart';
import 'package:hopital_connect/features/users/domain/staff_user.dart';

void main() {
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
        home: PatientHomeTab(
          user: const StaffUser(
            id: 'patient-id',
            displayName: 'Test Patient',
            email: 'patient@example.test',
            role: StaffRole.patient,
          ),
        ),
      ),
    );

    expect(find.text('Test Patient'), findsOneWidget);
    expect(find.text('Patient'), findsOneWidget);
    expect(find.text('Planning'), findsNothing);
    expect(find.text('Transmissions'), findsNothing);
  });
}
