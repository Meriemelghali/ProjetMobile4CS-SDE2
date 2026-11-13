const User = require('../models/User');
const Service = require('../models/Service');
const { HttpError } = require('../errors');
const { hashPassword } = require('../services/auth');
const { userResponse } = require('./authController');
const {
  requireBoolean,
  requireEmail,
  requireId,
  requireObject,
  requirePassword,
  requireRole,
  requireString,
  rejectUnknownFields,
} = require('../utils/validation');

const CREATE_FIELDS = ['username', 'email', 'password', 'role', 'serviceId', 'active'];
const UPDATE_FIELDS = ['username', 'email', 'password', 'role', 'serviceId', 'active'];

async function validateService(serviceId) {
  if (serviceId === null) return null;
  const id = requireId(serviceId, 'serviceId');
  if (!(await Service.exists({ _id: id }))) throw new HttpError(400, 'serviceId does not exist.');
  return id;
}

function parseUserFields(body, { creating = false } = {}) {
  const result = {};
  if (creating || body.username !== undefined) {
    result.username = requireString(body.username, 'username', { max: 120 });
  }
  if (creating || body.email !== undefined) result.email = requireEmail(body.email);
  if (creating || body.password !== undefined) result.password = requirePassword(body.password);
  if (creating || body.role !== undefined) result.role = requireRole(body.role);
  if (creating || body.serviceId !== undefined) result.serviceId = body.serviceId ?? null;
  if (creating || body.active !== undefined) {
    result.active = body.active === undefined ? true : requireBoolean(body.active, 'active');
  }
  return result;
}

async function list(_req, res) {
  const users = await User.find().sort({ username: 1 }).limit(200);
  return res.json({ users: users.map(userResponse) });
}

async function create(req, res) {
  const body = requireObject(req.body);
  rejectUnknownFields(body, CREATE_FIELDS);
  const fields = parseUserFields(body, { creating: true });
  fields.serviceId = await validateService(fields.serviceId);
  fields.passwordHash = await hashPassword(fields.password);
  delete fields.password;
  const user = await User.create(fields);
  return res.status(201).json({ user: userResponse(user) });
}

async function update(req, res) {
  const id = requireId(req.params.id, 'user id');
  const body = requireObject(req.body);
  rejectUnknownFields(body, UPDATE_FIELDS);
  const fields = parseUserFields(body);
  if (!Object.keys(fields).length) throw new HttpError(400, 'At least one field must be provided.');
  if (fields.serviceId !== undefined) fields.serviceId = await validateService(fields.serviceId);
  if (fields.password !== undefined) {
    fields.passwordHash = await hashPassword(fields.password);
    delete fields.password;
  }

  const user = await User.findByIdAndUpdate(id, { $set: fields }, {
    new: true,
    runValidators: true,
  });
  if (!user) throw new HttpError(404, 'User not found.');
  return res.json({ user: userResponse(user) });
}

module.exports = { list, create, update };
