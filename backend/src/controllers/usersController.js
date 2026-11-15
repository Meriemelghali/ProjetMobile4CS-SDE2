const User = require('../models/User');
const Service = require('../models/Service');
const Hospital = require('../models/Hospital');
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
  requireRoles,
  requireString,
  rejectUnknownFields,
} = require('../utils/validation');

const CREATE_FIELDS = [
  'username', 'email', 'password', 'role', 'roles', 'serviceId', 'serviceIds',
  'hospitalId',
  'pharmacyId',
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
  if (creating || body.role !== undefined || body.roles !== undefined) {
    const roles = body.roles === undefined
      ? [requireRole(body.role)]
      : requireRoles(body.roles);
    const primaryRole = body.role === undefined
      ? roles[0]
      : requireRole(body.role);
    if (!roles.includes(primaryRole)) {
      throw new HttpError(400, 'role must be included in roles.');
    }
    result.roles = roles;
    result.role = primaryRole;
  }
  if (creating || body.serviceId !== undefined) result.serviceId = body.serviceId ?? null;
  if (creating || body.pharmacyId !== undefined) result.pharmacyId = body.pharmacyId ?? null;
  if (creating || body.serviceIds !== undefined) {
    if (body.serviceIds !== undefined && !Array.isArray(body.serviceIds)) {
      throw new HttpError(400, 'serviceIds must be an array.');
    }
    if (creating || body.hospitalId !== undefined) {
      result.hospitalId = body.hospitalId ?? null;
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

async function validateHospital(hospitalId) {
  if (hospitalId === null) return null;
  const id = requireId(hospitalId, 'hospitalId');
  if (!(await Hospital.exists({ _id: id }))) {
    throw new HttpError(400, 'hospitalId does not exist.');
  }
  return id;
}

async function validatePharmacy(pharmacyId) {
  if (pharmacyId === null) return null;
  const id = requireId(pharmacyId, 'pharmacyId');
  const Pharmacy = require('../models/Pharmacy');
  if (!(await Pharmacy.exists({ _id: id }))) throw new HttpError(400, 'pharmacyId does not exist.');
  return id;
}

async function validateResourceAssignments(fields, roles) {
  fields.hospitalId = await validateHospital(fields.hospitalId);
  fields.pharmacyId = await validatePharmacy(fields.pharmacyId ?? null);
  const hasServiceManager = roles.includes('service_head');
  const hasBlockManager = roles.includes('operating_room_manager');
  if (hasServiceManager && (!fields.serviceId || !fields.hospitalId)) {
    throw new HttpError(400, 'A service manager must be assigned to a hospital and service.');
  }
  if (roles.includes('pharmacist') && !fields.pharmacyId) {
    throw new HttpError(400, 'A pharmacist must be assigned to a pharmacy.');
  }
  if (hasBlockManager && !fields.hospitalId) {
    throw new HttpError(400, 'An operating room manager must be assigned to a hospital.');
  }
  if (hasServiceManager &&
      !(await Hospital.exists({
        _id: fields.hospitalId,
        serviceIds: fields.serviceId,
      }))) {
    throw new HttpError(400, 'serviceId must belong to hospitalId.');
  }
  if (fields.hospitalId && fields.serviceId &&
      !(await Hospital.exists({
        _id: fields.hospitalId,
        serviceIds: fields.serviceId,
      }))) {
    throw new HttpError(400, 'serviceId must belong to hospitalId.');
  }
}

async function list(_req, res) {
  const users = await User.find().sort({ username: 1 }).limit(200);
  return res.json({ users: users.map(userResponse) });
}

async function listAssignablePatients(_req, res) {
  const patients = await User.find({ role: 'patient', active: true })
    .select('username role active')
    .sort({ username: 1 })
    .limit(500);
  return res.json({
    users: patients.map((user) => ({
      _id: user._id,
      username: user.username,
      role: user.role,
      active: user.active,
    })),
  });
}

async function listInterventionParticipants(req, res) {
  const serviceIds = [
    ...(req.user.serviceIds || []).map((id) => id.toString()),
    ...(req.user.serviceId ? [req.user.serviceId.toString()] : []),
  ];
  const doctorQuery = req.user.role === 'doctor'
    ? { _id: req.user._id }
    : req.user.role === 'secretary'
    ? {
        $or: [
          { serviceId: { $in: serviceIds } },
          { serviceIds: { $in: serviceIds } },
        ],
      }
    : {};
  const users = await User.find({
    active: true,
    $or: [
      {
        $and: [
          doctorQuery,
          { $or: [{ role: 'doctor' }, { roles: 'doctor' }] },
        ],
      },
      { role: 'patient' },
    ],
  }).sort({ username: 1 }).limit(500);
  return res.json({ users: users.map(userResponse) });
}

async function listServiceMembers(req, res) {
  const serviceId = requireId(req.params.serviceId, 'serviceId');
  const assignedServiceIds = [
    ...(req.user.serviceIds || []).map((id) => id.toString()),
    ...(req.user.serviceId ? [req.user.serviceId.toString()] : []),
  ];
  if (req.user.role !== 'admin' &&
      !assignedServiceIds.includes(serviceId)) {
    throw new HttpError(403, 'You can only view members of your service.');
  }
  if (!(await Service.exists({ _id: serviceId }))) {
    throw new HttpError(404, 'Service not found.');
  }
  const users = await User.find({
    _id: { $ne: req.user._id },
    active: true,
    $or: [
      {
        serviceId,
        $or: [
          { role: { $in: ['doctor', 'nurse', 'secretary'] } },
          { roles: { $in: ['doctor', 'nurse', 'secretary'] } },
        ],
      },
      {
        serviceIds: serviceId,
        $or: [
          { role: { $in: ['doctor', 'nurse', 'secretary'] } },
          { roles: { $in: ['doctor', 'nurse', 'secretary'] } },
        ],
      },
    ],
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
  fields.pharmacyId = await validatePharmacy(fields.pharmacyId);
  fields.serviceIds = await validateServiceIds(fields.serviceIds);
  await validateResourceAssignments(fields, fields.roles);
  const hasServiceRole = fields.roles.includes('secretary') ||
    fields.roles.includes('doctor');
  if (hasServiceRole) {
    fields.serviceIds = body.serviceIds === undefined && fields.serviceId
      ? [fields.serviceId]
      : fields.serviceIds;
    if (fields.roles.includes('secretary') && !fields.serviceIds.length) {
      throw new HttpError(400, 'A secretary must be assigned to at least one service.');
    }
    if (['secretary', 'doctor'].includes(fields.role)) {
      fields.serviceId = fields.serviceIds[0] || null;
    }
  } else if (fields.serviceIds.length) {
    throw new HttpError(400, 'serviceIds can only be assigned to doctors or secretaries.');
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
  const assignedRoles = fields.roles ||
      (currentUser.roles?.length
          ? currentUser.roles
          : [fields.role || currentUser.role]);
  const assignmentFields = {
    hospitalId: fields.hospitalId === undefined
      ? currentUser.hospitalId || null
      : fields.hospitalId,
    serviceId: fields.serviceId === undefined
      ? currentUser.serviceId || null
      : fields.serviceId,
    pharmacyId: fields.pharmacyId === undefined
      ? currentUser.pharmacyId || null
      : fields.pharmacyId,
  };
  if (assignedRoles.includes('service_head') &&
      !assignmentFields.hospitalId &&
      assignmentFields.serviceId) {
    const hospitals = await Hospital.find({
      serviceIds: assignmentFields.serviceId,
    }).select('_id').limit(2);
    if (hospitals.length === 1) assignmentFields.hospitalId = hospitals[0]._id;
  }
  await validateResourceAssignments(assignmentFields, assignedRoles);
  if (assignedRoles.includes('pharmacist') && !assignmentFields.pharmacyId) {
    throw new HttpError(400, 'A pharmacist must be assigned to a pharmacy.');
  }
  if (fields.pharmacyId !== undefined || assignedRoles.includes('pharmacist')) {
    fields.pharmacyId = assignmentFields.pharmacyId;
  }
  if (fields.hospitalId !== undefined || assignedRoles.includes('service_head') ||
      assignedRoles.includes('operating_room_manager')) {
    fields.hospitalId = assignmentFields.hospitalId;
  }
  const hasServiceRole = assignedRoles.includes('secretary') ||
    assignedRoles.includes('doctor') ||
    assignedRoles.includes('service_head');
  if (hasServiceRole) {
    if (fields.serviceIds === undefined &&
        fields.serviceId !== undefined &&
        ['secretary', 'doctor'].includes(fields.role)) {
      fields.serviceIds = fields.serviceId ? [fields.serviceId] : [];
    } else if (fields.serviceIds === undefined &&
        !currentUser.roles?.some((role) => ['secretary', 'doctor'].includes(role)) &&
        !['secretary', 'doctor'].includes(currentUser.role)) {
      fields.serviceIds = currentUser.serviceIds?.length
        ? currentUser.serviceIds
        : currentUser.serviceId
          ? [currentUser.serviceId]
          : [];
    }
    const assignedServiceIds = fields.serviceIds !== undefined
      ? fields.serviceIds
      : currentUser.serviceIds?.length
        ? currentUser.serviceIds
        : currentUser.serviceId
          ? [currentUser.serviceId]
          : [];
    if ((assignedRoles.includes('secretary') &&
         (fields.roles !== undefined ||
          fields.role === 'secretary' ||
         fields.serviceIds !== undefined ||
          fields.serviceId !== undefined)) &&
        !assignedServiceIds.length) {
      throw new HttpError(400, 'A secretary must be assigned to at least one service.');
    }
    if (['secretary', 'doctor'].includes(fields.role) &&
        fields.serviceIds !== undefined) {
      fields.serviceId = fields.serviceIds[0] || null;
    }
  } else if (fields.serviceIds?.length) {
    throw new HttpError(400, 'serviceIds can only be assigned to doctors or secretaries.');
  } else if (fields.roles !== undefined ||
      fields.role !== undefined &&
        (currentUser.role === 'secretary' ||
         currentUser.role === 'doctor' ||
         currentUser.roles?.some((role) => ['secretary', 'doctor'].includes(role)))) {
    fields.serviceIds = [];
    fields.serviceId = null;
  }
  const user = await User.findByIdAndUpdate(id, { $set: fields }, {
    new: true,
    runValidators: true,
  });
  if (!user) throw new HttpError(404, 'User not found.');
  return res.json({ user: userResponse(user) });
}

module.exports = {
  list,
  listAssignablePatients,
  listInterventionParticipants,
  listServiceMembers,
  create,
  update,
};
