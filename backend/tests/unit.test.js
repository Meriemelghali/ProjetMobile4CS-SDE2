const test = require('node:test');
const assert = require('node:assert/strict');
const { once } = require('node:events');
const app = require('../src/app');
const { userResponse } = require('../src/controllers/authController');
const { HttpError } = require('../src/errors');
const { authorize } = require('../src/middleware/authorize');
const { serviceResponse } = require('../src/controllers/servicesController');
const { shiftResponse } = require('../src/controllers/shiftsController');
const { handoverResponse } = require('../src/controllers/handoversController');
const {
  bedResponse,
  occupancyResponse,
  roomResponse,
} = require('../src/controllers/hospitalResourcesController');
const {
  equipmentResponse,
  hasScheduleConflict,
  interventionResponse,
  operatingRoomResponse,
  parseMaintenanceUpdate,
} = require('../src/controllers/operatingResourcesController');
const { getConfig } = require('../src/config');
const {
  requireDateOnly,
  requireDate,
  requireId,
  requirePassword,
  requireRole,
  requireRoles,
  getUserRoles,
} = require('../src/utils/validation');
const {
  createToken,
  createRoleSelectionToken,
  verifyToken,
} = require('../src/services/auth');
const Intervention = require('../src/models/Intervention');
const User = require('../src/models/User');
const Room = require('../src/models/Room');
const Bed = require('../src/models/Bed');
const OperatingRoom = require('../src/models/OperatingRoom');
const Equipment = require('../src/models/Equipment');

test('validation accepts the API role and date contract', () => {
  assert.equal(requireRole('nurse'), 'nurse');
  assert.equal(requireRole('secretary'), 'secretary');
  assert.equal(requireRole('service_head'), 'service_head');
  assert.equal(requireRole('patient'), 'patient');
  assert.deepEqual(requireRoles(['admin', 'service_head']), ['admin', 'service_head']);
  assert.deepEqual(getUserRoles({ role: 'admin', roles: ['admin', 'service_head'] }), [
    'admin',
    'service_head',
  ]);
  assert.deepEqual(getUserRoles({ role: 'secretary' }), ['secretary']);
  assert.throws(() => requireRoles([]), HttpError);
  assert.throws(() => requireRoles(['admin', 'admin']), HttpError);
  assert.equal(requireDateOnly('2026-02-28').toISOString(), '2026-02-28T00:00:00.000Z');
  assert.equal(requireDate('2026-02-28T09:30:00Z', 'start').toISOString(), '2026-02-28T09:30:00.000Z');
  assert.throws(() => requireDate('next Tuesday', 'start'), HttpError);
  assert.throws(() => requireDateOnly('2026-02-30'), HttpError);
  assert.throws(() => requireRole('administrator'), HttpError);
  assert.throws(() => requireId('not-an-id', 'userId'), HttpError);
  assert.throws(() => requirePassword('short'), HttpError);
  assert.throws(() => requirePassword('é'.repeat(37)), HttpError);
});

test('user response only includes Flutter contract fields', () => {
  const user = userResponse({
    _id: '507f1f77bcf86cd799439011',
    username: 'Ada',
    email: 'ada@example.test',
    role: 'doctor',
    roles: ['doctor', 'service_head'],
    serviceId: null,
    active: true,
    passwordHash: 'never-return-this',
    bootstrapKey: 'initial-admin',
  });
  assert.deepEqual(Object.keys(user), [
    '_id', 'username', 'email', 'role', 'roles', 'serviceId', 'active',
  ]);
  assert.deepEqual(user.roles, ['doctor', 'service_head']);
  assert.equal(user.username, 'Ada');
});

