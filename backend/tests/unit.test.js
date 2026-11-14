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
const Appointment = require('../src/models/Appointment');
const {
  notificationResponse,
} = require('../src/controllers/notificationsController');
const {
  appointmentResponse,
  generateAvailableSlots,
  STATUS_TRANSITIONS,
} = require('../src/controllers/appointmentsController');
const { getConfig } = require('../src/config');
const {
  requireDateOnly,
  requireDate,
  requireId,
  requirePassword,
  requireRole,
  requireAppointmentStatus,
} = require('../src/utils/validation');
const { createToken, verifyToken } = require('../src/services/auth');

test('validation accepts the API role and date contract', () => {
  assert.equal(requireRole('nurse'), 'nurse');
  assert.equal(requireRole('patient'), 'patient');
  assert.equal(requireRole('secretary'), 'secretary');
  assert.equal(requireAppointmentStatus('in_progress'), 'in_progress');
  assert.throws(() => requireAppointmentStatus('rejected'), HttpError);
  assert.equal(requireDateOnly('2026-02-28').toISOString(), '2026-02-28T00:00:00.000Z');
  assert.equal(requireDate('2026-02-28T09:30:00Z', 'start').toISOString(), '2026-02-28T09:30:00.000Z');
  assert.throws(() => requireDate('next Tuesday', 'start'), HttpError);
  assert.throws(() => requireDateOnly('2026-02-30'), HttpError);
  assert.throws(() => requireRole('administrator'), HttpError);
  assert.throws(() => requireId('not-an-id', 'userId'), HttpError);
  assert.throws(() => requirePassword('short'), HttpError);
  assert.throws(() => requirePassword('é'.repeat(37)), HttpError);
});

test('appointment response exposes patient and secretary fields with allowed status transitions', () => {
  const appointment = appointmentResponse({
    _id: 'appointment-id',
    patientId: { _id: 'patient-id', username: 'Sam' },
    doctorId: { _id: 'doctor-id', username: 'Dr Ada' },
    startAt: new Date('2026-03-01T09:00:00Z'),
    reason: 'Consultation',
    status: 'pending',
  });
  assert.deepEqual(Object.keys(appointment), [
    '_id', 'patientId', 'patientName', 'doctorId', 'doctorName',
    'doctorSpecialty', 'doctorPhotoUrl', 'serviceId', 'serviceName',
    'serviceLocation', 'servicePhone', 'serviceEmail', 'startAt', 'reason',
    'status', 'rejectionReason', 'proposedStartAt', 'proposalNote',
    'claimedBy', 'claimedByName', 'claimedAt', 'createdAt', 'isOverdue',
  ]);
  assert.equal(appointment.patientName, 'Sam');
  assert.deepEqual(STATUS_TRANSITIONS.pending, [
    'accepted', 'rejected', 'proposed', 'cancelled',
  ]);
  assert.deepEqual(STATUS_TRANSITIONS.cancelled, []);
  assert.equal(appointment.isOverdue, false);
});

test('appointment schema supports optional motives and secretary decisions', () => {
  assert.notEqual(Appointment.schema.path('reason').options.required, true);
  assert.deepEqual(Appointment.schema.path('status').enumValues, [
    'pending', 'accepted', 'in_progress', 'proposed', 'rejected', 'cancelled',
  ]);
});

test('user response only includes Flutter contract fields', () => {
  const user = userResponse({
    _id: '507f1f77bcf86cd799439011',
    username: 'Ada',
    email: 'ada@example.test',
    role: 'doctor',
    serviceId: null,
    active: true,
    passwordHash: 'never-return-this',
    bootstrapKey: 'initial-admin',
  });
  assert.deepEqual(Object.keys(user), [
    '_id', 'username', 'email', 'firstName', 'lastName', 'birthDate', 'phone',
    'address', 'emergencyContact', 'insurance', 'language',
    'notificationPreferences', 'role', 'serviceId', 'serviceIds',
    'specialty', 'photoUrl', 'active',
  ]);
  assert.equal(user.username, 'Ada');
  assert.deepEqual(user.serviceIds, []);
});

