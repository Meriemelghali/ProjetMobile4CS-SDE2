import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hopital_connect/core/network/api_client.dart';
import 'package:hopital_connect/features/hospital/data/hospital_resource_service.dart';
import 'package:hopital_connect/features/hospital/domain/hospital_resources.dart';
import 'package:hopital_connect/features/hospital/presentation/hospital_tab.dart';
import 'package:hopital_connect/features/services/domain/hospital_service.dart';
import 'package:hopital_connect/features/users/domain/staff_user.dart';
import 'package:http/testing.dart';
import 'package:http/http.dart' as http;

void main() {
  group('hospital resource models', () {
    test('parses hospital room and bed fields from the API contract', () {
      final room = HospitalRoom.fromJson({
        '_id': 'room-1',
        'hospitalId': 'hospital-1',
        'serviceId': 'service-1',
        'number': '203',
        'floor': '2',
        'type': 'intensive_care',
        'status': 'available',
        'capacity': 4,
      });
      final bed = HospitalBed.fromJson({
        '_id': 'bed-1',
        'roomId': 'room-1',
        'number': '2A',
        'status': 'occupied',
        'patientId': 'patient-1',
        'assignedAt': '2026-11-14T12:00:00.000Z',
      });

      expect(room.type, RoomType.intensiveCare);
      expect(room.capacity, 4);
      expect(bed.status, BedStatus.occupied);
      expect(bed.patientId, 'patient-1');
      expect(bed.assignedAt, isNotNull);
    });

    test('serializes intervention schedule and required equipment IDs', () {
      final intervention = HospitalIntervention(
        id: '',
        surgeonId: 'doctor-1',
        patientId: 'patient-1',
        operatingRoomId: 'or-1',
        title: 'Intervention de démonstration',
        start: DateTime.utc(2026, 11, 14, 12),
        end: DateTime.utc(2026, 11, 14, 13),
        equipmentIds: const ['equipment-1'],
      );

      expect(intervention.toJson(), {
        'surgeonId': 'doctor-1',
        'patientId': 'patient-1',
        'operatingRoomId': 'or-1',
        'title': 'Intervention de démonstration',
        'start': '2026-11-14T12:00:00.000Z',
        'end': '2026-11-14T13:00:00.000Z',
        'equipmentIds': ['equipment-1'],
        'status': 'planned',
      });
    });
  });

  test('bed assignment sends the patient ID to the assignment route', () async {
    final client = MockClient((request) async {
      expect(request.method, 'PUT');
      expect(request.url.path, '/beds/bed-1/assignment');
      expect(jsonDecode(request.body), {'patientId': 'patient-1'});
      return http.Response(
        jsonEncode({
          'bed': {
            '_id': 'bed-1',
            'roomId': 'room-1',
            'number': '1',
            'status': 'occupied',
            'patientId': 'patient-1',
          },
        }),
        200,
      );
    });
    final api = HospitalResourceService(apiClient: ApiClient(client: client));

    final bed = await api.assignBed('bed-1', 'patient-1');

    expect(bed.status, BedStatus.occupied);
    expect(bed.patientId, 'patient-1');
  });

  testWidgets('hospital tab loads hospital and bed occupancy', (tester) async {
    final client = MockClient((request) async {
      final response = switch (request.url.path) {
        '/hospitals' => {
          'hospitals': [
            {
              '_id': 'hospital-1',
              'name': 'Hôpital Démo',
              'address': 'Adresse fictive',
              'phone': '',
              'active': true,
              'serviceIds': [],
            },
          ],
        },
        '/rooms' => {
          'rooms': [
            {
              '_id': 'room-1',
              'hospitalId': 'hospital-1',
              'number': '101',
              'type': 'double',
              'status': 'available',
              'capacity': 2,
            },
          ],
        },
        '/beds' => {
          'beds': [
            {
              '_id': 'bed-1',
              'roomId': 'room-1',
              'number': '1',
              'status': 'free',
            },
            {
              '_id': 'bed-2',
              'roomId': 'room-1',
              'number': '2',
              'status': 'occupied',
            },
          ],
        },
        '/operating-rooms' => {'operatingRooms': []},
        '/equipment' => {'equipment': []},
        '/interventions' => {'interventions': []},
        _ => <String, Object?>{},
      };
      return http.Response(jsonEncode(response), 200);
    });

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: HospitalTab(
            canManage: false,
            isVisible: true,
            hospitalsApi: HospitalResourceService(
              apiClient: ApiClient(client: client),
            ),
            services: const <HospitalService>[],
            users: const <StaffUser>[],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Hôpital Démo'), findsOneWidget);
    expect(find.text('1 / 2'), findsOneWidget);
    expect(find.text('Hôpitaux'), findsOneWidget);
  });
}
