import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hopital_connect/core/network/api_client.dart';
import 'package:hopital_connect/features/hospital/data/hospital_resource_service.dart';
import 'package:hopital_connect/features/hospital/domain/hospital_occupancy.dart';
import 'package:hopital_connect/features/hospital/domain/hospital_resources.dart';
import 'package:hopital_connect/features/hospital/domain/resource_permissions.dart';
import 'package:hopital_connect/features/hospital/presentation/hospital_tab.dart';
import 'package:hopital_connect/features/hospital/presentation/hospital_occupancy_widgets.dart';
import 'package:hopital_connect/features/hospital/presentation/hospital_resource_dialogs.dart';
import 'package:hopital_connect/features/services/domain/hospital_service.dart';
import 'package:hopital_connect/features/users/domain/staff_user.dart';
import 'package:hopital_connect/features/users/domain/staff_role.dart';
import 'package:http/testing.dart';
import 'package:http/http.dart' as http;

void main() {
  test('resource permissions follow each active staff role', () {
    StaffUser user(StaffRole role) => StaffUser(
      id: 'user-$role',
      displayName: role.label,
      email: 'user@example.test',
      role: role,
      hospitalId: 'hospital-1',
      serviceId: 'service-1',
    );

    final admin = user(StaffRole.administrator);
    final serviceManager = user(StaffRole.serviceHead);
    final blockManager = user(StaffRole.operatingRoomManager);
    final nurse = user(StaffRole.nurse);
    final doctor = user(StaffRole.doctor);

    expect(canManageRooms(admin), isTrue);
    expect(canManageOperatingRooms(admin), isTrue);
    expect(canManageRooms(serviceManager), isTrue);
    expect(canManageOperatingRooms(serviceManager), isFalse);
    expect(canManageEquipment(serviceManager), isTrue);
    expect(canManageOperatingRooms(blockManager), isTrue);
    expect(canManageRooms(blockManager), isFalse);
    expect(canManageEquipment(blockManager), isTrue);
    expect(canChangeBedStatus(nurse), isTrue);
    expect(canAssignPatient(nurse), isTrue);
    expect(canManageRooms(nurse), isFalse);
    expect(canChangeBedStatus(doctor), isTrue);
    expect(canAssignPatient(doctor), isFalse);
  });

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
        'number': '2',
        'status': 'occupied',
        'patientId': 'patient-1',
        'assignedAt': '2026-11-14T12:00:00.000Z',
      });

      expect(room.type, RoomType.intensiveCare);
      expect(room.number, 203);
      expect(room.capacity, 4);
      expect(room.toJson()['number'], 203);
      expect(bed.status, BedStatus.occupied);
      expect(bed.number, 2);
      expect(bed.toJson()['number'], 2);
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

    test('operating room JSON contains only fields accepted by the API', () {
      const room = OperatingRoom(
        id: '',
        hospitalId: 'hospital-1',
        name: 'Bloc A',
        number: 1,
        serviceId: 'service-1',
        status: OperatingRoomStatus.free,
      );

      expect(room.toJson(), {
        'hospitalId': 'hospital-1',
        'name': 'Bloc A',
        'number': 1,
        'status': 'free',
        'serviceId': 'service-1',
      });
    });
  });

  test('service occupancy thresholds are exact', () {
    ServiceOccupancy occupancy(int occupied, int total) => ServiceOccupancy(
      service: HospitalService(
        id: '$occupied-$total',
        name: 'Service test',
        location: '',
        description: '',
      ),
      rooms: const [],
      beds: const [],
      summary: BedOccupancySummary(
        occupied: occupied,
        free: total - occupied,
        total: total,
      ),
    );

    expect(occupancy(69, 100).level, OccupancyLevel.normal);
    expect(occupancy(70, 100).level, OccupancyLevel.attention);
    expect(occupancy(90, 100).level, OccupancyLevel.attention);
    expect(occupancy(91, 100).level, OccupancyLevel.saturated);
  });

  testWidgets('room capacity defaults to type and preserves custom values', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RoomDialog(
            hospitals: const [
              Hospital(
                id: 'hospital-1',
                name: 'Hôpital Démo',
                serviceIds: ['service-1'],
              ),
            ],
            services: const [
              HospitalService(
                id: 'service-1',
                name: 'Pédiatrie',
                location: '',
                description: '',
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final fields = find.byType(TextFormField);
    final capacityField = fields.at(2);
    expect(tester.widget<TextFormField>(capacityField).controller!.text, '1');
    expect(tester.widget<TextFormField>(capacityField).enabled, isFalse);

    await tester.tap(find.byType(DropdownButtonFormField<RoomType>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Double').last);
    await tester.pumpAndSettle();
    expect(tester.widget<TextFormField>(capacityField).controller!.text, '2');
    expect(tester.widget<TextFormField>(capacityField).enabled, isFalse);

    await tester.tap(find.byType(DropdownButtonFormField<RoomType>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Soins intensifs').last);
    await tester.pumpAndSettle();
    expect(tester.widget<TextFormField>(capacityField).controller!.text, '1');
    expect(tester.widget<TextFormField>(capacityField).enabled, isTrue);

    await tester.enterText(capacityField, '4');
    expect(tester.widget<TextFormField>(capacityField).controller!.text, '4');

    final firstBedField = fields.last;
    expect(tester.widget<TextFormField>(firstBedField).controller!.text, '1');
  });

  testWidgets('new room dialog returns its required first bed number', (
    tester,
  ) async {
    final navigatorKey = GlobalKey<NavigatorState>();
    RoomDialogResult? result;

    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigatorKey,
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                result = await showDialog<RoomDialogResult>(
                  context: context,
                  builder: (_) => RoomDialog(
                    hospitals: const [
                      Hospital(
                        id: 'hospital-1',
                        name: 'Hôpital principal',
                        serviceIds: ['service-1'],
                      ),
                    ],
                    services: const [
                      HospitalService(
                        id: 'service-1',
                        name: 'Cardiologie',
                        location: '',
                        description: '',
                      ),
                    ],
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

    final roomNumberField = find.byType(TextFormField).first;
    await tester.enterText(roomNumberField, '12');
    await tester.tap(find.text('Enregistrer'));
    await tester.pumpAndSettle();

    expect(result, isNotNull);
    expect(result!.room.number, 12);
    expect(result!.firstBedNumber, 1);
  });

  testWidgets('new room dialog selects the hospital of the scoped service', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RoomDialog(
            hospitals: const [
              Hospital(
                id: 'hospital-1',
                name: 'Hôpital 1',
                serviceIds: ['service-1'],
              ),
              Hospital(
                id: 'hospital-2',
                name: 'Hôpital 2',
                serviceIds: ['service-2'],
              ),
            ],
            services: const [
              HospitalService(
                id: 'service-1',
                name: 'Cardiologie',
                location: '',
                description: '',
              ),
              HospitalService(
                id: 'service-2',
                name: 'Pédiatrie',
                location: '',
                description: '',
              ),
            ],
            initialHospitalId: 'hospital-1',
            initialServiceId: 'service-2',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Hôpital 2'), findsOneWidget);
    expect(find.text('Pédiatrie'), findsOneWidget);
  });

  testWidgets('operating room dialog accepts a suggested next number', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: OperatingRoomDialog(
            initialNumber: 2,
            hospitals: const [
              Hospital(id: 'hospital-1', name: 'Hôpital principal'),
            ],
            services: const <HospitalService>[],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final numberField = find.byType(TextFormField).at(1);
    expect(tester.widget<TextFormField>(numberField).controller!.text, '2');
  });

  testWidgets('creating a room also creates its first bed', (tester) async {
    final createdRequests = <String>[];
    Map<String, dynamic>? createdRoom;
    Map<String, dynamic>? createdBed;
    final client = MockClient((request) async {
      if (request.method == 'POST') {
        createdRequests.add('${request.method} ${request.url.path}');
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        if (request.url.path == '/rooms') {
          createdRoom = {'_id': 'room-1', ...body};
          return http.Response(jsonEncode({'room': createdRoom}), 201);
        }
        if (request.url.path == '/beds') {
          expect(body['roomId'], 'room-1');
          expect(body['number'], 1);
          createdBed = {'_id': 'bed-1', ...body};
          return http.Response(jsonEncode({'bed': createdBed}), 201);
        }
      }

      final response = switch (request.url.path) {
        '/hospitals' => {
          'hospitals': [
            {
              '_id': 'hospital-1',
              'name': 'Hôpital principal',
              'serviceIds': ['service-1'],
            },
          ],
        },
        '/rooms' => {
          'rooms': createdRoom == null ? [] : [createdRoom],
        },
        '/beds' => {
          'beds': createdBed == null ? [] : [createdBed],
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
            canManage: true,
            isVisible: true,
            hospitalsApi: HospitalResourceService(
              apiClient: ApiClient(client: client),
            ),
            services: const [
              HospitalService(
                id: 'service-1',
                name: 'Cardiologie',
                location: '',
                description: '',
              ),
            ],
            users: const <StaffUser>[],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Chambres et lits'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ajouter une chambre'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, '12');
    await tester.tap(find.text('Enregistrer'));
    await tester.pumpAndSettle();

    expect(createdRequests, ['POST /rooms', 'POST /beds']);
    expect(find.text('Chambre 12'), findsOneWidget);
    expect(find.text('Lit 1'), findsOneWidget);
  });

  testWidgets('room cards only allow adding beds within room capacity', (
    tester,
  ) async {
    Widget roomCard(HospitalRoom room, List<HospitalBed> beds) => MaterialApp(
      home: Scaffold(
        body: RoomBedCard(
          room: room,
          hospitalName: 'Hôpital principal',
          serviceName: 'Cardiologie',
          beds: beds,
          displayedBeds: beds,
          canManage: true,
          onAddBed: () {},
          onEditRoom: () {},
          onDeleteRoom: () {},
          onEditBed: (_) {},
          onAssignBed: (_) {},
          onReleaseBed: (_) {},
          onDeleteBed: (_) {},
          userName: (_) => '',
        ),
      ),
    );

    const singleRoom = HospitalRoom(
      id: 'room-1',
      hospitalId: 'hospital-1',
      number: 1,
      floor: '1',
      type: RoomType.single,
      status: RoomStatus.available,
      capacity: 1,
    );
    const singleBed = HospitalBed(
      id: 'bed-1',
      roomId: 'room-1',
      number: 1,
      status: BedStatus.free,
    );
    await tester.pumpWidget(roomCard(singleRoom, const [singleBed]));
    expect(find.text('Cardiologie · Étage 1 · Simple'), findsOneWidget);
    expect(find.text('Ajouter un lit'), findsNothing);
    expect(find.text('Capacité maximale atteinte (1 lit)'), findsOneWidget);

    const intensiveCareRoom = HospitalRoom(
      id: 'room-2',
      hospitalId: 'hospital-1',
      number: 2,
      floor: '1',
      type: RoomType.intensiveCare,
      status: RoomStatus.available,
      capacity: 6,
    );
    const intensiveCareBed = HospitalBed(
      id: 'bed-2',
      roomId: 'room-2',
      number: 1,
      status: BedStatus.free,
    );
    await tester.pumpWidget(
      roomCard(intensiveCareRoom, const [intensiveCareBed]),
    );
    expect(
      find.text('Cardiologie · Étage 1 · Soins intensifs'),
      findsOneWidget,
    );
    expect(find.text('Ajouter un lit'), findsOneWidget);
    expect(find.text('1/6 dispo'), findsOneWidget);
    expect(find.text('Capacité maximale atteinte (6 lits)'), findsNothing);
  });

  testWidgets('resource tabs and actions are scoped to manager roles', (
    tester,
  ) async {
    final service = const HospitalService(
      id: 'service-1',
      name: 'Cardiologie',
      location: '',
      description: '',
      hasOperations: true,
    );
    final client = MockClient((request) async {
      final response = switch (request.url.path) {
        '/hospitals' => {
          'hospitals': [
            {
              '_id': 'hospital-1',
              'name': 'Hôpital principal',
              'serviceIds': ['service-1'],
            },
          ],
        },
        '/rooms' => {'rooms': []},
        '/beds' => {'beds': []},
        '/operating-rooms' => {'operatingRooms': []},
        '/equipment' => {'equipment': []},
        '/interventions' => {'interventions': []},
        _ => <String, Object?>{},
      };
      return http.Response(jsonEncode(response), 200);
    });

    Widget resourcePage(StaffRole role) => MaterialApp(
      home: Scaffold(
        body: HospitalTab(
          key: ValueKey(role),
          canManage: false,
          isVisible: true,
          hospitalsApi: HospitalResourceService(
            apiClient: ApiClient(client: client),
          ),
          services: [service],
          users: const [],
          user: StaffUser(
            id: 'manager-1',
            displayName: 'Responsable',
            email: 'manager@example.test',
            role: role,
            hospitalId: 'hospital-1',
            serviceId: 'service-1',
          ),
        ),
      ),
    );

    await tester.pumpWidget(resourcePage(StaffRole.serviceHead));
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byType(TabBar),
        matching: find.text('Chambres et lits'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byType(TabBar),
        matching: find.text('Bloc opératoire'),
      ),
      findsNothing,
    );
    await tester.tap(find.text('Chambres et lits'));
    await tester.pumpAndSettle();
    expect(find.text('Ajouter une chambre'), findsOneWidget);

    await tester.pumpWidget(resourcePage(StaffRole.operatingRoomManager));
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byType(TabBar),
        matching: find.text('Chambres et lits'),
      ),
      findsNothing,
    );
    expect(
      find.descendant(
        of: find.byType(TabBar),
        matching: find.text('Bloc opératoire'),
      ),
      findsOneWidget,
    );
    await tester.tap(find.text('Bloc opératoire'));
    await tester.pumpAndSettle();
    expect(find.text('Ajouter une salle'), findsOneWidget);
    expect(find.text('Ajouter une chambre'), findsNothing);
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

  test('staff bed status update sends only the status field', () async {
    final client = MockClient((request) async {
      expect(request.method, 'PUT');
      expect(request.url.path, '/beds/bed-1');
      expect(jsonDecode(request.body), {'status': 'cleaning'});
      return http.Response(
        jsonEncode({
          'bed': {
            '_id': 'bed-1',
            'roomId': 'room-1',
            'number': 1,
            'status': 'cleaning',
          },
        }),
        200,
      );
    });

    final updated = await HospitalResourceService(
      apiClient: ApiClient(client: client),
    ).updateBedStatus('bed-1', BedStatus.cleaning);

    expect(updated.status, BedStatus.cleaning);
  });

  testWidgets('hospital tab shows bed occupancy without establishment list', (
    tester,
  ) async {
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
              'serviceId': 'service-1',
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
            services: const [
              HospitalService(
                id: 'service-1',
                name: 'Pédiatrie',
                location: '',
                description: '',
              ),
            ],
            users: const <StaffUser>[],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Établissements'), findsNothing);
    expect(find.text('Ajouter un hôpital'), findsNothing);
    expect(find.text('Aucun hôpital enregistré.'), findsNothing);
    expect(find.text('1 / 2 lits occupés'), findsOneWidget);
    expect(find.text('50%'), findsNWidgets(2));
    expect(find.text('Normal'), findsOneWidget);
    expect(find.text('Lits occupés'), findsOneWidget);
    expect(find.text('Lits libres'), findsOneWidget);
    expect(find.text('Dernière synchro :'), findsNothing);
    expect(find.textContaining('Dernière synchro : '), findsOneWidget);
    expect(find.text('Hôpitaux'), findsOneWidget);
  });

  testWidgets('demo data shows alert and lets staff inspect service beds', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: HospitalTab(
            canManage: false,
            isVisible: true,
            hospitalsApi: HospitalResourceService(),
            services: const <HospitalService>[],
            users: const <StaffUser>[],
            useMockData: true,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('1 service presque saturé'), findsOneWidget);
    expect(find.text('Pédiatrie'), findsOneWidget);
    expect(find.text('Saturé'), findsOneWidget);
    expect(find.text('1 / 2 lits occupés'), findsNothing);

    await tester.tap(find.text('Pédiatrie'));
    await tester.pumpAndSettle();
    expect(find.text('10 occupés · 0 libres · 10 au total'), findsOneWidget);
    expect(find.text('Chambre 101'), findsOneWidget);

    Navigator.of(tester.element(find.text('Chambre 101'))).pop();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Chambres et lits'));
    await tester.pumpAndSettle();
    expect(find.text('Chambre 101'), findsOneWidget);
    expect(find.textContaining('Disponibles'), findsOneWidget);
    expect(find.text('Lits dispo uniquement'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilterChip, 'Lits dispo uniquement'));
    await tester.pumpAndSettle();
    expect(find.text('Chambre 101'), findsNothing);
  });

  testWidgets('room list filters by floor and reserved beds', (tester) async {
    final client = MockClient((request) async {
      final response = switch (request.url.path) {
        '/hospitals' => {
          'hospitals': [
            {
              '_id': 'hospital-1',
              'name': 'Hôpital principal',
              'serviceIds': ['service-1'],
            },
          ],
        },
        '/rooms' => {
          'rooms': [
            {
              '_id': 'room-floor-1',
              'hospitalId': 'hospital-1',
              'serviceId': 'service-1',
              'number': 1,
              'floor': '1',
              'type': 'single',
              'status': 'available',
              'capacity': 1,
            },
            {
              '_id': 'room-floor-2',
              'hospitalId': 'hospital-1',
              'serviceId': 'service-1',
              'number': 1,
              'floor': '2',
              'type': 'double',
              'status': 'available',
              'capacity': 2,
            },
          ],
        },
        '/beds' => {
          'beds': [
            {
              '_id': 'bed-reserved',
              'roomId': 'room-floor-1',
              'number': 1,
              'status': 'reserved',
            },
            {
              '_id': 'bed-free',
              'roomId': 'room-floor-2',
              'number': 1,
              'status': 'free',
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
            services: const [
              HospitalService(
                id: 'service-1',
                name: 'Cardiologie',
                location: '',
                description: '',
              ),
            ],
            users: const <StaffUser>[],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Chambres et lits'));
    await tester.pumpAndSettle();
    expect(find.text('Chambre 1'), findsNWidgets(2));

    await tester.tap(find.text('Tous les étages'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Étage 2').last);
    await tester.pumpAndSettle();
    expect(find.text('Chambre 1'), findsOneWidget);
    expect(find.text('Cardiologie · Étage 2 · Double'), findsOneWidget);

    await tester.tap(find.text('Étage 2'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Étage 1').last);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilterChip, 'Lits réservés'));
    await tester.pumpAndSettle();
    expect(find.text('Chambre 1'), findsOneWidget);
    expect(find.text('Cardiologie · Étage 1 · Simple'), findsOneWidget);
    expect(find.text('Réservé'), findsOneWidget);
    expect(find.text('Disponible'), findsNothing);
  });

  testWidgets('empty and error responses use dedicated states', (tester) async {
    final emptyClient = MockClient((request) async {
      final key = switch (request.url.path) {
        '/hospitals' => 'hospitals',
        '/rooms' => 'rooms',
        '/beds' => 'beds',
        '/operating-rooms' => 'operatingRooms',
        '/equipment' => 'equipment',
        '/interventions' => 'interventions',
        _ => 'items',
      };
      return http.Response(jsonEncode({key: []}), 200);
    });
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: HospitalTab(
            canManage: false,
            isVisible: true,
            hospitalsApi: HospitalResourceService(
              apiClient: ApiClient(client: emptyClient),
            ),
            services: const <HospitalService>[],
            users: const <StaffUser>[],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Aucune donnée de lits disponible'), findsOneWidget);
    expect(find.text('Voir les chambres et lits'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    final errorClient = MockClient(
      (_) async =>
          http.Response(jsonEncode({'message': 'Serveur indisponible'}), 503),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: HospitalTab(
            canManage: false,
            isVisible: true,
            hospitalsApi: HospitalResourceService(
              apiClient: ApiClient(client: errorClient),
            ),
            services: const <HospitalService>[],
            users: const <StaffUser>[],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Serveur indisponible'), findsOneWidget);
    expect(find.text('Réessayer'), findsOneWidget);
  });

  testWidgets('loading state shows skeleton instead of zero occupancy', (
    tester,
  ) async {
    final hospitalsResponse = Completer<http.Response>();
    final client = MockClient((request) async {
      if (request.url.path == '/hospitals') return hospitalsResponse.future;
      final key = switch (request.url.path) {
        '/rooms' => 'rooms',
        '/beds' => 'beds',
        '/operating-rooms' => 'operatingRooms',
        '/equipment' => 'equipment',
        '/interventions' => 'interventions',
        _ => 'items',
      };
      return http.Response(jsonEncode({key: []}), 200);
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
    await tester.pump();

    expect(find.byType(HospitalLoadingSkeleton), findsOneWidget);
    expect(find.textContaining('0 / 0'), findsNothing);

    hospitalsResponse.complete(
      http.Response(jsonEncode({'hospitals': []}), 200),
    );
    await tester.pumpAndSettle();
    expect(find.text('Aucune donnée de lits disponible'), findsOneWidget);
  });

  testWidgets('resource actions fit a narrow screen', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final client = MockClient((request) async {
      final response = switch (request.url.path) {
        '/hospitals' => {
          'hospitals': [
            {
              '_id': 'hospital-1',
              'name': 'Hôpital Démo',
              'active': true,
              'serviceIds': [],
            },
          ],
        },
        '/rooms' => {'rooms': []},
        '/beds' => {'beds': []},
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
            canManage: true,
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
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Chambres et lits'));
    await tester.pumpAndSettle();
    expect(find.text('Ajouter une chambre'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