test('resource serializers expose the documented Flutter fields', () => {
  const service = serviceResponse({
    _id: 'service-id',
    name: 'Emergency',
    location: 'North wing',
    description: 'Emergency unit',
    active: true,
  });
  const shift = shiftResponse({
    _id: 'shift-id',
    userId: { _id: 'user-id', username: 'Ada' },
    serviceId: { _id: 'service-id', name: 'Urgences' },
    start: new Date('2026-03-01T07:00:00Z'),
    end: new Date('2026-03-01T15:00:00Z'),
    role: 'nurse',
  });
  const handover = handoverResponse({
    _id: 'handover-id',
    serviceId: 'service-id',
    authorId: { _id: 'user-id', username: 'Ada' },
    title: 'Equipment',
    content: 'Inventory completed.',
    important: false,
    createdAt: new Date('2026-03-01T06:00:00Z'),
  });
  assert.deepEqual(Object.keys(service), [
    '_id', 'name', 'location', 'description', 'active', 'serviceType',
    'building', 'floor', 'capacity', 'phone', 'email', 'headName',
    'headUserId', 'openingHours', 'notes',
  ]);
  assert.deepEqual(Object.keys(shift), [
    '_id', 'userId', 'serviceId', 'start', 'end', 'role', 'userName', 'serviceName',
  ]);
  assert.equal(shift.userName, 'Ada');
  assert.equal(shift.serviceName, 'Urgences');
  assert.deepEqual(Object.keys(handover), [
    '_id', 'serviceId', 'authorId', 'authorName', 'title', 'content', 'important', 'createdAt',
  ]);
  assert.equal(handover.authorName, 'Ada');
});

test('hospital resource serializers expose occupancy and avoid patient details', () => {
  const room = {
    _id: 'room-id',
    hospitalId: 'hospital-id',
    serviceId: 'service-id',
    number: 12,
    floor: '2',
    type: 'double',
    status: 'available',
    capacity: 4,
  };
  assert.deepEqual(roomResponse(room, occupancyResponse(room, 2)), {
    _id: 'room-id',
    hospitalId: 'hospital-id',
    serviceId: 'service-id',
    number: 12,
    floor: '2',
    type: 'double',
    status: 'available',
    capacity: 4,
    occupancy: {
      roomId: 'room-id',
      capacity: 4,
      occupiedBeds: 2,
      availableBeds: 2,
    },
  });
  const bed = bedResponse({
    _id: 'bed-id',
    roomId: 'room-id',
    number: 1,
    status: 'occupied',
    patientId: 'synthetic-patient-id',
    assignedAt: new Date('2026-03-01T06:00:00Z'),
  });
  assert.deepEqual(Object.keys(bed), ['_id', 'roomId', 'number', 'status', 'patientId', 'assignedAt']);
  assert.equal(Object.hasOwn(bed, 'patientName'), false);
});

test('operating room schedule conflict checks use strict interval overlap', () => {
  const schedule = [{
    interventionId: 'existing',
    start: new Date('2026-03-01T09:00:00Z'),
    end: new Date('2026-03-01T10:00:00Z'),
    status: 'scheduled',
  }];
  assert.equal(hasScheduleConflict(schedule, new Date('2026-03-01T09:30:00Z'), new Date('2026-03-01T10:30:00Z')), true);
  assert.equal(hasScheduleConflict(schedule, new Date('2026-03-01T10:00:00Z'), new Date('2026-03-01T11:00:00Z')), false);
  assert.equal(hasScheduleConflict(schedule, new Date('2026-03-01T09:30:00Z'), new Date('2026-03-01T10:30:00Z'), 'existing'), false);
  assert.equal(hasScheduleConflict([{ ...schedule[0], status: 'cancelled' }], new Date('2026-03-01T09:30:00Z'), new Date('2026-03-01T10:30:00Z')), false);
});

