const Appointment = require('../models/Appointment');
const Notification = require('../models/Notification');
const Shift = require('../models/Shift');
const User = require('../models/User');
const { HttpError } = require('../errors');
const {
  requireAppointmentStatus,
  requireDate,
  requireDateOnly,
  requireId,
  requireObject,
  requireString,
  rejectUnknownFields,
} = require('../utils/validation');

const SLOT_DURATION_MS = 30 * 60 * 1000;
const CLAIM_DURATION_MS = 15 * 60 * 1000;
const OVERDUE_AFTER_MS = 24 * 60 * 60 * 1000;
const ACTIVE_SLOT_STATUSES = ['pending', 'accepted', 'in_progress', 'proposed'];
const PATIENT_FIELDS = ['doctorId', 'startAt', 'reason'];
const SECRETARY_FIELDS = [...PATIENT_FIELDS, 'status'];
const PATIENT_UPDATE_FIELDS = [...PATIENT_FIELDS, 'status'];
const MANAGER_ROLES = ['admin', 'secretary'];
const STATUS_TRANSITIONS = {
  pending: ['accepted', 'rejected', 'proposed', 'cancelled'],
  accepted: ['in_progress', 'cancelled'],
  in_progress: ['cancelled'],
  proposed: ['cancelled'],
  rejected: [],
  cancelled: [],
};

function serviceIdsFor(user) {
  const ids = (user.serviceIds || []).map((id) => id.toString());
  if (user.serviceId) ids.push(user.serviceId.toString());
  return [...new Set(ids)];
}

function appointmentResponse(appointment) {
  const createdAt = appointment.createdAt || null;
  return {
    _id: appointment._id,
    patientId: appointment.patientId?._id || appointment.patientId,
    patientName: appointment.patientId?.username || '',
    doctorId: appointment.doctorId?._id || appointment.doctorId,
    doctorName: appointment.doctorId?.username || '',
    doctorSpecialty: appointment.doctorId?.specialty || '',
    doctorPhotoUrl: appointment.doctorId?.photoUrl || '',
    serviceId: appointment.doctorId?.serviceId?._id ||
      appointment.doctorId?.serviceId ||
      '',
    serviceName: appointment.doctorId?.serviceId?.name || '',
    serviceLocation: appointment.doctorId?.serviceId?.location || '',
    servicePhone: appointment.doctorId?.serviceId?.phone || '',
    serviceEmail: appointment.doctorId?.serviceId?.email || '',
    startAt: appointment.startAt,
    reason: appointment.reason || '',
    status: appointment.status,
    rejectionReason: appointment.rejectionReason || '',
    proposedStartAt: appointment.proposedStartAt || null,
    proposalNote: appointment.proposalNote || '',
    claimedBy: appointment.claimedBy?._id || appointment.claimedBy || null,
    claimedByName: appointment.claimedBy?.username || '',
    claimedAt: appointment.claimedAt || null,
    createdAt,
    isOverdue: appointment.status === 'pending' &&
      createdAt !== null &&
      Date.now() - new Date(createdAt).getTime() >= OVERDUE_AFTER_MS,
  };
}

async function populateAppointment(appointment) {
  await appointment.populate([
    { path: 'patientId', select: 'username' },
    {
      path: 'doctorId',
      select: 'username serviceId specialty photoUrl',
      populate: { path: 'serviceId', select: 'name location phone email' },
    },
    { path: 'claimedBy', select: 'username' },
  ]);
  return appointment;
}

async function notifyPatient(appointment, title, message) {
  await Notification.create({
    recipientId: appointment.patientId?._id || appointment.patientId,
    appointmentId: appointment._id,
    title,
    message,
  });
}

async function doctorIsBookable(doctorId) {
  return User.findOne({
    _id: doctorId,
    active: true,
    $or: [{ role: 'doctor' }, { roles: 'doctor' }],
  })
    .select('serviceId serviceIds')
    .populate('serviceId', 'name location phone email active a_rdv');
}

