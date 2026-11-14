const User = require('../models/User');
const { HttpError } = require('../errors');
const {
  requireEmail,
  requireObject,
  requirePassword,
  requireDateOnly,
  requireBoolean,
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
    firstName: user.firstName || '',
    lastName: user.lastName || '',
    birthDate: user.birthDate,
    phone: user.phone || '',
    address: user.address || '',
    emergencyContact: user.emergencyContact || '',
    insurance: user.insurance || '',
    language: user.language || 'fr',
    notificationPreferences: user.notificationPreferences || {
      appointments: true,
      results: true,
      reminders: true,
    },
    role: user.role,
    roles: getUserRoles(user),
    serviceId: user.serviceId,
    serviceIds: user.serviceIds?.length
      ? user.serviceIds
      : user.serviceId
        ? [user.serviceId]
        : [],
    specialty: user.specialty || '',
    photoUrl: user.photoUrl || '',
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

function switchRole(req, res) {
  const body = requireObject(req.body);
  rejectUnknownFields(body, ['role']);
  const role = requireRoles([body.role])[0];
  if (!getUserRoles(req.user).includes(role)) {
    throw new HttpError(403, 'This role is not assigned to your account.');
  }
  const config = getConfig();
  return res.json({
    token: createToken(req.user, config, role),
    user: { ...userResponse(req.user), role },
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

async function updateMe(req, res) {
  const body = requireObject(req.body);
  const allowedFields = [
    'firstName', 'lastName', 'email', 'birthDate', 'phone', 'address',
    'emergencyContact', 'insurance', 'language', 'notificationPreferences',
    'currentPassword', 'newPassword',
  ];
  rejectUnknownFields(body, allowedFields);
  const updates = {};

  const profileStringLimits = {
    firstName: 80,
    lastName: 80,
    phone: 40,
    address: 240,
    emergencyContact: 160,
    insurance: 120,
  };
  for (const [field, max] of Object.entries(profileStringLimits)) {
    if (body[field] !== undefined) {
      updates[field] = requireString(body[field], field, { max, min: 0 });
    }
  }
  if (body.email !== undefined) updates.email = requireEmail(body.email);
  if (body.birthDate !== undefined) {
    updates.birthDate = body.birthDate === null || body.birthDate === ''
      ? null
      : requireDateOnly(body.birthDate);
  }
  if (body.language !== undefined) {
    if (!['fr', 'ar'].includes(body.language)) {
      throw new HttpError(400, 'language must be fr or ar.');
    }
    updates.language = body.language;
  }
  if (body.notificationPreferences !== undefined) {
    const preferences = requireObject(body.notificationPreferences, 'notificationPreferences');
    rejectUnknownFields(preferences, ['appointments', 'results', 'reminders']);
    const currentPreferences = req.user.notificationPreferences?.toObject?.() ||
      req.user.notificationPreferences || {};
    updates.notificationPreferences = { ...currentPreferences };
    for (const key of ['appointments', 'results', 'reminders']) {
      if (preferences[key] !== undefined) {
        updates.notificationPreferences[key] = requireBoolean(preferences[key], key);
      }
    }
  }

  if (body.newPassword !== undefined) {
    if (typeof body.currentPassword !== 'string' || body.currentPassword.length === 0) {
      throw new HttpError(400, 'currentPassword is required to change the password.');
    }
    const userWithPassword = await User.findById(req.user._id).select('+passwordHash');
    if (!(await verifyPassword(body.currentPassword, userWithPassword.passwordHash))) {
      throw new HttpError(400, 'Current password is incorrect.');
    }
    updates.passwordHash = await hashPassword(requirePassword(body.newPassword));
  } else if (body.currentPassword !== undefined) {
    throw new HttpError(400, 'newPassword is required with currentPassword.');
  }

  if (updates.firstName !== undefined || updates.lastName !== undefined) {
    const firstName = updates.firstName ?? req.user.firstName ?? '';
    const lastName = updates.lastName ?? req.user.lastName ?? '';
    const username = `${firstName} ${lastName}`.trim();
    if (!username) throw new HttpError(400, 'A first or last name is required.');
    updates.username = username;
  }

  if (!Object.keys(updates).length) {
    throw new HttpError(400, 'At least one profile field must be provided.');
  }

  const user = await User.findByIdAndUpdate(
    req.user._id,
    { $set: updates },
    { new: true, runValidators: true },
  );
  return res.json({ user: userResponse(user) });
}

module.exports = {
  login,
  selectRole,
  switchRole,
  register,
  me,
  updateMe,
  userResponse,
};