test('intervention links expose IDs only and require doctor/patient user references', () => {
  const intervention = interventionResponse({
    _id: 'intervention-id',
    surgeonId: 'doctor-user-id',
    patientId: 'patient-user-id',
    operatingRoomId: { _id: 'or-id', name: 'OR 1' },
    equipmentIds: ['equipment-id'],
    title: 'Routine procedure',
    start: new Date('2026-03-01T09:00:00Z'),
    end: new Date('2026-03-01T10:00:00Z'),
    status: 'scheduled',
  });
  assert.deepEqual(Object.keys(intervention), [
    '_id', 'surgeonId', 'patientId', 'operatingRoomId', 'operatingRoomName',
    'equipmentIds', 'title', 'start', 'end', 'status',
  ]);
  assert.equal(intervention.surgeonId, 'doctor-user-id');
  assert.equal(intervention.patientId, 'patient-user-id');
  assert.equal(Intervention.schema.path('surgeonId').options.ref, 'User');
  assert.equal(Intervention.schema.path('surgeonId').isRequired, true);
  assert.equal(Intervention.schema.path('patientId').options.ref, 'User');
  assert.equal(Intervention.schema.path('patientId').isRequired, true);

  const equipment = equipmentResponse({
    _id: 'equipment-id',
    hospitalId: 'hospital-id',
    serviceId: 'service-id',
    operatingRoomId: null,
    name: 'Monitor',
    type: 'patient_monitor',
    serialNumber: 'SERIAL-1',
    status: 'functional',
    lastMaintenanceAt: new Date('2026-02-01T00:00:00Z'),
    maintenanceDueAt: new Date('2027-02-01T00:00:00Z'),
  });
  assert.deepEqual(Object.keys(equipment), [
    '_id', 'hospitalId', 'serviceId', 'operatingRoomId', 'name', 'type',
    'serialNumber', 'status', 'lastMaintenanceAt', 'maintenanceDueAt',
  ]);
  assert.equal(equipment.status, 'functional');
  assert.equal(equipmentResponse({
    _id: 'equipment-id',
    hospitalId: 'hospital-id',
    serviceId: 'service-id',
    name: 'Monitor',
    type: 'patient_monitor',
    serialNumber: 'SERIAL-1',
    status: 'functional',
  }).maintenanceDueAt, null);
  assert.deepEqual(Object.keys(operatingRoomResponse({
    _id: 'or-id',
    hospitalId: 'hospital-id',
    serviceId: null,
    name: 'OR 1',
    number: 1,
    status: 'free',
    schedule: [{ status: 'scheduled' }, { status: 'completed' }],
  })), ['_id', 'hospitalId', 'serviceId', 'name', 'number', 'status', 'scheduledCount']);
});

test('resource schemas enforce the requested room, bed, OR, equipment, and intervention enums', () => {
  assert.deepEqual(Room.schema.path('type').enumValues, ['single', 'double', 'intensive_care']);
  assert.deepEqual(Room.schema.path('status').enumValues, ['available', 'full', 'maintenance']);
  assert.deepEqual(Bed.schema.path('status').enumValues, ['free', 'occupied', 'reserved', 'cleaning']);
  assert.deepEqual(OperatingRoom.schema.path('status').enumValues, ['free', 'in_progress', 'sterilization']);
  assert.deepEqual(Equipment.schema.path('status').enumValues, ['functional', 'broken', 'maintenance']);
  assert.ok(Intervention.schema.path('equipmentIds'));
});

test('maintenance update accepts both dates and changes status only when requested', () => {
  const update = parseMaintenanceUpdate({
    lastMaintenanceAt: '2026-10-01T10:00:00Z',
    maintenanceDueAt: '2027-10-01T10:00:00Z',
  });
  assert.deepEqual(update, {
    $set: {
      lastMaintenanceAt: new Date('2026-10-01T10:00:00Z'),
      maintenanceDueAt: new Date('2027-10-01T10:00:00Z'),
    },
    $unset: {},
  });
  assert.deepEqual(parseMaintenanceUpdate({ status: 'functional' }), {
    $set: { status: 'functional' },
    $unset: {},
  });
  assert.deepEqual(parseMaintenanceUpdate({ maintenanceDueAt: null }), {
    $set: {},
    $unset: { maintenanceDueAt: 1 },
  });
  assert.throws(() => parseMaintenanceUpdate({}), HttpError);
});

test('beds and equipment enforce assignment-state invariants without exposing extra data', async () => {
  const invalidOccupiedBed = new Bed({
    roomId: '507f1f77bcf86cd799439011',
    number: 1,
    status: 'occupied',
  });
  await assert.rejects(
    invalidOccupiedBed.validate(),
    (error) => Boolean(error.errors.patientId),
  );

  const invalidEquipmentAssignment = new Equipment({
    serviceId: '507f1f77bcf86cd799439011',
    operatingRoomId: '507f1f77bcf86cd799439012',
    name: 'Synthetic unit',
    type: 'test',
    serialNumber: 'SYNTHETIC-1',
  });
  await assert.rejects(
    invalidEquipmentAssignment.validate(),
    (error) => Boolean(error.errors.serviceId),
  );
});