function generateAvailableSlots(
  shifts,
  appointments,
  dayStart,
  { excludeAppointmentId = null, now = Date.now() } = {},
) {
  const dayEnd = new Date(dayStart.getTime() + 24 * 60 * 60 * 1000);
  const busyIntervals = [];
  for (const appointment of appointments) {
    if (excludeAppointmentId &&
        appointment._id?.toString() === excludeAppointmentId.toString()) {
      continue;
    }
    if (appointment.status === 'proposed' && appointment.proposedStartAt) {
      busyIntervals.push(new Date(appointment.proposedStartAt).getTime());
    } else {
      busyIntervals.push(new Date(appointment.startAt).getTime());
    }
  }

  const slotTimes = new Set();
  for (const shift of shifts) {
    const shiftStart = Math.max(new Date(shift.start).getTime(), dayStart.getTime());
    const shiftEnd = Math.min(new Date(shift.end).getTime(), dayEnd.getTime());
    let slotStart = Math.ceil(shiftStart / SLOT_DURATION_MS) * SLOT_DURATION_MS;
    for (
      ;
      slotStart + SLOT_DURATION_MS <= shiftEnd && slotStart > now;
      slotStart += SLOT_DURATION_MS
    ) {
      const overlaps = busyIntervals.some(
        (busyStart) =>
          slotStart < busyStart + SLOT_DURATION_MS &&
          slotStart + SLOT_DURATION_MS > busyStart,
      );
      if (!overlaps) slotTimes.add(slotStart);
    }
  }
  return [...slotTimes].sort((a, b) => a - b).map((time) => new Date(time));
}

async function findAvailableSlots(doctorId, date, excludeAppointmentId = null) {
  const dayStart = requireDateOnly(date);
  const [shifts, appointments] = await Promise.all([
    Shift.find({
      userId: doctorId,
      start: { $lt: new Date(dayStart.getTime() + 24 * 60 * 60 * 1000) },
      end: { $gt: dayStart },
    }).select('start end'),
    Appointment.find({
      doctorId,
      status: { $in: ACTIVE_SLOT_STATUSES },
      ...(excludeAppointmentId ? { _id: { $ne: excludeAppointmentId } } : {}),
    }).select('startAt proposedStartAt status').limit(500),
  ]);
  return generateAvailableSlots(shifts, appointments, dayStart, {
    excludeAppointmentId,
  });
}

async function assertSlotAvailable(doctorId, startAt, excludeAppointmentId = null) {
  const date = startAt.toISOString().slice(0, 10);
  const slots = await findAvailableSlots(doctorId, date, excludeAppointmentId);
  if (!slots.some((slot) => slot.getTime() === startAt.getTime())) {
    throw new HttpError(409, 'The selected time is not an available 30-minute slot.');
  }
}

async function parseFields(body, {
  creating = false,
  secretary = false,
  patientUpdate = false,
} = {}) {
  const fields = {};
  const allowedFields = secretary
    ? SECRETARY_FIELDS
    : patientUpdate
      ? PATIENT_UPDATE_FIELDS
      : PATIENT_FIELDS;
  rejectUnknownFields(body, allowedFields);

  if (creating || body.doctorId !== undefined) {
    fields.doctorId = requireId(body.doctorId, 'doctorId');
    const doctor = await doctorIsBookable(fields.doctorId);
    if (!doctor ||
        !doctor.serviceId ||
        doctor.serviceId.active !== true ||
        doctor.serviceId.a_rdv !== true) {
      throw new HttpError(400, 'doctorId must refer to an active doctor in an active service.');
    }
  }
  if (creating || body.startAt !== undefined) {
    fields.startAt = requireDate(body.startAt, 'startAt');
    if (fields.startAt <= new Date()) {
      throw new HttpError(400, 'startAt must be in the future.');
    }
  }
  if (creating || body.reason !== undefined) {
    fields.reason = body.reason === undefined
      ? ''
      : requireString(body.reason, 'reason', { max: 500, min: 0 });
  }
  if ((secretary || patientUpdate) && body.status !== undefined) {
    fields.status = requireAppointmentStatus(body.status);
  }
  return fields;
}

