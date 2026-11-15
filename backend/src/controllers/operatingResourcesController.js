const Hospital = require('../models/Hospital');
const OperatingRoom = require('../models/OperatingRoom');
const Intervention = require('../models/Intervention');
const Equipment = require('../models/Equipment');
const User = require('../models/User');
const Service = require('../models/Service');
const { HttpError } = require('../errors');
const {
  assertHospitalScope,
  assertServiceScope,
  hospitalIdFor,
  serviceIdFor,
} = require('../middleware/resourceAccess');
const {
  requireDate,
  requireId,
  requireObject,
  requireString,
  rejectUnknownFields,
} = require('../utils/validation');

const INTERVENTION_STATUSES = ['scheduled', 'in_progress', 'completed', 'cancelled'];
const ACTIVE_STATUSES = ['scheduled', 'in_progress'];
const EQUIPMENT_STATUSES = ['functional', 'broken', 'maintenance'];
const OPERATING_ROOM_STATUSES = ['free', 'in_progress', 'sterilization', 'maintenance'];

function idOf(value) {
  return value?._id || value || null;
}

function assignedServiceIds(user) {
  return [
    ...(user.serviceIds || []).map((id) => id.toString()),
    ...(user.serviceId ? [user.serviceId.toString()] : []),
  ];
}

async function assertInterventionScope(user, room, surgeonId) {
  if (user.role === 'admin') return;
  const roomServiceId = idOf(room.serviceId)?.toString();
  if (!roomServiceId || !assignedServiceIds(user).includes(roomServiceId)) {
    throw new HttpError(403, 'The operating room is outside your assigned services.');
  }
  if (user.hospitalId && String(user.hospitalId) !== String(room.hospitalId)) {
    throw new HttpError(403, 'The operating room is outside your hospital.');
  }
  const service = await Service.findById(room.serviceId).select('a_operations');
  if (!service?.a_operations) {
    throw new HttpError(403, 'Operating interventions are not enabled for this service.');
  }
  if (user.role === 'doctor' && String(surgeonId) !== String(user._id)) {
    throw new HttpError(403, 'A doctor can only schedule their own interventions.');
  }
}

function hasScheduleConflict(schedule, start, end, excludingId = null) {
  return schedule.some((entry) => (
    String(entry.interventionId) !== String(excludingId)
      && ACTIVE_STATUSES.includes(entry.status)
      && new Date(entry.start) < end
      && new Date(entry.end) > start
  ));
}

function operatingRoomResponse(room) {
  return {
    _id: room._id,
    hospitalId: idOf(room.hospitalId),
    serviceId: idOf(room.serviceId),
    name: room.name,
    number: room.number || 1,
    status: room.status || 'free',
    scheduledCount: (room.schedule || []).filter((entry) => ACTIVE_STATUSES.includes(entry.status)).length,
  };
}

function interventionResponse(intervention) {
  return {
    _id: intervention._id,
    surgeonId: idOf(intervention.surgeonId),
    surgeonName: intervention.surgeonId?.displayName || '',
    patientId: idOf(intervention.patientId),
    operatingRoomId: idOf(intervention.operatingRoomId),
    operatingRoomName: intervention.operatingRoomId?.name || '',
    serviceId: idOf(intervention.operatingRoomId?.serviceId),
    equipmentIds: (intervention.equipmentIds || []).map(idOf),
    title: intervention.title,
    start: intervention.start,
    end: intervention.end,
    status: intervention.status,
  };
}

function equipmentResponse(equipment) {
  const legacyStatus = {
    available: 'functional',
    in_use: 'functional',
    retired: 'broken',
  }[equipment.status];
  return {
    _id: equipment._id,
    hospitalId: idOf(equipment.hospitalId),
    serviceId: idOf(equipment.serviceId),
    operatingRoomId: idOf(equipment.operatingRoomId),
    name: equipment.name,
    type: equipment.type || 'unspecified',
    serialNumber: equipment.serialNumber || equipment.assetTag || '',
    status: EQUIPMENT_STATUSES.includes(equipment.status) ? equipment.status : (legacyStatus || 'functional'),
    lastMaintenanceAt: equipment.lastMaintenanceAt || null,
    maintenanceDueAt: equipment.maintenanceDueAt || null,
  };
}

async function validateServiceLink(hospitalId, serviceId) {
  if (!serviceId) return;
  if (!(await Hospital.exists({ _id: hospitalId, serviceIds: serviceId }))) {
    throw new HttpError(400, 'serviceId must be linked to the selected hospital.');
  }
}

function parseOperatingRoomFields(body, creating = false) {
  const fields = {};
  if (creating || body.hospitalId !== undefined) fields.hospitalId = requireId(body.hospitalId, 'hospitalId');
  if (creating || body.serviceId !== undefined) {
    fields.serviceId = body.serviceId === undefined
      ? null
      : body.serviceId === null ? null : requireId(body.serviceId, 'serviceId');
  }
  if (creating || body.name !== undefined) fields.name = requireString(body.name, 'name', { max: 100 });
  if (creating || body.number !== undefined) {
    const number = body.number === undefined ? 1 : body.number;
    if (!Number.isInteger(number) || number < 1) throw new HttpError(400, 'number must be a positive integer.');
    fields.number = number;
  }
  if (body.status !== undefined) {
    if (!['free', 'sterilization'].includes(body.status)) {
      throw new HttpError(400, 'status may be free or sterilization; in_progress is managed by interventions.');
    }
    fields.status = body.status;
  }
  return fields;
}

