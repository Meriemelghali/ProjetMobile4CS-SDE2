const Hospital = require('../models/Hospital');
const Room = require('../models/Room');
const Bed = require('../models/Bed');
const OperatingRoom = require('../models/OperatingRoom');
const Equipment = require('../models/Equipment');
const Service = require('../models/Service');
const User = require('../models/User');
const { HttpError } = require('../errors');
const {
  requireBoolean,
  requireId,
  requireObject,
  requireString,
  rejectUnknownFields,
} = require('../utils/validation');

function idOf(value) {
  return value?._id || value || null;
}

function optionalId(value, field) {
  if (value === null) return null;
  return requireId(value, field);
}

function hospitalResponse(hospital) {
  return {
    _id: hospital._id,
    name: hospital.name,
    address: hospital.address || '',
    phone: hospital.phone || '',
    active: hospital.active,
    serviceIds: (hospital.serviceIds || []).map(idOf),
  };
}

function roomResponse(room, occupancy = undefined) {
  const parsedNumber = Number.parseInt(room.name, 10);
  return {
    _id: room._id,
    hospitalId: idOf(room.hospitalId),
    serviceId: idOf(room.serviceId),
    number: room.number || (Number.isInteger(parsedNumber) ? parsedNumber : 1),
    floor: room.floor || '0',
    type: room.type || 'single',
    status: room.status || 'available',
    capacity: room.capacity,
    occupancy: occupancy || occupancyResponse(room, 0),
  };
}

function bedResponse(bed) {
  const parsedNumber = Number.parseInt(bed.bedNumber, 10);
  return {
    _id: bed._id,
    roomId: idOf(bed.roomId),
    number: bed.number || (Number.isInteger(parsedNumber) ? parsedNumber : 1),
    status: bed.status || (bed.patientId ? 'occupied' : 'free'),
    patientId: idOf(bed.patientId),
    assignedAt: bed.assignedAt || null,
  };
}

function occupancyResponse(room, occupiedBeds) {
  return {
    roomId: room._id,
    capacity: room.capacity,
    occupiedBeds,
    availableBeds: Math.max(0, room.capacity - occupiedBeds),
  };
}

async function validateServiceLinks(serviceIds) {
  if (!Array.isArray(serviceIds)) throw new HttpError(400, 'serviceIds must be an array.');
  const ids = serviceIds.map((id) => requireId(id, 'serviceIds item'));
  if (new Set(ids.map(String)).size !== ids.length) {
    throw new HttpError(400, 'serviceIds must not contain duplicates.');
  }
  if (ids.length && await Service.countDocuments({ _id: { $in: ids } }) !== ids.length) {
    throw new HttpError(400, 'Every serviceId must exist.');
  }
  return ids;
}

async function validateServiceForHospital(hospitalId, serviceId) {
  if (!serviceId) return;
  if (!(await Hospital.exists({ _id: hospitalId, serviceIds: serviceId }))) {
    throw new HttpError(400, 'serviceId must be linked to the selected hospital.');
  }
}

async function parseHospitalFields(body, creating = false) {
  const fields = {};
  if (creating || body.name !== undefined) {
    fields.name = requireString(body.name, 'name', { max: 160 });
  }
  for (const [field, max] of [['address', 240], ['phone', 30]]) {
    if (creating || body[field] !== undefined) {
      fields[field] = body[field] === undefined
        ? ''
        : requireString(body[field], field, { max, min: 0 });
    }
  }
  if (creating || body.active !== undefined) {
    fields.active = body.active === undefined ? true : requireBoolean(body.active, 'active');
  }
  if (creating || body.serviceIds !== undefined) {
    fields.serviceIds = await validateServiceLinks(body.serviceIds === undefined ? [] : body.serviceIds);
  }
  return fields;
}

async function listHospitals(_req, res) {
  const hospitals = await Hospital.find().sort({ name: 1 }).limit(200);
  return res.json({ hospitals: hospitals.map(hospitalResponse) });
}

async function createHospital(req, res) {
  const body = requireObject(req.body);
  rejectUnknownFields(body, ['name', 'address', 'phone', 'active', 'serviceIds']);
  const hospital = await Hospital.create(await parseHospitalFields(body, true));
  return res.status(201).json({ hospital: hospitalResponse(hospital) });
}

