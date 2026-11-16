const Shift = require('../models/Shift');
const User = require('../models/User');
const Service = require('../models/Service');
const { HttpError } = require('../errors');
const {
  requireDate,
  requireDateOnly,
  requireId,
  requireObject,
  requireString,
  rejectUnknownFields,
} = require('../utils/validation');

const FIELDS = ['userId', 'serviceId', 'start', 'end', 'role'];

function normalizeLabel(value) {
  return String(value || '')
    .normalize('NFD')
    .replace(/[\u0300-\u036f]/g, '')
    .trim()
    .toLowerCase();
}

function doctorServiceMatchesSpecialty(doctor, service) {
  const roles = doctor.roles?.length ? doctor.roles : [doctor.role];
  const specialty = normalizeLabel(doctor.specialty);
  return roles.includes('doctor') &&
    specialty.length > 0 &&
    normalizeLabel(service.name) === specialty;
}

async function validateDoctorService(userId, serviceId) {
  const [doctor, service] = await Promise.all([
    User.findById(userId).select('role roles specialty active'),
    Service.findById(serviceId).select('name active'),
  ]);
  if (!doctor ||
      doctor.active === false ||
      !doctorServiceMatchesSpecialty(doctor, service || {})) {
    throw new HttpError(
      400,
      'A shift must use the active service matching an active doctor’s specialty.',
    );
  }
  if (!service || service.active === false) {
    throw new HttpError(400, 'The doctor specialty service must be active.');
  }
}

function shiftResponse(shift) {
  return {
    _id: shift._id,
    userId: shift.userId?._id || shift.userId,
    serviceId: shift.serviceId?._id || shift.serviceId,
    start: shift.start,
    end: shift.end,
    role: shift.role,
    userName: shift.userId?.username || '',
    serviceName: shift.serviceId?.name || '',
  };
}

async function populateShift(shift) {
  await shift.populate([
    { path: 'userId', select: 'username' },
    { path: 'serviceId', select: 'name' },
  ]);
  return shift;
}

async function parseFields(body, creating = false) {
  const fields = {};
  for (const field of ['userId', 'serviceId', 'start', 'end', 'role']) {
    if (!creating && body[field] === undefined) continue;
    if (field === 'userId' || field === 'serviceId') {
      fields[field] = requireId(body[field], field);
    } else if (field === 'start' || field === 'end') {
      fields[field] = requireDate(body[field], field);
    } else {
      fields[field] = requireString(body[field], 'role', { max: 100 });
    }
  }
  const [user, service] = await Promise.all([
    fields.userId ? User.exists({ _id: fields.userId }) : Promise.resolve(true),
    fields.serviceId ? Service.exists({ _id: fields.serviceId }) : Promise.resolve(true),
  ]);
  if (!user) throw new HttpError(400, 'userId does not exist.');
  if (!service) throw new HttpError(400, 'serviceId does not exist.');
  if (fields.start && fields.end && fields.end <= fields.start) {
    throw new HttpError(400, 'end must be after start.');
  }
  return fields;
}

async function getManagedServiceIdsForUser(user) {
  const userServices = [
    ...(user.serviceId ? [user.serviceId] : []),
    ...(user.serviceIds || []),
  ];
  const query = {
    $or: [
      { headUserId: user._id },
      ...(userServices.length > 0 ? [{ _id: { $in: userServices } }] : []),
    ],
  };
  const services = await Service.find(query).select('_id headUserId');
  return services.map((s) => String(s._id));
}

async function list(req, res) {
  const query = {};
  if (req.user.role === 'service_head') {
    // Le chef de service voit toutes les gardes de ses services.
    const managedServiceIds = await getManagedServiceIdsForUser(req.user);
    if (req.query.userId !== undefined) {
      query.userId = requireId(req.query.userId, 'userId');
    }
    if (managedServiceIds.length > 0) {
      query.serviceId = { $in: managedServiceIds };
    } else {
      return res.json({ shifts: [] });
    }
  } else if (['doctor', 'secretary'].includes(req.user.role)) {
    if (req.query.userId !== undefined && String(req.query.userId) !== String(req.user._id)) {
      throw new HttpError(403, 'Users can only view their own shifts.');
    }
    query.userId = req.user._id;
  } else if (req.query.userId !== undefined) {
    query.userId = requireId(req.query.userId, 'userId');
  }
  if (req.query.date !== undefined) {
    const start = requireDateOnly(req.query.date);
    const end = new Date(start.getTime() + 24 * 60 * 60 * 1000);
    query.start = { $gte: start, $lt: end };
  }
  const shifts = await Shift.find(query)
    .populate('userId', 'username')
    .populate('serviceId', 'name')
    .sort({ start: 1 })
    .limit(500);
  return res.json({ shifts: shifts.map(shiftResponse) });
}

async function assertServiceHeadOwnsService(user, serviceId) {
  if (user.role !== 'service_head') return;
  const managedIds = await getManagedServiceIdsForUser(user);
  if (!managedIds.includes(String(serviceId))) {
    throw new HttpError(
      403,
      'En tant que chef de service, vous ne pouvez gérer que les gardes de votre propre service.',
    );
  }
}

async function create(req, res) {
  const body = requireObject(req.body);
  rejectUnknownFields(body, FIELDS);
  const fields = await parseFields(body, true);
  await assertServiceHeadOwnsService(req.user, fields.serviceId);
  await validateDoctorService(fields.userId, fields.serviceId);
  const shift = await Shift.create(fields);
  await populateShift(shift);
  return res.status(201).json({ shift: shiftResponse(shift) });
}

async function update(req, res) {
  const id = requireId(req.params.id, 'shift id');
  const body = requireObject(req.body);
  rejectUnknownFields(body, FIELDS);
  const fields = await parseFields(body);
  if (!Object.keys(fields).length) throw new HttpError(400, 'At least one field must be provided.');
  const current = await Shift.findById(id);
  if (!current) throw new HttpError(404, 'Shift not found.');
  const resolvedServiceId = fields.serviceId ?? current.serviceId;
  await assertServiceHeadOwnsService(req.user, resolvedServiceId);
  const start = fields.start || current.start;
  const end = fields.end || current.end;
  if (end <= start) throw new HttpError(400, 'end must be after start.');
  await validateDoctorService(
    fields.userId ?? current.userId,
    resolvedServiceId,
  );
  const shift = await Shift.findByIdAndUpdate(
    id,
    { $set: fields },
    { new: true, runValidators: true },
  );
  await populateShift(shift);
  return res.json({ shift: shiftResponse(shift) });
}

async function remove(req, res) {
  const id = requireId(req.params.id, 'shift id');
  const shift = await Shift.findById(id).populate('serviceId', 'headUserId');
  if (!shift) throw new HttpError(404, 'Shift not found.');
  await assertServiceHeadOwnsService(req.user, shift.serviceId?._id ?? shift.serviceId);
  await shift.deleteOne();
  return res.json({ shift: shiftResponse(shift) });
}

module.exports = {
  list,
  create,
  update,
  remove,
  shiftResponse,
  doctorServiceMatchesSpecialty,
};