async function validateOperatingRoomFields(fields, current = null) {
  const hospitalId = fields.hospitalId || idOf(current?.hospitalId);
  const serviceId = fields.serviceId === undefined ? idOf(current?.serviceId) : fields.serviceId;
  if (!(await Hospital.exists({ _id: hospitalId }))) throw new HttpError(400, 'hospitalId does not exist.');
  await validateServiceLink(hospitalId, serviceId);
}

async function listOperatingRooms(req, res) {
  const query = {};
  if (req.query.hospitalId !== undefined) query.hospitalId = requireId(req.query.hospitalId, 'hospitalId');
  if (req.user.role === 'service_head') {
    const serviceId = serviceIdFor(req.user);
    const hospitalId = hospitalIdFor(req.user);
    if (!serviceId || !hospitalId) {
      throw new HttpError(403, 'A hospital and service assignment are required.');
    }
    if (query.hospitalId) assertHospitalScope(req.user, query.hospitalId);
    query.hospitalId = hospitalId;
    query.serviceId = serviceId;
  } else if (req.user.role === 'operating_room_manager') {
    const hospitalId = hospitalIdFor(req.user);
    if (!hospitalId) throw new HttpError(403, 'A hospital assignment is required.');
    if (query.hospitalId) assertHospitalScope(req.user, query.hospitalId);
    query.hospitalId = hospitalId;
  }
  const rooms = await OperatingRoom.find(query).sort({ number: 1 }).limit(200);
  return res.json({ operatingRooms: rooms.map(operatingRoomResponse) });
}

async function createOperatingRoom(req, res) {
  const body = requireObject(req.body);
  rejectUnknownFields(body, ['hospitalId', 'serviceId', 'name', 'number', 'status']);
  const fields = parseOperatingRoomFields(body, true);
  assertHospitalScope(req.user, fields.hospitalId);
  await validateOperatingRoomFields(fields);
  const room = await OperatingRoom.create(fields);
  return res.status(201).json({ operatingRoom: operatingRoomResponse(room) });
}

async function updateOperatingRoom(req, res) {
  const id = requireId(req.params.id, 'operating room id');
  const body = requireObject(req.body);
  rejectUnknownFields(body, ['hospitalId', 'serviceId', 'name', 'number', 'status']);
  const current = await OperatingRoom.findById(id);
  if (!current) throw new HttpError(404, 'Operating room not found.');
  if (req.user.role === 'nurse') {
    rejectUnknownFields(body, ['status']);
    if (body.status === undefined) {
      throw new HttpError(400, 'Only an operating room status change is allowed.');
    }
    const serviceIds = new Set([
      ...(req.user.serviceIds || []).map(String),
      ...(req.user.serviceId ? [String(req.user.serviceId)] : []),
    ]);
    const service = current.serviceId
      ? await Service.findById(current.serviceId).select('a_operations')
      : null;
    if (!current.serviceId || !serviceIds.has(String(current.serviceId)) ||
        service?.a_operations !== true) {
      throw new HttpError(403, 'Operating room is outside your assigned services.');
    }
  } else {
    assertHospitalScope(req.user, current.hospitalId);
  }
  const fields = parseOperatingRoomFields(body);
  if (req.user.role !== 'nurse') {
    assertHospitalScope(
      req.user,
      fields.hospitalId === undefined ? current.hospitalId : fields.hospitalId,
    );
  }
  if (!Object.keys(fields).length) throw new HttpError(400, 'At least one field must be provided.');
  await validateOperatingRoomFields(fields, current);
  const updateQuery = { _id: id };
  if (['sterilization', 'free', 'maintenance'].includes(fields.status)) {
    updateQuery.schedule = {
      $not: { $elemMatch: { status: { $in: ACTIVE_STATUSES } } },
    };
  }
  const room = await OperatingRoom.findOneAndUpdate(
    updateQuery, { $set: fields }, { new: true, runValidators: true },
  );
  if (!room) {
    if (!(await OperatingRoom.exists({ _id: id }))) throw new HttpError(404, 'Operating room not found.');
    throw new HttpError(409, 'Cancel or complete scheduled interventions before changing the room status.');
  }
  return res.json({ operatingRoom: operatingRoomResponse(room) });
}

async function deleteOperatingRoom(req, res) {
  const id = requireId(req.params.id, 'operating room id');
  const room = await OperatingRoom.findById(id);
  if (!room) throw new HttpError(404, 'Operating room not found.');
  assertHospitalScope(req.user, room.hospitalId);
  if (await Intervention.exists({ operatingRoomId: id })) {
    throw new HttpError(409, 'Remove interventions before deleting the operating room.');
  }
  await room.deleteOne();
  return res.json({ operatingRoom: operatingRoomResponse(room) });
}