async function listDoctors(req, res) {
  const filters = [
    { $or: [{ role: 'doctor' }, { roles: 'doctor' }] },
    { active: true },
  ];
  const requestedServiceId = req.query.serviceId === undefined
    ? null
    : requireId(req.query.serviceId, 'serviceId');
  if (req.user.role === 'secretary') {
    const ids = serviceIdsFor(req.user);
    if (requestedServiceId && !ids.includes(requestedServiceId)) {
      return res.json({ doctors: [] });
    }
    const assignedIds = requestedServiceId ? [requestedServiceId] : ids;
    filters.push({
      $or: [
        { serviceId: { $in: assignedIds } },
        { serviceIds: { $in: assignedIds } },
      ],
    });
  } else if (requestedServiceId) {
    filters.push({
      $or: [
        { serviceId: requestedServiceId },
        { serviceIds: requestedServiceId },
      ],
    });
  }
  const doctors = await User.find({ $and: filters })
    .select('username serviceId specialty photoUrl')
    .populate('serviceId', 'name location phone email active a_rdv')
    .sort({ username: 1 })
    .limit(200);
  return res.json({
    doctors: doctors.filter((doctor) =>
      doctor.serviceId?.active === true && doctor.serviceId?.a_rdv === true
    ).map((doctor) => ({
      _id: doctor._id,
      username: doctor.username,
      specialty: doctor.specialty || '',
      photoUrl: doctor.photoUrl || '',
      serviceId: doctor.serviceId?._id || doctor.serviceId || null,
      serviceName: doctor.serviceId?.name || '',
      serviceLocation: doctor.serviceId?.location || '',
      servicePhone: doctor.serviceId?.phone || '',
      serviceEmail: doctor.serviceId?.email || '',
    })),
  });
}

async function list(req, res) {
  const query = {};
  if (req.user.role === 'patient') query.patientId = req.user._id;
  if (req.user.role === 'doctor') query.doctorId = req.user._id;
  if (req.user.role === 'secretary') {
    const ids = serviceIdsFor(req.user);
    const doctors = ids.length
      ? await User.find({
          active: true,
          $and: [
            { $or: [{ role: 'doctor' }, { roles: 'doctor' }] },
            { $or: [{ serviceId: { $in: ids } }, { serviceIds: { $in: ids } }] },
          ],
        }).select('_id')
      : [];
    query.doctorId = { $in: doctors.map((doctor) => doctor._id) };
  }
  const appointments = await Appointment.find(query)
    .populate('patientId', 'username')
    .populate({
      path: 'doctorId',
      select: 'username serviceId specialty photoUrl',
      populate: { path: 'serviceId', select: 'name location phone email active a_rdv' },
    })
    .populate('claimedBy', 'username')
    .sort({ startAt: 1 })
    .limit(500);
  return res.json({ appointments: appointments.map(appointmentResponse) });
}

async function available(req, res) {
  const doctorId = requireId(req.query.doctorId, 'doctorId');
  const date = req.query.date;
  if (date === undefined) throw new HttpError(400, 'date is required.');
  await requireDateOnly(date);
  const doctor = await doctorIsBookable(doctorId);
  if (!doctor ||
      !doctor.serviceId ||
      doctor.serviceId.active !== true ||
      doctor.serviceId.a_rdv !== true) {
    throw new HttpError(404, 'Doctor not found.');
  }
  const doctorServiceId = doctor.serviceId._id?.toString() || doctor.serviceId.toString();
  if (req.user.role === 'secretary' &&
      !serviceIdsFor(req.user).includes(doctorServiceId)) {
    throw new HttpError(403, 'This doctor is outside your assigned services.');
  }
  const slots = await findAvailableSlots(doctorId, date);
  return res.json({ durationMinutes: SLOT_DURATION_MS / 60000, slots });
}

async function create(req, res) {
  const body = requireObject(req.body);
  const fields = await parseFields(body, { creating: true });
  await assertSlotAvailable(fields.doctorId, fields.startAt);
  let appointment;
  try {
    appointment = await Appointment.create({
      ...fields,
      patientId: req.user._id,
      status: 'pending',
      slotKey: fields.startAt.toISOString(),
    });
  } catch (error) {
    if (error?.code === 11000) {
      throw new HttpError(409, 'The selected time has just been booked.');
    }
    throw error;
  }
  await populateAppointment(appointment);
  await notifyPatient(
    appointment,
    'Demande de rendez-vous envoyée',
    'Votre demande est enregistrée et en attente de confirmation.',
  );
  return res.status(201).json({ appointment: appointmentResponse(appointment) });
}

function canAccessService(user, appointment) {
  if (user.role === 'admin') return true;
  if (user.role !== 'secretary') return false;
  const serviceId = appointment.doctorId?.serviceId?._id ||
    appointment.doctorId?.serviceId;
  return serviceIdsFor(user).includes(serviceId?.toString());
}

