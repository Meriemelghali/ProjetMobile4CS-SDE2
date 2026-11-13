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
const { getConfig } = require('../src/config');
const {
  requireDateOnly,
  requireDate,
  requireId,
  requirePassword,
  requireRole,
} = require('../src/utils/validation');
const { createToken, verifyToken } = require('../src/services/auth');

test('validation accepts the API role and date contract', () => {
  assert.equal(requireRole('nurse'), 'nurse');
  assert.equal(requireRole('patient'), 'patient');
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
    serviceId: null,
    active: true,
    passwordHash: 'never-return-this',
    bootstrapKey: 'initial-admin',
  });
  assert.deepEqual(Object.keys(user), ['_id', 'username', 'email', 'role', 'serviceId', 'active']);
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
  assert.deepEqual(Object.keys(service), ['_id', 'name', 'location', 'description', 'active']);
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

test('role middleware denies non-admin writes and allows handover roles', () => {
  const invoke = (roles, role) => {
    let result;
    authorize(...roles)({ user: { role } }, null, (error) => { result = error; });
    return result;
  };
  assert.equal(invoke(['admin'], 'nurse').status, 403);
  assert.equal(invoke(['admin', 'doctor', 'nurse'], 'nurse'), undefined);
  assert.equal(invoke(['admin', 'doctor', 'nurse'], 'patient').status, 403);
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