async function listInterventions(req, res) {
  const query = {};
  let allowedOperatingRoomIds = null;
  if (req.user.role === 'operating_room_manager') {
    const hospitalId = hospitalIdFor(req.user);
    if (!hospitalId) throw new HttpError(403, 'A hospital assignment is required.');
    const rooms = await OperatingRoom.find({ hospitalId }).select('_id');
    allowedOperatingRoomIds = new Set(rooms.map((room) => String(room._id)));
  }
  if (req.user.role === 'service_head') {
    const serviceId = serviceIdFor(req.user);
    const hospitalId = hospitalIdFor(req.user);
    if (!serviceId || !hospitalId) {
      throw new HttpError(403, 'A hospital and service assignment are required.');
    }
    const rooms = await OperatingRoom.find({ hospitalId, serviceId }).select('_id');
    allowedOperatingRoomIds = new Set(rooms.map((room) => String(room._id)));
  }
  if (req.user.role === 'doctor') {
    if (req.query.surgeonId !== undefined &&
        requireId(req.query.surgeonId, 'surgeonId') !== req.user._id.toString()) {
      throw new HttpError(403, 'Doctors can only view their own interventions.');
    }
    query.surgeonId = req.user._id;
    const assignedServiceIds = [
      ...(req.user.serviceIds || []).map((id) => id.toString()),
      ...(req.user.serviceId ? [req.user.serviceId.toString()] : []),
    ];
    const enabledServices = assignedServiceIds.length
      ? await Service.find({
          _id: { $in: assignedServiceIds },
          a_operations: true,
        }).select('_id')
      : [];
    const rooms = enabledServices.length
      ? await OperatingRoom.find({
          serviceId: { $in: enabledServices.map((service) => service._id) },
        }).select('_id')
      : [];
    allowedOperatingRoomIds = new Set(rooms.map((room) => String(room._id)));
  }
  if (req.user.role === 'secretary') {
    const serviceIds = assignedServiceIds(req.user);
    const enabledServices = serviceIds.length
      ? await Service.find({ _id: { $in: serviceIds }, a_operations: true }).select('_id')
      : [];
    const rooms = enabledServices.length
      ? await OperatingRoom.find({
          serviceId: { $in: enabledServices.map((service) => service._id) },
        }).select('_id')
      : [];
    allowedOperatingRoomIds = new Set(rooms.map((room) => String(room._id)));
  }
  if (req.query.surgeonId !== undefined) {
    const surgeonId = requireId(req.query.surgeonId, 'surgeonId');
    if (req.user.role !== 'doctor') query.surgeonId = surgeonId;
  }
  if (req.query.patientId !== undefined) {
    query.patientId = requireId(req.query.patientId, 'patientId');
  }
  if (req.query.operatingRoomId !== undefined) {
    const operatingRoomId = requireId(req.query.operatingRoomId, 'operatingRoomId');
    if (allowedOperatingRoomIds && !allowedOperatingRoomIds.has(operatingRoomId)) {
      throw new HttpError(403, 'Operating room is outside your assigned scope.');
    }
    query.operatingRoomId = operatingRoomId;
  } else if (allowedOperatingRoomIds) {
    query.operatingRoomId = { $in: [...allowedOperatingRoomIds] };
  }
  if (req.query.status !== undefined) {
    if (!INTERVENTION_STATUSES.includes(req.query.status)) {
      throw new HttpError(400, `status must be one of: ${INTERVENTION_STATUSES.join(', ')}.`);
    }
    query.status = req.query.status;
  }
  const interventions = await Intervention.find(query)
    .populate('operatingRoomId', 'name serviceId')
    .populate('surgeonId', 'displayName')
    .sort({ start: 1 })
    .limit(500);
  return res.json({ interventions: interventions.map(interventionResponse) });
}

async function persistInterventionSchedule(roomId, interventionId, start, end, status, creating = false) {
  const active = ACTIVE_STATUSES.includes(status);
  const query = { _id: roomId, status: { $ne: 'sterilization' } };
  if (creating) {
    if (active) {
      query.schedule = {
        $not: { $elemMatch: { status: { $in: ACTIVE_STATUSES }, start: { $lt: end }, end: { $gt: start } } },
      };
    }
    return OperatingRoom.findOneAndUpdate(
      query,
      { $push: { schedule: { interventionId, start, end, status } } },
      { new: true },
    );
  }

  const conditions = [{ schedule: { $elemMatch: { interventionId } } }];
  if (active) {
    conditions.push({
      schedule: {
        $not: {
          $elemMatch: {
            interventionId: { $ne: interventionId },
            status: { $in: ACTIVE_STATUSES },
            start: { $lt: end },
            end: { $gt: start },
          },
        },
      },
    });
  }
  query.$and = conditions;
  return OperatingRoom.findOneAndUpdate(
    query,
    {
      $set: {
        'schedule.$[slot].start': start,
        'schedule.$[slot].end': end,
        'schedule.$[slot].status': status,
      },
    },
    { arrayFilters: [{ 'slot.interventionId': interventionId }], new: true },
  );
}

