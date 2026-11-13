const User = require('../models/User');
const { HttpError } = require('../errors');
const {
  requireEmail,
  requireObject,
  requirePassword,
  requireString,
  rejectUnknownFields,
} = require('../utils/validation');
const { createToken, hashPassword, verifyPassword } = require('../services/auth');
const { getConfig } = require('../config');

function userResponse(user) {
  return {
    _id: user._id,
    username: user.username,
    email: user.email,
    role: user.role,
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
  return res.json({ token: createToken(user, config), user: userResponse(user) });
}

async function register(req, res) {
  const body = requireObject(req.body);
  rejectUnknownFields(body, ['username', 'email', 'password']);

  const user = await User.create({
    username: requireString(body.username, 'username', { max: 120 }),
    email: requireEmail(body.email),
    passwordHash: await hashPassword(requirePassword(body.password)),
    role: 'patient',
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

module.exports = { login, register, me, userResponse };
