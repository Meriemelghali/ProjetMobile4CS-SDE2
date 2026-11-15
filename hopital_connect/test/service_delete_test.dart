import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hopital_connect/features/services/domain/hospital_service.dart';
import 'package:hopital_connect/features/services/presentation/service_card.dart';

void main() {
  testWidgets('service card exposes delete action to administrators', (
    tester,
  ) async {
    var deleteRequested = false;
    const service = HospitalService(
      id: 'service-id',
      name: 'Cardiologie',
      location: '',
      description: '',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ServiceCard(
            service: service,
            canEdit: true,
            onDelete: () => deleteRequested = true,
          ),
        ),
      ),
    );

    await tester.tap(find.byTooltip('Supprimer'));

    expect(deleteRequested, isTrue);
  });
}