async function setOperatingRoomStatus(roomId) {
  const active = await Intervention.exists({
    operatingRoomId: roomId,
    status: 'in_progress',
  });
  await OperatingRoom.updateOne(
    { _id: roomId, status: { $ne: 'sterilization' } },
    { $set: { status: active ? 'in_progress' : 'free' } },
  );
}

async function reserveEquipment(equipmentId, interventionId, start, end, status) {
  if (!ACTIVE_STATUSES.includes(status)) {
    await Equipment.updateOne({ _id: equipmentId }, { $pull: { schedule: { interventionId } } });
    return true;
  }
  const noConflict = {
    schedule: {
      $not: {
        $elemMatch: {
          interventionId: { $ne: interventionId },
          status: { $in: ACTIVE_STATUSES },
          start: { $lt: end },
          end: { $gt: start },
        },
      },
    },
  };
  const existing = await Equipment.exists({ _id: equipmentId, 'schedule.interventionId': interventionId });
  if (existing) {
    return Boolean(await Equipment.updateOne(
      { _id: equipmentId, status: 'functional', ...noConflict },
      {
        $set: {
          'schedule.$[slot].start': start,
          'schedule.$[slot].end': end,
          'schedule.$[slot].status': status,
        },
      },
      { arrayFilters: [{ 'slot.interventionId': interventionId }] },
    ).then((result) => result.matchedCount));
  }
  const updated = await Equipment.updateOne(
    { _id: equipmentId, status: 'functional', ...noConflict },
    { $push: { schedule: { interventionId, start, end, status } } },
  );
  return Boolean(updated.modifiedCount);
}

async function restoreEquipmentSchedules(equipmentIds, interventionId, oldEntry) {
  for (const equipmentId of equipmentIds) {
    await Equipment.updateOne({ _id: equipmentId }, { $pull: { schedule: { interventionId } } });
  }
  if (oldEntry && ACTIVE_STATUSES.includes(oldEntry.status)) {
    for (const equipmentId of oldEntry.equipmentIds) {
      await Equipment.updateOne(
        { _id: equipmentId },
        { $push: { schedule: { interventionId, start: oldEntry.start, end: oldEntry.end, status: oldEntry.status } } },
      );
    }
  }
}

async function syncEquipmentSchedules(nextIds, interventionId, start, end, status, oldEntry = null) {
  const allIds = [...new Set([...(oldEntry?.equipmentIds || []), ...nextIds].map(String))].sort();
  const reserved = [];
  for (const equipmentId of nextIds.map(String).sort()) {
    const success = await reserveEquipment(equipmentId, interventionId, start, end, status);
    if (!success) {
      await restoreEquipmentSchedules(reserved, interventionId, oldEntry);
      for (const oldId of oldEntry?.equipmentIds || []) {
        if (!reserved.includes(String(oldId))) {
          await reserveEquipment(oldId, interventionId, oldEntry.start, oldEntry.end, oldEntry.status);
        }
      }
      throw new HttpError(409, 'Equipment is not functional or is reserved by an overlapping intervention.');
    }
    reserved.push(equipmentId);
  }
  for (const equipmentId of oldEntry?.equipmentIds || []) {
    if (!nextIds.some((nextId) => String(nextId) === String(equipmentId))) {
      await Equipment.updateOne({ _id: equipmentId }, { $pull: { schedule: { interventionId } } });
    }
  }
  if (!ACTIVE_STATUSES.includes(status)) {
    await restoreEquipmentSchedules(allIds, interventionId, null);
  }
}

async function validateInterventionEquipment(equipmentIds, operatingRoom, requireFunctional) {
  if (!Array.isArray(equipmentIds)) throw new HttpError(400, 'equipmentIds must be an array.');
  const ids = equipmentIds.map((id) => requireId(id, 'equipmentIds item'));
  if (new Set(ids.map(String)).size !== ids.length) {
    throw new HttpError(400, 'equipmentIds must not contain duplicates.');
  }
  if (!ids.length) return ids;
  const items = await Equipment.find({ _id: { $in: ids } }).select(
    '_id hospitalId serviceId operatingRoomId status',
  );
  if (items.length !== ids.length) throw new HttpError(400, 'Every equipmentId must exist.');
  for (const item of items) {
    if (requireFunctional && item.status !== 'functional') {
      throw new HttpError(409, 'Every assigned equipment item must be functional.');
    }
    const assignedToRoom = item.operatingRoomId
      && String(item.operatingRoomId) === String(operatingRoom._id);
    const assignedToService = item.serviceId && operatingRoom.serviceId
      && String(item.serviceId) === String(operatingRoom.serviceId);
    if (!assignedToRoom && !assignedToService) {
      throw new HttpError(400, 'Equipment must be assigned to this operating room or its service.');
    }
  }
  return ids;
}