async function updateHospital(req, res) {
  const id = requireId(req.params.id, 'hospital id');
  const body = requireObject(req.body);
  rejectUnknownFields(body, ['name', 'address', 'phone', 'active', 'serviceIds']);
  const fields = await parseHospitalFields(body);
  if (!Object.keys(fields).length) throw new HttpError(400, 'At least one field must be provided.');
  if (fields.serviceIds) {
    const current = await Hospital.findById(id).select('serviceIds');
    if (!current) throw new HttpError(404, 'Hospital not found.');
    const removed = current.serviceIds.filter(
      (serviceId) => !fields.serviceIds.some((nextId) => String(nextId) === String(serviceId)),
    );
    if (removed.length) {
      const dependent = await Promise.all([
        Room.exists({ hospitalId: id, serviceId: { $in: removed } }),
        OperatingRoom.exists({ hospitalId: id, serviceId: { $in: removed } }),
        Equipment.exists({ hospitalId: id, serviceId: { $in: removed } }),
      ]);
      if (dependent.some(Boolean)) {
        throw new HttpError(409, 'A service linked to hospital resources cannot be removed.');
      }
    }
  }
  const hospital = await Hospital.findByIdAndUpdate(
    id, { $set: fields }, { new: true, runValidators: true },
  );
  if (!hospital) throw new HttpError(404, 'Hospital not found.');
  return res.json({ hospital: hospitalResponse(hospital) });
}

async function deleteHospital(req, res) {
  const id = requireId(req.params.id, 'hospital id');
  const hospital = await Hospital.findById(id);
  if (!hospital) throw new HttpError(404, 'Hospital not found.');
  const dependent = await Promise.all([
    Room.exists({ hospitalId: id }),
    OperatingRoom.exists({ hospitalId: id }),
    Equipment.exists({ hospitalId: id }),
  ]);
  if (dependent.some(Boolean)) throw new HttpError(409, 'Remove hospital resources before deleting it.');
  await hospital.deleteOne();
  return res.json({ hospital: hospitalResponse(hospital) });
}

function positiveInteger(value, field, max = 500) {
  if (!Number.isInteger(value) || value < 1 || value > max) {
    throw new HttpError(400, `${field} must be an integer between 1 and ${max}.`);
  }
  return value;
}

async function refreshRoomStatus(roomId) {
  const room = await Room.findById(roomId).select('capacity status');
  if (!room || room.status === 'maintenance') return;
  const occupied = await Bed.countDocuments({ roomId, status: 'occupied' });
  const status = occupied >= room.capacity ? 'full' : 'available';
  if (room.status !== status) {
    await Room.updateOne({ _id: roomId, status: { $ne: 'maintenance' } }, { $set: { status } });
  }
}

async function validateRoomFields(fields, current = null) {
  const hospitalId = fields.hospitalId || idOf(current?.hospitalId);
  const serviceId = fields.serviceId === undefined ? idOf(current?.serviceId) : fields.serviceId;
  if (!(await Hospital.exists({ _id: hospitalId }))) throw new HttpError(400, 'hospitalId does not exist.');
  await validateServiceForHospital(hospitalId, serviceId);
  if (current && fields.capacity !== undefined) {
    const bedCount = await Bed.countDocuments({ roomId: current?._id });
    if (fields.capacity < bedCount) {
      throw new HttpError(409, 'capacity cannot be less than the number of registered beds.');
    }
  }
}

const ROOM_TYPES = ['single', 'double', 'intensive_care'];
const ROOM_STATUSES = ['available', 'full', 'maintenance'];

function parseRoomFields(body, creating = false) {
  const fields = {};
  if (creating || body.hospitalId !== undefined) fields.hospitalId = requireId(body.hospitalId, 'hospitalId');
  if (creating || body.serviceId !== undefined) {
    fields.serviceId = requireId(body.serviceId, 'serviceId');
  }
  if (creating || body.number !== undefined) {
    fields.number = positiveInteger(body.number, 'number');
  }
  if (creating || body.floor !== undefined) {
    fields.floor = body.floor === undefined ? '0' : requireString(body.floor, 'floor', { max: 40 });
  }
  if (creating || body.type !== undefined) {
    fields.type = body.type === undefined ? 'single' : body.type;
    if (!ROOM_TYPES.includes(fields.type)) {
      throw new HttpError(400, `type must be one of: ${ROOM_TYPES.join(', ')}.`);
    }
  }
  if (creating || body.status !== undefined) {
    fields.status = body.status === undefined ? 'available' : body.status;
    if (!ROOM_STATUSES.includes(fields.status)) {
      throw new HttpError(400, `status must be one of: ${ROOM_STATUSES.join(', ')}.`);
    }
  }
  if (creating || body.capacity !== undefined) {
    fields.capacity = positiveInteger(
      body.capacity === undefined ? (fields.type === 'double' ? 2 : 1) : body.capacity,
      'capacity',
    );
  }
  return fields;
}

