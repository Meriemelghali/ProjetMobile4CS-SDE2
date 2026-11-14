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

const CREATE_FIELDS = [
  'username', 'email', 'password', 'role', 'serviceId', 'serviceIds',
  'specialty', 'photoUrl', 'active',
];
const UPDATE_FIELDS = CREATE_FIELDS;

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
  if (creating || body.serviceIds !== undefined) {
    if (body.serviceIds !== undefined && !Array.isArray(body.serviceIds)) {
      throw new HttpError(400, 'serviceIds must be an array.');
    }
    const values = body.serviceIds || [];
    if (values.length > 50) throw new HttpError(400, 'serviceIds cannot contain more than 50 services.');
    result.serviceIds = [...new Set(values.map((value) => requireId(value, 'serviceIds item')))];
  }
  if (creating || body.specialty !== undefined) {
    result.specialty = body.specialty === undefined
      ? ''
      : requireString(body.specialty, 'specialty', { max: 120, min: 0 });
  }
  if (creating || body.photoUrl !== undefined) {
    result.photoUrl = body.photoUrl === undefined
      ? ''
      : requireString(body.photoUrl, 'photoUrl', { max: 500, min: 0 });
  }
  if (creating || body.active !== undefined) {
    result.active = body.active === undefined ? true : requireBoolean(body.active, 'active');
  }
  return result;
}

async function validateServiceIds(serviceIds) {
  if (!serviceIds.length) return [];
  const count = await Service.countDocuments({ _id: { $in: serviceIds } });
  if (count !== serviceIds.length) throw new HttpError(400, 'One or more serviceIds do not exist.');
  return serviceIds;
}

async function list(_req, res) {
  const users = await User.find().sort({ username: 1 }).limit(200);
  return res.json({ users: users.map(userResponse) });
}

async function listServiceMembers(req, res) {
  const serviceId = requireId(req.params.serviceId, 'serviceId');
  if (req.user.role !== 'admin' &&
      serviceId !== req.user.serviceId?.toString()) {
    throw new HttpError(403, 'You can only view members of your service.');
  }
  if (!(await Service.exists({ _id: serviceId }))) {
    throw new HttpError(404, 'Service not found.');
  }
  const users = await User.find({
    serviceId,
    _id: { $ne: req.user._id },
    role: { $in: ['doctor', 'nurse', 'secretary'] },
    active: true,
  })
    .select('username role specialty')
    .sort({ username: 1 })
    .limit(200);
  return res.json({
    users: users.map((user) => ({
      _id: user._id,
      username: user.username,
      role: user.role,
      specialty: user.specialty,
    })),
  });
}

async function create(req, res) {
  const body = requireObject(req.body);
  rejectUnknownFields(body, CREATE_FIELDS);
  const fields = parseUserFields(body, { creating: true });
  fields.serviceId = await validateService(fields.serviceId);
  fields.serviceIds = await validateServiceIds(fields.serviceIds);
  if (fields.role === 'secretary') {
    fields.serviceIds = body.serviceIds === undefined && fields.serviceId
      ? [fields.serviceId]
      : fields.serviceIds;
    if (!fields.serviceIds.length) {
      throw new HttpError(400, 'A secretary must be assigned to at least one service.');
    }
    fields.serviceId = fields.serviceIds[0] || null;
  } else if (fields.serviceIds.length) {
    throw new HttpError(400, 'serviceIds can only be assigned to secretaries.');
  }
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
  if (fields.serviceIds !== undefined) fields.serviceIds = await validateServiceIds(fields.serviceIds);
  if (fields.password !== undefined) {
    fields.passwordHash = await hashPassword(fields.password);
    delete fields.password;
  }

  const currentUser = await User.findById(id);
  if (!currentUser) throw new HttpError(404, 'User not found.');
  const role = fields.role || currentUser.role;
  if (role === 'secretary') {
    if (fields.serviceIds !== undefined) {
      fields.serviceId = fields.serviceIds[0] || null;
    } else if (fields.serviceId !== undefined) {
      fields.serviceIds = fields.serviceId ? [fields.serviceId] : [];
    } else if (fields.role === 'secretary' && currentUser.role !== 'secretary') {
      fields.serviceIds = currentUser.serviceId ? [currentUser.serviceId] : [];
      fields.serviceId = fields.serviceIds[0] || null;
    }
    const assignedServiceIds = fields.serviceIds !== undefined
      ? fields.serviceIds
      : currentUser.serviceIds?.length
        ? currentUser.serviceIds
        : currentUser.serviceId
          ? [currentUser.serviceId]
          : [];
    if ((fields.role === 'secretary' ||
         fields.serviceIds !== undefined ||
         fields.serviceId !== undefined) &&
        !assignedServiceIds.length) {
      throw new HttpError(400, 'A secretary must be assigned to at least one service.');
    }
  } else if (fields.serviceIds?.length) {
    throw new HttpError(400, 'serviceIds can only be assigned to secretaries.');
  } else if (fields.role && currentUser.role === 'secretary') {
    fields.serviceIds = [];
  }
  const user = await User.findByIdAndUpdate(id, { $set: fields }, {
    new: true,
    runValidators: true,
  });
  if (!user) throw new HttpError(404, 'User not found.');
  return res.json({ user: userResponse(user) });
}

module.exports = { list, listServiceMembers, create, update };