async function createIntervention(req, res) {
  const body = requireObject(req.body);
  rejectUnknownFields(body, [
    'surgeonId', 'patientId', 'operatingRoomId', 'equipmentIds', 'title', 'start', 'end', 'status',
  ]);
  const surgeonId = requireId(body.surgeonId, 'surgeonId');
  const patientId = requireId(body.patientId, 'patientId');
  const operatingRoomId = requireId(body.operatingRoomId, 'operatingRoomId');
  const title = requireString(body.title, 'title', { max: 160 });
  const start = requireDate(body.start, 'start');
  const end = requireDate(body.end, 'end');
  const status = body.status === undefined ? 'scheduled' : body.status;
  if (!INTERVENTION_STATUSES.includes(status)) {
    throw new HttpError(400, `status must be one of: ${INTERVENTION_STATUSES.join(', ')}.`);
  }
  if (end <= start) throw new HttpError(400, 'end must be after start.');

  const [surgeon, patient] = await Promise.all([
    User.exists({
      _id: surgeonId,
      active: true,
      $or: [{ role: 'doctor' }, { roles: 'doctor' }],
    }),
    User.exists({ _id: patientId, role: 'patient', active: true }),
  ]);
  if (!surgeon) throw new HttpError(400, 'surgeonId must identify an active doctor account.');
  if (!patient) throw new HttpError(400, 'patientId must identify an active patient account.');

  const room = await OperatingRoom.findById(operatingRoomId);
  if (!room) throw new HttpError(400, 'operatingRoomId does not exist.');
  await assertInterventionScope(req.user, room, surgeonId);
  if (room.status === 'sterilization') throw new HttpError(409, 'Operating room is in sterilization.');
  const equipmentIds = await validateInterventionEquipment(
    body.equipmentIds || [], room, ACTIVE_STATUSES.includes(status),
  );
  if (ACTIVE_STATUSES.includes(status) && hasScheduleConflict(room.schedule, start, end)) {
    throw new HttpError(409, 'The operating room already has an overlapping intervention.');
  }

  const interventionId = new Intervention()._id;
  const reserved = await persistInterventionSchedule(
    operatingRoomId, interventionId, start, end, status, true,
  );
  if (!reserved) {
    const latestRoom = await OperatingRoom.findById(operatingRoomId);
    if (!latestRoom) throw new HttpError(404, 'Operating room not found.');
    if (latestRoom.status === 'sterilization') throw new HttpError(409, 'Operating room is in sterilization.');
    throw new HttpError(409, 'The operating room already has an overlapping intervention.');
  }
  try {
    await syncEquipmentSchedules(equipmentIds, interventionId, start, end, status);
    const intervention = await Intervention.create({
      _id: interventionId,
      surgeonId,
      patientId,
      operatingRoomId,
      equipmentIds,
      title,
      start,
      end,
      status,
    });
    await setOperatingRoomStatus(operatingRoomId);
    await intervention.populate('operatingRoomId', 'name serviceId');
    await intervention.populate('surgeonId', 'displayName');
    return res.status(201).json({ intervention: interventionResponse(intervention) });
  } catch (error) {
    await OperatingRoom.updateOne(
      { _id: operatingRoomId },
      { $pull: { schedule: { interventionId } } },
    );
    await restoreEquipmentSchedules(equipmentIds, interventionId, null);
    throw error;
  }
}