async function update(req, res) {
  const id = requireId(req.params.id, 'appointment id');
  const body = requireObject(req.body);
  const isSecretary = req.user.role === 'secretary';
  const isManager = MANAGER_ROLES.includes(req.user.role);
  const isPatient = req.user.role === 'patient';
  const fields = await parseFields(body, {
    secretary: isManager,
    patientUpdate: isPatient,
  });
  if (!Object.keys(fields).length) {
    throw new HttpError(400, 'At least one field must be provided.');
  }

  const current = await Appointment.findById(id).populate({
    path: 'doctorId',
    select: 'serviceId',
    populate: { path: 'serviceId', select: 'name' },
  });
  if (!current) throw new HttpError(404, 'Appointment not found.');
  if (isPatient && current.patientId.toString() !== req.user._id.toString()) {
    throw new HttpError(404, 'Appointment not found.');
  }
  if (isSecretary && !canAccessService(req.user, current)) {
    throw new HttpError(404, 'Appointment not found.');
  }
  if (current.status === 'cancelled' || current.status === 'rejected') {
    throw new HttpError(409, 'This appointment can no longer be modified.');
  }
  if (fields.status !== undefined) {
    if (isManager &&
        current.status === 'pending' &&
        fields.status === 'accepted' &&
        current.startAt <= new Date()) {
      throw new HttpError(409, 'An elapsed request must be rescheduled or rejected.');
    }
    if (fields.status === 'cancelled' && Object.keys(fields).length > 1) {
      throw new HttpError(400, 'Cancellation cannot be combined with other changes.');
    }
    if (isPatient &&
        (fields.status !== 'cancelled' || current.startAt <= new Date())) {
      throw new HttpError(409, 'Patients can only cancel future appointments.');
    }
    if (isSecretary && current.status === 'pending' &&
        (current.claimedBy?.toString() !== req.user._id.toString() ||
         !current.claimedAt ||
         current.claimedAt < new Date(Date.now() - CLAIM_DURATION_MS))) {
      throw new HttpError(409, 'Claim this request before managing it.');
    }
    if (isManager &&
        (!STATUS_TRANSITIONS[current.status].includes(fields.status) ||
         ['rejected', 'proposed'].includes(fields.status))) {
      throw new HttpError(
        409,
        'Use the decision endpoint to reject a request or propose a new time.',
      );
    }
  }

  const doctorId = fields.doctorId || current.doctorId._id;
  if (fields.startAt || fields.doctorId) {
    const startAt = fields.startAt || current.startAt;
    if (startAt <= new Date()) {
      throw new HttpError(400, 'startAt must be in the future.');
    }
    const doctor = await doctorIsBookable(doctorId);
    if (!doctor ||
        !doctor.serviceId ||
        doctor.serviceId.active !== true ||
        doctor.serviceId.a_rdv !== true) {
      throw new HttpError(409, 'The selected doctor or service is no longer active.');
    }
    await assertSlotAvailable(doctorId, startAt, current._id);
    fields.slotKey = startAt.toISOString();
  }
  const updateDocument = { $set: fields };
  if (fields.status === 'cancelled') {
    updateDocument.$unset = {
      slotKey: 1,
      proposedStartAt: 1,
      proposalNote: 1,
    };
    fields.claimedBy = null;
    fields.claimedAt = null;
  }
  if (isManager && fields.status !== undefined && fields.status !== 'pending') {
    fields.claimedBy = null;
    fields.claimedAt = null;
  }
  const appointment = await Appointment.findByIdAndUpdate(
    id,
    updateDocument,
    { new: true, runValidators: true },
  );
  if (!appointment) throw new HttpError(404, 'Appointment not found.');
  await populateAppointment(appointment);
  const dateChanged = fields.startAt !== undefined || fields.doctorId !== undefined;
  if (fields.status !== undefined || dateChanged) {
    await notifyPatient(
      appointment,
      'Mise à jour de votre rendez-vous',
      fields.status === 'cancelled'
        ? 'Votre rendez-vous a été annulé.'
        : dateChanged
          ? 'La date ou le médecin de votre rendez-vous a été modifié.'
          : `Le statut de votre rendez-vous est maintenant « ${appointment.status} ».`,
    );
  }
  return res.json({ appointment: appointmentResponse(appointment) });
}

