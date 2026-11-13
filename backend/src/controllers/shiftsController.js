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

async function list(req, res) {
  const query = {};
  if (req.query.userId !== undefined) query.userId = requireId(req.query.userId, 'userId');
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

async function create(req, res) {
  const body = requireObject(req.body);
  rejectUnknownFields(body, FIELDS);
  const shift = await Shift.create(await parseFields(body, true));
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
  const start = fields.start || current.start;
  const end = fields.end || current.end;
  if (end <= start) throw new HttpError(400, 'end must be after start.');
  const shift = await Shift.findByIdAndUpdate(
    id,
    { $set: fields },
    { new: true, runValidators: true },
  );
  await populateShift(shift);
  return res.json({ shift: shiftResponse(shift) });
}

module.exports = { list, create, update, shiftResponse };