async function updateIntervention(req, res) {
  const id = requireId(req.params.id, 'intervention id');
  const body = requireObject(req.body);
  rejectUnknownFields(body, ['surgeonId', 'patientId', 'equipmentIds', 'title', 'start', 'end', 'status']);
  const current = await Intervention.findById(id);
  if (!current) throw new HttpError(404, 'Intervention not found.');
  const fields = {};
  if (body.surgeonId !== undefined) {
    fields.surgeonId = requireId(body.surgeonId, 'surgeonId');
  }
  if (body.patientId !== undefined) {
    fields.patientId = requireId(body.patientId, 'patientId');
  }
  if (body.equipmentIds !== undefined) fields.equipmentIds = body.equipmentIds;
  if (body.title !== undefined) fields.title = requireString(body.title, 'title', { max: 160 });
  if (body.start !== undefined) fields.start = requireDate(body.start, 'start');
  if (body.end !== undefined) fields.end = requireDate(body.end, 'end');
  if (body.status !== undefined) {
    if (!INTERVENTION_STATUSES.includes(body.status)) {
      throw new HttpError(400, `status must be one of: ${INTERVENTION_STATUSES.join(', ')}.`);
    }
    fields.status = body.status;
  }
  if (!Object.keys(fields).length) throw new HttpError(400, 'At least one field must be provided.');
  const [surgeon, patient] = await Promise.all([
    fields.surgeonId
      ? User.exists({
          _id: fields.surgeonId,
          active: true,
          $or: [{ role: 'doctor' }, { roles: 'doctor' }],
        })
      : Promise.resolve(true),
    fields.patientId
      ? User.exists({ _id: fields.patientId, role: 'patient', active: true })
      : Promise.resolve(true),
  ]);
  if (!surgeon) throw new HttpError(400, 'surgeonId must identify an active doctor account.');
  if (!patient) throw new HttpError(400, 'patientId must identify an active patient account.');
  const start = fields.start || current.start;
  const end = fields.end || current.end;
  const status = fields.status || current.status;
  if (end <= start) throw new HttpError(400, 'end must be after start.');

  const roomId = idOf(current.operatingRoomId);
  const room = await OperatingRoom.findById(roomId);
  if (!room) throw new HttpError(409, 'The intervention operating room no longer exists.');
  await assertInterventionScope(
    req.user,
    room,
    fields.surgeonId || current.surgeonId,
  );
  if (room.status === 'sterilization' && ACTIVE_STATUSES.includes(status)) {
    throw new HttpError(409, 'Operating room is in sterilization.');
  }
  const equipmentIds = await validateInterventionEquipment(
    fields.equipmentIds === undefined ? current.equipmentIds || [] : fields.equipmentIds,
    room,
    ACTIVE_STATUSES.includes(status),
  );
  if (fields.equipmentIds !== undefined) fields.equipmentIds = equipmentIds;
  if (ACTIVE_STATUSES.includes(status) && hasScheduleConflict(room.schedule, start, end, id)) {
    throw new HttpError(409, 'The operating room already has an overlapping intervention.');
  }
  const reservation = await persistInterventionSchedule(roomId, id, start, end, status);
  if (!reservation) {
    throw new HttpError(409, 'The intervention schedule changed or conflicts with another intervention.');
  }
  try {
    await syncEquipmentSchedules(
      equipmentIds,
      id,
      start,
      end,
      status,
      {
        equipmentIds: current.equipmentIds || [],
        start: current.start,
        end: current.end,
        status: current.status,
      },
    );
    const intervention = await Intervention.findByIdAndUpdate(
      id, { $set: fields }, { new: true, runValidators: true },
    ).populate('operatingRoomId', 'name serviceId').populate('surgeonId', 'displayName');
    if (!intervention) {
      throw new HttpError(404, 'Intervention not found.');
    }
    await setOperatingRoomStatus(roomId);
    return res.json({ intervention: interventionResponse(intervention) });
  } catch (error) {
    await persistInterventionSchedule(roomId, id, current.start, current.end, current.status);
    const rollbackIds = [...new Set([...(current.equipmentIds || []), ...equipmentIds].map(String))];
    await restoreEquipmentSchedules(rollbackIds, id, {
      equipmentIds: current.equipmentIds || [],
      start: current.start,
      end: current.end,
      status: current.status,
    });
    throw error;
  }
}

async function deleteIntervention(req, res) {
  const id = requireId(req.params.id, 'intervention id');
  const intervention = await Intervention.findById(id).populate('operatingRoomId', 'name');
  if (!intervention) throw new HttpError(404, 'Intervention not found.');
  await OperatingRoom.updateOne(
    { _id: idOf(intervention.operatingRoomId) },
    { $pull: { schedule: { interventionId: id } } },
  );
  await Equipment.updateMany(
    { 'schedule.interventionId': id },
    { $pull: { schedule: { interventionId: id } } },
  );
  await intervention.deleteOne();
  await setOperatingRoomStatus(idOf(intervention.operatingRoomId));
  return res.json({ intervention: interventionResponse(intervention) });
}

function parseEquipmentFields(body, creating = false) {
  const fields = {};
  if (creating || body.hospitalId !== undefined) fields.hospitalId = requireId(body.hospitalId, 'hospitalId');
  if (creating || body.serviceId !== undefined) {
    fields.serviceId = body.serviceId === undefined || body.serviceId === null
      ? null : requireId(body.serviceId, 'serviceId');
  }
  if (creating || body.operatingRoomId !== undefined) {
    fields.operatingRoomId = body.operatingRoomId === undefined || body.operatingRoomId === null
      ? null : requireId(body.operatingRoomId, 'operatingRoomId');
  }
  if (creating || body.name !== undefined) fields.name = requireString(body.name, 'name', { max: 120 });
  if (creating || body.type !== undefined) fields.type = requireString(body.type, 'type', { max: 100 });
  if (creating || body.serialNumber !== undefined) {
    fields.serialNumber = requireString(body.serialNumber, 'serialNumber', { max: 100 });
  }
  if (creating || body.status !== undefined) {
    fields.status = body.status === undefined ? 'functional' : body.status;
    if (!EQUIPMENT_STATUSES.includes(fields.status)) {
      throw new HttpError(400, `status must be one of: ${EQUIPMENT_STATUSES.join(', ')}.`);
    }
  }
  if (creating || body.lastMaintenanceAt !== undefined) {
    fields.lastMaintenanceAt = body.lastMaintenanceAt === null || body.lastMaintenanceAt === undefined
      ? undefined : requireDate(body.lastMaintenanceAt, 'lastMaintenanceAt');
  }
  if (creating || body.maintenanceDueAt !== undefined) {
    fields.maintenanceDueAt = body.maintenanceDueAt === null || body.maintenanceDueAt === undefined
      ? undefined : requireDate(body.maintenanceDueAt, 'maintenanceDueAt');
  }
  return fields;
}