async function claim(req, res) {
  if (!MANAGER_ROLES.includes(req.user.role)) {
    throw new HttpError(403, 'Only secretaries and administrators can claim requests.');
  }
  const id = requireId(req.params.id, 'appointment id');
  const current = await Appointment.findById(id).populate({
    path: 'doctorId',
    select: 'serviceId',
    populate: { path: 'serviceId', select: 'name' },
  });
  if (!current) throw new HttpError(404, 'Appointment not found.');
  if (req.user.role === 'secretary' && !canAccessService(req.user, current)) {
    throw new HttpError(404, 'Appointment not found.');
  }
  const expiredBefore = new Date(Date.now() - CLAIM_DURATION_MS);
  const appointment = await Appointment.findOneAndUpdate(
    {
      _id: id,
      status: 'pending',
      doctorId: current.doctorId._id,
      $or: [
        { claimedBy: null },
        { claimedBy: { $exists: false } },
        { claimedBy: req.user._id },
        { claimedAt: { $lt: expiredBefore } },
      ],
    },
    { $set: { claimedBy: req.user._id, claimedAt: new Date() } },
    { new: true },
  );
  if (!appointment) {
    throw new HttpError(409, 'This request is already being handled or is no longer pending.');
  }
  await populateAppointment(appointment);
  return res.json({ appointment: appointmentResponse(appointment) });
}

async function release(req, res) {
  const id = requireId(req.params.id, 'appointment id');
  const current = await Appointment.findById(id).populate({
    path: 'doctorId',
    select: 'serviceId',
    populate: { path: 'serviceId', select: 'name' },
  });
  if (!current) throw new HttpError(404, 'Appointment not found.');
  if (req.user.role === 'secretary' && !canAccessService(req.user, current)) {
    throw new HttpError(404, 'Appointment not found.');
  }
  const filter = { _id: id, status: 'pending' };
  if (req.user.role === 'secretary') {
    filter.claimedBy = req.user._id;
    filter.doctorId = current.doctorId._id;
  }
  else if (req.user.role !== 'admin') {
    throw new HttpError(403, 'Only secretaries and administrators can release requests.');
  }
  const appointment = await Appointment.findOneAndUpdate(
    filter,
    { $set: { claimedBy: null, claimedAt: null } },
    { new: true },
  );
  if (!appointment) throw new HttpError(404, 'Claimed request not found.');
  await populateAppointment(appointment);
  return res.json({ appointment: appointmentResponse(appointment) });
}