async function listRooms(req, res) {
  const query = {};
  if (req.query.hospitalId !== undefined) {
    query.hospitalId = requireId(req.query.hospitalId, 'hospitalId');
  }
  const rooms = await Room.find(query).select('+name').sort({ number: 1 }).limit(200);
  const counts = await Bed.aggregate([
    { $match: { roomId: { $in: rooms.map((room) => room._id) }, patientId: { $type: 'objectId' } } },
    { $group: { _id: '$roomId', occupied: { $sum: 1 } } },
  ]);
  const occupiedByRoom = new Map(counts.map((item) => [String(item._id), item.occupied]));
  return res.json({
    rooms: rooms.map((room) => roomResponse(room, occupancyResponse(
      room, occupiedByRoom.get(String(room._id)) || 0,
    ))),
  });
}

async function createRoom(req, res) {
  const body = requireObject(req.body);
  rejectUnknownFields(body, ['hospitalId', 'serviceId', 'number', 'floor', 'type', 'status', 'capacity']);
  const fields = parseRoomFields(body, true);
  await validateRoomFields(fields);
  const room = await Room.create({ ...fields, name: String(fields.number) });
  return res.status(201).json({ room: roomResponse(room, occupancyResponse(room, 0)) });
}

async function updateRoom(req, res) {
  const id = requireId(req.params.id, 'room id');
  const body = requireObject(req.body);
  rejectUnknownFields(body, ['hospitalId', 'serviceId', 'number', 'floor', 'type', 'status', 'capacity']);
  const current = await Room.findById(id).select('+name');
  if (!current) throw new HttpError(404, 'Room not found.');
  const fields = parseRoomFields(body);
  if (!Object.keys(fields).length) throw new HttpError(400, 'At least one field must be provided.');
  if (fields.number !== undefined) fields.name = String(fields.number);
  await validateRoomFields(fields, current);
  const room = await Room.findByIdAndUpdate(
    id, { $set: fields }, { new: true, runValidators: true },
  );
  const occupiedBeds = await Bed.countDocuments({ roomId: id, patientId: { $type: 'objectId' } });
  return res.json({ room: roomResponse(room, occupancyResponse(room, occupiedBeds)) });
}

async function deleteRoom(req, res) {
  const id = requireId(req.params.id, 'room id');
  const room = await Room.findById(id);
  if (!room) throw new HttpError(404, 'Room not found.');
  const dependent = await Promise.all([
    Bed.exists({ roomId: id }),
  ]);
  if (dependent.some(Boolean)) throw new HttpError(409, 'Remove beds before deleting the room.');
  await room.deleteOne();
  return res.json({ room: roomResponse(room) });
}

async function roomOccupancy(req, res) {
  const id = requireId(req.params.id, 'room id');
  const room = await Room.findById(id);
  if (!room) throw new HttpError(404, 'Room not found.');
  const occupiedBeds = await Bed.countDocuments({ roomId: id, patientId: { $type: 'objectId' } });
  return res.json({ occupancy: occupancyResponse(room, occupiedBeds) });
}

async function listBeds(req, res) {
  const query = {};
  if (req.query.roomId !== undefined) query.roomId = requireId(req.query.roomId, 'roomId');
  if (req.query.status !== undefined) {
    if (!['free', 'occupied', 'reserved', 'cleaning'].includes(req.query.status)) {
      throw new HttpError(400, 'status must be one of: free, occupied, reserved, cleaning.');
    }
    query.status = req.query.status;
  }
  const beds = await Bed.find(query).select('+bedNumber').sort({ roomId: 1, number: 1 }).limit(500);
  return res.json({ beds: beds.map(bedResponse) });
}

async function createBed(req, res) {
  const body = requireObject(req.body);
  rejectUnknownFields(body, ['roomId', 'number', 'status']);
  const roomId = requireId(body.roomId, 'roomId');
  const number = positiveInteger(body.number, 'number');
  const status = body.status === undefined ? 'free' : body.status;
  if (!['free', 'occupied', 'reserved', 'cleaning'].includes(status) || status === 'occupied') {
    throw new HttpError(400, 'New beds must use free, reserved, or cleaning status.');
  }
  const room = await Room.findById(roomId);
  if (!room) throw new HttpError(400, 'roomId does not exist.');
  if (await Bed.countDocuments({ roomId }) >= room.capacity) {
    throw new HttpError(409, 'The room has reached its bed capacity.');
  }
  const bed = await Bed.create({ roomId, number, bedNumber: String(number), status });
  return res.status(201).json({ bed: bedResponse(bed) });
}