function parseMaintenanceUpdate(body) {
  const fields = parseEquipmentFields(body);
  const $set = {};
  const $unset = {};
  if (fields.status !== undefined) $set.status = fields.status;
  for (const field of ['lastMaintenanceAt', 'maintenanceDueAt']) {
    if (body[field] === null) $unset[field] = 1;
    else if (fields[field] !== undefined) $set[field] = fields[field];
  }
  if (!Object.keys($set).length && !Object.keys($unset).length) {
    throw new HttpError(400, 'At least one maintenance field must be provided.');
  }
  return { $set, $unset };
}

async function validateEquipmentLocation(fields, current = null) {
  const hospitalId = fields.hospitalId || idOf(current?.hospitalId);
  const serviceId = fields.serviceId === undefined ? idOf(current?.serviceId) : fields.serviceId;
  const operatingRoomId = fields.operatingRoomId === undefined
    ? idOf(current?.operatingRoomId)
    : fields.operatingRoomId;
  if (!(await Hospital.exists({ _id: hospitalId }))) throw new HttpError(400, 'hospitalId does not exist.');
  if (Boolean(serviceId) === Boolean(operatingRoomId)) {
    throw new HttpError(400, 'Specify exactly one of serviceId or operatingRoomId.');
  }
  if (serviceId) {
    await validateServiceLink(hospitalId, serviceId);
  } else {
    const operatingRoom = await OperatingRoom.findById(operatingRoomId).select('hospitalId');
    if (!operatingRoom || String(operatingRoom.hospitalId) !== String(hospitalId)) {
      throw new HttpError(400, 'operatingRoomId must identify an operating room in the selected hospital.');
    }
  }
}

async function listEquipment(req, res) {
  const query = {};
  if (req.query.hospitalId !== undefined) query.hospitalId = requireId(req.query.hospitalId, 'hospitalId');
  if (req.query.status !== undefined) {
    if (!EQUIPMENT_STATUSES.includes(req.query.status)) {
      throw new HttpError(400, `status must be one of: ${EQUIPMENT_STATUSES.join(', ')}.`);
    }
    query.status = req.query.status;
  }
  if (req.user.role === 'service_head') {
    const serviceId = serviceIdFor(req.user);
    const hospitalId = hospitalIdFor(req.user);
    if (!serviceId || !hospitalId) {
      throw new HttpError(403, 'A hospital and service assignment are required.');
    }
    if (query.hospitalId) assertHospitalScope(req.user, query.hospitalId);
    query.hospitalId = hospitalId;
    query.serviceId = serviceId;
    query.operatingRoomId = null;
  } else if (req.user.role === 'operating_room_manager') {
    const hospitalId = hospitalIdFor(req.user);
    if (!hospitalId) throw new HttpError(403, 'A hospital assignment is required.');
    if (query.hospitalId && String(query.hospitalId) !== hospitalId) {
      assertHospitalScope(req.user, query.hospitalId);
    }
    const rooms = await OperatingRoom.find({ hospitalId }).select('_id');
    query.hospitalId = hospitalId;
    query.operatingRoomId = { $in: rooms.map((room) => room._id) };
    query.serviceId = null;
  }
  const equipment = await Equipment.find(query).select('+assetTag').sort({ name: 1 }).limit(500);
  return res.json({ equipment: equipment.map(equipmentResponse) });
}

async function createEquipment(req, res) {
  const body = requireObject(req.body);
  const allowed = [
    'hospitalId', 'serviceId', 'operatingRoomId', 'name', 'type', 'serialNumber',
    'status', 'lastMaintenanceAt', 'maintenanceDueAt',
  ];
  rejectUnknownFields(body, allowed);
  const fields = parseEquipmentFields(body, true);
  await validateEquipmentLocation(fields);
  await assertEquipmentScope(req.user, fields);
  const equipment = await Equipment.create({ ...fields, assetTag: fields.serialNumber });
  return res.status(201).json({ equipment: equipmentResponse(equipment) });
}