async function decide(req, res) {
  const id = requireId(req.params.id, 'appointment id');
  const body = requireObject(req.body);
  rejectUnknownFields(body, ['action', 'reason', 'proposedStartAt']);
  const action = requireString(body.action, 'action', { max: 20 });
  if (!['accept', 'reject', 'propose'].includes(action)) {
    throw new HttpError(400, 'action must be accept, reject, or propose.');
  }
  const current = await Appointment.findById(id).populate({
    path: 'doctorId',
    select: 'serviceId',
    populate: { path: 'serviceId', select: 'name' },
  });
  if (!current) throw new HttpError(404, 'Appointment not found.');
  if (req.user.role === 'secretary' && !canAccessService(req.user, current)) {
    throw new HttpError(404, 'Appointment not found.');
  }
  if (current.status !== 'pending') {
    throw new HttpError(409, 'Only pending requests can be managed.');
  }
  if (req.user.role === 'secretary' &&
      (current.claimedBy?.toString() !== req.user._id.toString() ||
       !current.claimedAt ||
       current.claimedAt < new Date(Date.now() - CLAIM_DURATION_MS))) {
    throw new HttpError(409, 'Claim this request before managing it.');
  }

  const fields = { claimedBy: null, claimedAt: null };
  const unset = { proposedStartAt: 1, proposalNote: 1 };
  let title;
  let message;
  if (action === 'accept') {
    if (current.startAt <= new Date()) {
      throw new HttpError(409, 'An elapsed request must be rescheduled or rejected.');
    }
    fields.status = 'accepted';
    title = 'Rendez-vous confirmé';
    message = 'Votre demande de rendez-vous a été confirmée.';
  } else if (action === 'reject') {
    fields.status = 'rejected';
    fields.rejectionReason = requireString(body.reason, 'reason', { max: 500 });
    unset.slotKey = 1;
    title = 'Demande de rendez-vous refusée';
    message = `Votre demande a été refusée. Motif : ${fields.rejectionReason}`;
  } else {
    fields.status = 'proposed';
    fields.proposedStartAt = requireDate(body.proposedStartAt, 'proposedStartAt');
    if (fields.proposedStartAt <= new Date()) {
      throw new HttpError(400, 'proposedStartAt must be in the future.');
    }
    if (fields.proposedStartAt.getTime() === current.startAt.getTime()) {
      throw new HttpError(400, 'The proposed time must differ from the requested time.');
    }
    fields.proposalNote = body.reason === undefined
      ? ''
      : requireString(body.reason, 'reason', { max: 500, min: 0 });
    await assertSlotAvailable(
      current.doctorId._id,
      fields.proposedStartAt,
      current._id,
    );
    fields.slotKey = fields.proposedStartAt.toISOString();
    title = 'Nouveau créneau proposé';
    message = `Un autre créneau vous est proposé : ${fields.proposedStartAt.toISOString()}.`;
  }

  let appointment;
  try {
    appointment = await Appointment.findOneAndUpdate(
      {
        _id: id,
        status: 'pending',
        doctorId: current.doctorId._id,
        ...(req.user.role === 'secretary'
          ? {
              claimedBy: req.user._id,
              claimedAt: { $gte: new Date(Date.now() - CLAIM_DURATION_MS) },
            }
          : {}),
      },
      { $set: fields, $unset: unset },
      { new: true, runValidators: true },
    );
  } catch (error) {
    if (error?.code === 11000) {
      throw new HttpError(409, 'The selected time has just been booked.');
    }
    throw error;
  }
  if (!appointment) throw new HttpError(409, 'This request is no longer available.');
  await populateAppointment(appointment);
  await notifyPatient(appointment, title, message);
  return res.json({ appointment: appointmentResponse(appointment) });
}

async function respondToProposal(req, res) {
  const id = requireId(req.params.id, 'appointment id');
  const body = requireObject(req.body);
  rejectUnknownFields(body, ['action']);
  const action = requireString(body.action, 'action', { max: 20 });
  if (!['accept', 'reject'].includes(action)) {
    throw new HttpError(400, 'action must be accept or reject.');
  }
  const current = await Appointment.findOne({
    _id: id,
    patientId: req.user._id,
    status: 'proposed',
  });
  if (!current) throw new HttpError(404, 'Proposed appointment not found.');
  if (action === 'accept' && current.proposedStartAt <= new Date()) {
    throw new HttpError(409, 'The proposed time has passed; refuse it and request a new slot.');
  }
  const updateDocument = action === 'accept'
    ? {
        $set: {
          startAt: current.proposedStartAt,
          slotKey: current.slotKey,
          status: 'accepted',
        },
        $unset: { proposedStartAt: 1, proposalNote: 1 },
      }
    : {
        $set: { status: 'cancelled' },
        $unset: {
          slotKey: 1,
          proposedStartAt: 1,
          proposalNote: 1,
        },
      };
  const appointment = await Appointment.findOneAndUpdate(
    { _id: id, patientId: req.user._id, status: 'proposed' },
    updateDocument,
    { new: true, runValidators: true },
  );
  if (!appointment) throw new HttpError(409, 'This proposal is no longer available.');
  await populateAppointment(appointment);
  await notifyPatient(
    appointment,
    action === 'accept' ? 'Rendez-vous confirmé' : 'Proposition refusée',
    action === 'accept'
      ? 'Vous avez accepté le nouveau créneau. Votre rendez-vous est confirmé.'
      : 'Vous avez refusé le créneau proposé. La demande est annulée.',
  );
  return res.json({ appointment: appointmentResponse(appointment) });
}

module.exports = {
  listDoctors,
  list,
  available,
  create,
  update,
  claim,
  release,
  decide,
  respondToProposal,
  appointmentResponse,
  findAvailableSlots,
  generateAvailableSlots,
  STATUS_TRANSITIONS,
  SLOT_DURATION_MS,
  CLAIM_DURATION_MS,
  OVERDUE_AFTER_MS,
};