async function updateBed(req, res) {
  const id = requireId(req.params.id, 'bed id');
  const body = requireObject(req.body);
  rejectUnknownFields(body, ['roomId', 'number', 'status']);
  const current = await Bed.findById(id).select('+bedNumber');
  if (!current) throw new HttpError(404, 'Bed not found.');
  const fields = {};
  if (body.roomId !== undefined) fields.roomId = requireId(body.roomId, 'roomId');
  if (body.number !== undefined) fields.number = positiveInteger(body.number, 'number');
  if (body.status !== undefined) {
    if (!['free', 'reserved', 'cleaning'].includes(body.status)) {
      throw new HttpError(400, 'status must be free, reserved, or cleaning when changing an unassigned bed.');
    }
    if (current.patientId) throw new HttpError(409, 'Release the patient before changing bed status.');
    fields.status = body.status;
  }
  if (!Object.keys(fields).length) throw new HttpError(400, 'At least one field must be provided.');
  if (fields.number !== undefined) fields.bedNumber = String(fields.number);
  const roomId = fields.roomId || current.roomId;
  const room = await Room.findById(roomId);
  if (!room) throw new HttpError(400, 'roomId does not exist.');
  if (String(roomId) !== String(current.roomId)
      && await Bed.countDocuments({ roomId }) >= room.capacity) {
    throw new HttpError(409, 'The room has reached its bed capacity.');
  }
  const bed = await Bed.findByIdAndUpdate(
    id, { $set: fields }, { new: true, runValidators: true },
  ).select('+bedNumber');
  await refreshRoomStatus(roomId);
  if (String(roomId) !== String(current.roomId)) await refreshRoomStatus(current.roomId);
  return res.json({ bed: bedResponse(bed) });
}

async function deleteBed(req, res) {
  const id = requireId(req.params.id, 'bed id');
  const bed = await Bed.findById(id).select('+bedNumber');
  if (!bed) throw new HttpError(404, 'Bed not found.');
  if (bed.patientId) throw new HttpError(409, 'Release the patient before deleting the bed.');
  const roomId = bed.roomId;
  await bed.deleteOne();
  await refreshRoomStatus(roomId);
  return res.json({ bed: bedResponse(bed) });
}

async function assignBed(req, res) {
  const id = requireId(req.params.id, 'bed id');
  const body = requireObject(req.body);
  rejectUnknownFields(body, ['patientId']);
  const patientId = requireId(body.patientId, 'patientId');
  if (!(await User.exists({ _id: patientId, role: 'patient', active: true }))) {
    throw new HttpError(400, 'patientId must identify an active patient account.');
  }
  if (await Bed.exists({ patientId })) throw new HttpError(409, 'This patient already has an assigned bed.');
  const bed = await Bed.findOneAndUpdate(
    { _id: id, patientId: { $exists: false }, status: { $in: ['free', 'reserved'] } },
    { $set: { patientId, assignedAt: new Date(), status: 'occupied' } },
    { new: true },
  ).select('+bedNumber');
  if (!bed) {
    if (!(await Bed.exists({ _id: id }))) throw new HttpError(404, 'Bed not found.');
    throw new HttpError(409, 'The bed is already occupied.');
  }
  await refreshRoomStatus(bed.roomId);
  return res.json({ bed: bedResponse(bed) });
}

async function dischargeBed(req, res) {
  const id = requireId(req.params.id, 'bed id');
  const current = await Bed.findById(id).select('roomId');
  if (!current) throw new HttpError(404, 'Bed not found.');
  const bed = await Bed.findByIdAndUpdate(
    id, { $unset: { patientId: 1, assignedAt: 1 }, $set: { status: 'free' } }, { new: true },
  ).select('+bedNumber');
  await refreshRoomStatus(current.roomId);
  return res.json({ bed: bedResponse(bed) });
}

module.exports = {
  listHospitals,
  createHospital,
  updateHospital,
  deleteHospital,
  listRooms,
  createRoom,
  updateRoom,
  deleteRoom,
  roomOccupancy,
  listBeds,
  createBed,
  updateBed,
  deleteBed,
  assignBed,
  dischargeBed,
  hospitalResponse,
  roomResponse,
  bedResponse,
  occupancyResponse,
};