test('secretary responses include all assigned service identifiers', () => {
  const user = userResponse({
    _id: 'user-id',
    username: 'Secretary',
    email: 'secretary@example.test',
    role: 'secretary',
    serviceId: 'service-one',
    serviceIds: ['service-one', 'service-two'],
    active: true,
  });
  assert.deepEqual(user.serviceIds, ['service-one', 'service-two']);
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
    'openingHours', 'notes',
  ]);
  assert.deepEqual(Object.keys(shift), [
    '_id', 'userId', 'serviceId', 'start', 'end', 'role', 'userName', 'serviceName',
  ]);
  assert.equal(shift.userName, 'Ada');
  assert.equal(shift.serviceName, 'Urgences');
  assert.deepEqual(Object.keys(handover), [
    '_id', 'serviceId', 'authorId', 'authorName', 'title', 'content',
    'important', 'createdAt', 'isRead',
  ]);
  assert.equal(handover.authorName, 'Ada');
  assert.equal(handover.isRead, false);
  assert.equal(handoverResponse({
    _id: 'handover-id',
    serviceId: 'service-id',
    authorId: 'user-id',
    title: 'Equipment',
    content: 'Inventory completed.',
    important: false,
    createdAt: new Date('2026-03-01T06:00:00Z'),
    readBy: ['reader-id'],
  }, 'reader-id').isRead, true);
});

test('availability returns only unbooked future slots inside doctor shifts', () => {
  const dayStart = new Date('2026-03-01T00:00:00.000Z');
  const slots = generateAvailableSlots(
    [{
      start: new Date('2026-03-01T08:00:00.000Z'),
      end: new Date('2026-03-01T10:00:00.000Z'),
    }],
    [
      {
        startAt: new Date('2026-03-01T08:30:00.000Z'),
        status: 'pending',
      },
      {
        startAt: new Date('2026-03-01T08:30:00.000Z'),
        proposedStartAt: new Date('2026-03-01T09:00:00.000Z'),
        status: 'proposed',
      },
    ],
    dayStart,
    { now: new Date('2026-03-01T07:00:00.000Z').getTime() },
  );
  assert.deepEqual(
    slots.map((slot) => slot.toISOString()),
    ['2026-03-01T08:00:00.000Z', '2026-03-01T09:30:00.000Z'],
  );
});

test('notification response exposes persisted in-app appointment updates', () => {
  const notification = notificationResponse({
    _id: 'notification-id',
    appointmentId: 'appointment-id',
    title: 'Rendez-vous confirmé',
    message: 'Votre demande a été confirmée.',
    createdAt: new Date('2026-03-01T08:00:00Z'),
    readAt: null,
  });
  assert.deepEqual(Object.keys(notification), [
    '_id', 'appointmentId', 'title', 'message', 'createdAt', 'readAt',
  ]);
});

test('role middleware denies unauthorized writes and allows configured roles', () => {
  const invoke = (roles, role) => {
    let result;
    authorize(...roles)({ user: { role } }, null, (error) => { result = error; });
    return result;
  };
  assert.equal(invoke(['admin'], 'nurse').status, 403);
  assert.equal(invoke(['admin', 'doctor', 'nurse'], 'nurse'), undefined);
  assert.equal(invoke(['admin', 'doctor', 'nurse'], 'patient').status, 403);
  assert.equal(invoke(['admin', 'secretary'], 'secretary'), undefined);
  assert.equal(invoke(['admin', 'secretary'], 'nurse').status, 403);
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
  const token = createToken({ id: '507f1f77bcf86cd799439011', role: 'admin' }, config);
  const payload = verifyToken(token, config);
  assert.equal(payload.sub, '507f1f77bcf86cd799439011');
  assert.equal(payload.role, 'admin');
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
