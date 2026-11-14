const User = require('../models/User');
const { HttpError } = require('../errors');
const {
  requireEmail,
  requireObject,
  requirePassword,
  requireRoles,
  requireString,
  rejectUnknownFields,
  getUserRoles,
} = require('../utils/validation');
const {
  createToken,
  createRoleSelectionToken,
  hashPassword,
  verifyPassword,
  verifyToken,
} = require('../services/auth');
const { getConfig } = require('../config');

function userResponse(user) {
  return {
    _id: user._id,
    username: user.username,
    email: user.email,
    role: user.role,
    roles: getUserRoles(user),
    serviceId: user.serviceId,
    active: user.active,
  };
}

async function login(req, res) {
  const body = requireObject(req.body);
  rejectUnknownFields(body, ['email', 'password']);
  const email = requireEmail(body.email);
  if (typeof body.password !== 'string' || body.password.length === 0) {
    throw new HttpError(400, 'password is required.');
  }

  const user = await User.findOne({ email }).select('+passwordHash');
  if (!user || !user.active || !(await verifyPassword(body.password, user.passwordHash))) {
    throw new HttpError(401, 'Invalid email or password.');
  }

  const config = getConfig();
  const roles = getUserRoles(user);
  if (roles.length > 1) {
    return res.json({
      selectionToken: createRoleSelectionToken(user, config),
      user: userResponse(user),
    });
  }
  const role = roles[0] || user.role;
  return res.json({ token: createToken(user, config, role), user: userResponse(user) });
}

async function selectRole(req, res) {
  const body = requireObject(req.body);
  rejectUnknownFields(body, ['selectionToken', 'role']);
  if (typeof body.selectionToken !== 'string' || !body.selectionToken) {
    throw new HttpError(400, 'selectionToken is required.');
  }
  const role = requireRoles([body.role])[0];
  const config = getConfig();
  let payload;
  try {
    payload = verifyToken(body.selectionToken, config);
  } catch {
    throw new HttpError(401, 'Role selection has expired. Please sign in again.');
  }
  if (payload.purpose !== 'role_selection' || !payload.sub) {
    throw new HttpError(401, 'Invalid role selection token.');
  }
  const user = await User.findById(payload.sub);
  if (!user || !user.active) {
    throw new HttpError(401, 'Authentication is no longer valid.');
  }
  if (!getUserRoles(user).includes(role)) {
    throw new HttpError(403, 'This role is not assigned to your account.');
  }
  return res.json({
    token: createToken(user, config, role),
    user: { ...userResponse(user), role },
  });
}

async function register(req, res) {
  const body = requireObject(req.body);
  rejectUnknownFields(body, ['username', 'email', 'password']);

  const user = await User.create({
    username: requireString(body.username, 'username', { max: 120 }),
    email: requireEmail(body.email),
    passwordHash: await hashPassword(requirePassword(body.password)),
    role: 'patient',
    roles: ['patient'],
    active: true,
  });

  const config = getConfig();
  return res.status(201).json({
    token: createToken(user, config),
    user: userResponse(user),
  });
}

function me(req, res) {
  return res.json({ user: userResponse(req.user) });
}

module.exports = { login, selectRole, register, me, userResponse };