async function updateEquipment(req, res) {
  const id = requireId(req.params.id, 'equipment id');
  const body = requireObject(req.body);
  const allowed = [
    'hospitalId', 'serviceId', 'operatingRoomId', 'name', 'type', 'serialNumber',
    'status', 'lastMaintenanceAt', 'maintenanceDueAt',
  ];
  rejectUnknownFields(body, allowed);
  const current = await Equipment.findById(id).select('+assetTag');
  if (!current) throw new HttpError(404, 'Equipment not found.');
  await assertEquipmentScope(req.user, current);
  const fields = parseEquipmentFields(body);
  if (!Object.keys(fields).length) throw new HttpError(400, 'At least one field must be provided.');
  if (fields.serialNumber !== undefined) fields.assetTag = fields.serialNumber;
  await validateEquipmentLocation(fields, current);
  await assertEquipmentScope(req.user, {
    ...current.toObject(),
    ...fields,
    hospitalId: fields.hospitalId || current.hospitalId,
    serviceId: fields.serviceId === undefined ? current.serviceId : fields.serviceId,
    operatingRoomId: fields.operatingRoomId === undefined
      ? current.operatingRoomId
      : fields.operatingRoomId,
  });
  const nextStatus = fields.status || current.status;
  const assignmentChanged = (fields.serviceId !== undefined
      && String(fields.serviceId || '') !== String(idOf(current.serviceId) || ''))
    || (fields.operatingRoomId !== undefined
      && String(fields.operatingRoomId || '') !== String(idOf(current.operatingRoomId) || ''))
    || (fields.hospitalId !== undefined
      && String(fields.hospitalId) !== String(current.hospitalId));
  if ((nextStatus !== 'functional' || assignmentChanged) && await Equipment.exists({
    _id: id,
    'schedule.status': { $in: ACTIVE_STATUSES },
  })) {
    throw new HttpError(409, 'Equipment with scheduled interventions cannot change status or assignment.');
  }
  const update = { $set: fields };
  if (body.lastMaintenanceAt === null) {
    delete update.$set.lastMaintenanceAt;
    update.$unset = { lastMaintenanceAt: 1 };
  }
  if (body.maintenanceDueAt === null) {
    delete update.$set.maintenanceDueAt;
    update.$unset = { ...update.$unset, maintenanceDueAt: 1 };
  }
  const updateQuery = { _id: id };
  if (nextStatus !== 'functional' || assignmentChanged) {
    updateQuery.schedule = { $not: { $elemMatch: { status: { $in: ACTIVE_STATUSES } } } };
  }
  const equipment = await Equipment.findOneAndUpdate(
    updateQuery, update, { new: true, runValidators: true },
  ).select('+assetTag');
  if (!equipment) {
    if (!(await Equipment.exists({ _id: id }))) throw new HttpError(404, 'Equipment not found.');
    throw new HttpError(409, 'Equipment with scheduled interventions cannot change status or assignment.');
  }
  return res.json({ equipment: equipmentResponse(equipment) });
}

async function updateMaintenance(req, res) {
  const id = requireId(req.params.id, 'equipment id');
  const body = requireObject(req.body);
  rejectUnknownFields(body, ['status', 'lastMaintenanceAt', 'maintenanceDueAt']);
  const update = parseMaintenanceUpdate(body);
  const current = await Equipment.findById(id);
  if (!current) throw new HttpError(404, 'Equipment not found.');
  await assertEquipmentScope(req.user, current);
  const updateQuery = { _id: id };
  if (update.$set.status && update.$set.status !== 'functional') {
    updateQuery.schedule = { $not: { $elemMatch: { status: { $in: ACTIVE_STATUSES } } } };
  }
  const equipment = await Equipment.findOneAndUpdate(
    updateQuery,
    {
      ...(Object.keys(update.$set).length ? { $set: update.$set } : {}),
      ...(Object.keys(update.$unset).length ? { $unset: update.$unset } : {}),
    },
    { new: true, runValidators: true },
  ).select('+assetTag');
  if (!equipment) {
    if (!(await Equipment.exists({ _id: id }))) throw new HttpError(404, 'Equipment not found.');
    throw new HttpError(409, 'Equipment with scheduled interventions cannot become non-functional.');
  }
  return res.json({ equipment: equipmentResponse(equipment) });
}

async function deleteEquipment(req, res) {
  const id = requireId(req.params.id, 'equipment id');
  if (await Equipment.exists({ _id: id, 'schedule.status': { $in: ACTIVE_STATUSES } })) {
    throw new HttpError(409, 'Equipment assigned to an active intervention cannot be deleted.');
  }
  const equipment = await Equipment.findByIdAndDelete(id).select('+assetTag');
  if (!equipment) throw new HttpError(404, 'Equipment not found.');
  return res.json({ equipment: equipmentResponse(equipment) });
}

async function assertEquipmentScope(user, equipment) {
  if (user.role === 'admin') return;
  if (user.role === 'service_head') {
    if (equipment.operatingRoomId) {
      throw new HttpError(403, 'Equipment is outside your service.');
    }
    assertServiceScope(user, equipment.serviceId, equipment.hospitalId);
    return;
  }
  if (user.role === 'operating_room_manager') {
    if (equipment.serviceId || !equipment.operatingRoomId) {
      throw new HttpError(403, 'Only operating room equipment is in your scope.');
    }
    const room = await OperatingRoom.findById(equipment.operatingRoomId).select('hospitalId');
    if (!room) throw new HttpError(400, 'operatingRoomId does not exist.');
    assertHospitalScope(user, equipment.hospitalId);
    assertHospitalScope(user, room.hospitalId);
    return;
  }
  throw new HttpError(403, 'Action is not authorized.');
}

module.exports = {
  listOperatingRooms,
  createOperatingRoom,
  updateOperatingRoom,
  deleteOperatingRoom,
  listInterventions,
  createIntervention,
  updateIntervention,
  deleteIntervention,
  listEquipment,
  createEquipment,
  updateEquipment,
  updateMaintenance,
  deleteEquipment,
  operatingRoomResponse,
  interventionResponse,
  equipmentResponse,
  hasScheduleConflict,
  parseMaintenanceUpdate,
};