test('role middleware denies non-admin writes and allows handover roles', () => {
  const invoke = (roles, role) => {
    let result;
    authorize(...roles)({ user: { role } }, null, (error) => { result = error; });
    return result;
  };
  assert.equal(invoke(['admin'], 'nurse').status, 403);
  assert.equal(invoke(['admin', 'doctor', 'nurse'], 'nurse'), undefined);
  assert.equal(invoke(['admin', 'doctor', 'nurse'], 'patient').status, 403);
  assert.equal(invoke(['admin', 'doctor', 'nurse', 'service_head'], 'service_head'), undefined);
});

test('user schema accepts the service head role', async () => {
  const user = new User({
    username: 'Service Head',
    email: 'head@example.test',
    passwordHash: 'synthetic-hash',
    role: 'service_head',
  });
  await user.validate();
});

test('user schema stores multiple assigned roles', async () => {
  const user = new User({
    username: 'Meriem',
    email: 'meriem@example.test',
    passwordHash: 'synthetic-hash',
    role: 'admin',
    roles: ['admin', 'service_head', 'patient'],
  });
  await user.validate();
  assert.deepEqual(getUserRoles(user), ['admin', 'service_head', 'patient']);
});

test('user schema accepts the secretary role already used by existing accounts', async () => {
  const user = new User({
    username: 'Secretary',
    email: 'secretary@example.test',
    passwordHash: 'synthetic-hash',
    role: 'secretary',
  });
  await user.validate();
});

test('public registration rejects attempts to choose a privileged role', async (t) => {
  const server = app.listen(0);
  await once(server, 'listening');
  t.after(() => server.close());

  const response = await fetch(`http://127.0.0.1:${server.address().port}/auth/register`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      username: 'Patient',
      email: 'patient@example.test',
      password: 'a-strong-password',
      role: 'admin',
    }),
  });
  assert.equal(response.status, 400);
  assert.match((await response.json()).error.message, /Unsupported field/);
});

test('JWT tokens are signed and scoped to the API', () => {
  const config = { jwtSecret: 'test-secret-with-more-than-thirty-two-characters', jwtExpiresIn: '8h' };
  const account = { id: '507f1f77bcf86cd799439011', role: 'admin' };
  const token = createToken(account, config, 'service_head');
  const payload = verifyToken(token, config);
  assert.equal(payload.sub, '507f1f77bcf86cd799439011');
  assert.equal(payload.role, 'service_head');
  assert.equal(payload.tokenType, 'access');
  const selectionPayload = verifyToken(createRoleSelectionToken(account, config), config);
  assert.equal(selectionPayload.purpose, 'role_selection');
  assert.throws(() => verifyToken(token, { ...config, jwtSecret: 'a-different-secret-with-more-than-32-chars' }));
});

test('configuration rejects the checked-in JWT placeholder', () => {
  const previousSecret = process.env.JWT_SECRET;
  process.env.JWT_SECRET = 'replace-with-a-random-secret-at-least-32-characters';
  try {
    assert.throws(() => getConfig(), /JWT_SECRET/);
  } finally {
    if (previousSecret === undefined) delete process.env.JWT_SECRET;
    else process.env.JWT_SECRET = previousSecret;
  }
});

test('health endpoint responds without requiring a database', async (t) => {
  const server = app.listen(0);
  await once(server, 'listening');
  t.after(() => server.close());

  const response = await fetch(`http://127.0.0.1:${server.address().port}/health`);
  assert.equal(response.status, 200);
  assert.deepEqual(await response.json(), { status: 'ok' });
});

test('protected endpoints reject requests without bearer authentication', async (t) => {
  const server = app.listen(0);
  await once(server, 'listening');
  t.after(() => server.close());

  const response = await fetch(`http://127.0.0.1:${server.address().port}/users`);
  assert.equal(response.status, 401);
  assert.deepEqual(await response.json(), { error: { message: 'A bearer token is required.' } });
});

test('hospital resource endpoints require bearer authentication', async (t) => {
  const server = app.listen(0);
  await once(server, 'listening');
  t.after(() => server.close());

  for (const path of [
    '/hospitals', '/rooms', '/beds', '/operating-rooms', '/interventions', '/equipment',
  ]) {
    const response = await fetch(`http://127.0.0.1:${server.address().port}${path}`);
    assert.equal(response.status, 401, path);
  }
});
