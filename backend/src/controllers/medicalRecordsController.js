const MedicalRecord = require('../models/MedicalRecord');
const Consultation = require('../models/Consultation');
const VitalSign = require('../models/VitalSign');
const Prescription = require('../models/Prescription');
const Appointment = require('../models/Appointment');
const User = require('../models/User');
const { HttpError } = require('../errors');
const {
  requireId,
  requireObject,
  requireString,
  rejectUnknownFields,
} = require('../utils/validation');

const { BLOOD_TYPES, ALLERGY_SEVERITIES } = MedicalRecord;
const { VITAL_LIMITS } = VitalSign;
const VITAL_FIELDS = Object.keys(VITAL_LIMITS);
const MAX_LIST_ITEMS = 50;
const PATIENT_FIELDS = 'username firstName lastName email birthDate phone '
  + 'emergencyContact insurance allergies photoUrl role roles active';
const PERSON_FIELDS = 'username firstName lastName specialty';

// ---------------------------------------------------------------------------
// Réponses
// ---------------------------------------------------------------------------

function displayName(user) {
  if (!user) return '';
  const full = [user.firstName, user.lastName].filter(Boolean).join(' ').trim();
  return full || user.username || '';
}

function personSummary(user) {
  if (!user || !user._id) return { _id: user || null, name: '' };
  return { _id: user._id, name: displayName(user), specialty: user.specialty || '' };
}

function patientResponse(user) {
  return {
    _id: user._id,
    displayName: displayName(user),
    email: user.email,
    birthDate: user.birthDate || null,
    phone: user.phone || '',
    emergencyContact: user.emergencyContact || '',
    insurance: user.insurance || '',
    photoUrl: user.photoUrl || '',
  };
}

function mergeAllergies(recordAllergies = [], declared = []) {
  const allergies = recordAllergies.map((allergy) => ({
    name: allergy.name,
    severity: allergy.severity,
    reaction: allergy.reaction || '',
    source: 'record',
  }));
  const known = new Set(allergies.map((allergy) => allergy.name.toLowerCase()));
  for (const name of declared) {
    const trimmed = String(name || '').trim();
    if (!trimmed || known.has(trimmed.toLowerCase())) continue;
    known.add(trimmed.toLowerCase());
    allergies.push({ name: trimmed, severity: null, reaction: '', source: 'patient' });
  }
  return allergies;
}

function medicalRecordResponse(record, patient) {
  const source = record || {};
  return {
    exists: Boolean(record),
    patientId: patient?._id || source.patientId || null,
    bloodType: source.bloodType || 'unknown',
    heightCm: source.heightCm ?? null,
    allergies: mergeAllergies(source.allergies, patient?.allergies),
    chronicConditions: (source.chronicConditions || []).map((item) => ({
      name: item.name, since: item.since || null, notes: item.notes || '',
    })),
    history: {
      medical: [...(source.history?.medical || [])],
      surgical: [...(source.history?.surgical || [])],
      family: [...(source.history?.family || [])],
    },
    currentTreatments: (source.currentTreatments || []).map((item) => ({
      name: item.name,
      dosage: item.dosage || '',
      frequency: item.frequency || '',
      startedAt: item.startedAt || null,
    })),
    vaccinations: (source.vaccinations || []).map((item) => ({
      name: item.name, date: item.date || null,
    })),
    updatedAt: source.updatedAt || null,
  };
}

function consultationResponse(consultation) {
  return {
    _id: consultation._id,
    patientId: consultation.patientId,
    doctor: personSummary(consultation.doctorId),
    appointmentId: consultation.appointmentId || null,
    date: consultation.date,
    reason: consultation.reason,
    symptoms: consultation.symptoms || '',
    examination: consultation.examination || '',
    diagnosis: consultation.diagnosis || '',
    notes: consultation.notes || '',
    followUpAt: consultation.followUpAt || null,
    createdAt: consultation.createdAt || null,
  };
}

function vitalResponse(vital) {
  const response = {
    _id: vital._id,
    patientId: vital.patientId,
    recordedBy: personSummary(vital.recordedBy),
    recordedAt: vital.recordedAt,
    notes: vital.notes || '',
  };
  for (const field of VITAL_FIELDS) response[field] = vital[field] ?? null;
  return response;
}

function prescriptionSummary(prescription) {
  return {
    _id: prescription._id,
    doctor: personSummary(prescription.doctorId),
    status: prescription.status,
    medications: (prescription.medications || []).map((item) => ({
      name: item.name, dosage: item.dosage, quantity: item.quantity,
    })),
    createdAt: prescription.createdAt,
  };
}

function appointmentSummary(appointment) {
  return {
    _id: appointment._id,
    doctor: personSummary(appointment.doctorId),
    startAt: appointment.startAt,
    reason: appointment.reason || '',
    status: appointment.status,
  };
}

// ---------------------------------------------------------------------------
// Validation
// ---------------------------------------------------------------------------

function optionalString(value, field, max) {
  if (value === undefined || value === null) return '';
  return requireString(value, field, { min: 0, max });
}

function optionalDate(value, field) {
  if (value === undefined || value === null || value === '') return null;
  if (typeof value !== 'string' || Number.isNaN(Date.parse(value))) {
    throw new HttpError(400, `${field} must be a valid date.`);
  }
  return new Date(value);
}

function requireList(value, field) {
  if (!Array.isArray(value)) throw new HttpError(400, `${field} must be an array.`);
  if (value.length > MAX_LIST_ITEMS) {
    throw new HttpError(400, `${field} must contain at most ${MAX_LIST_ITEMS} items.`);
  }
  return value;
}

function parseItems(value, field, allowed, parseItem) {
  return requireList(value, field).map((item, index) => {
    const label = `${field}[${index}]`;
    requireObject(item, label);
    rejectUnknownFields(item, allowed);
    return parseItem(item, label);
  });
}

function parseStringList(value, field) {
  return requireList(value, field).map((item, index) => (
    requireString(item, `${field}[${index}]`, { max: 240 })
  ));
}

const RECORD_FIELDS = [
  'bloodType', 'heightCm', 'allergies', 'chronicConditions', 'history',
  'currentTreatments', 'vaccinations',
];

function parseRecordUpdate(body) {
  requireObject(body);
  rejectUnknownFields(body, RECORD_FIELDS);
  const update = {};
  if (body.bloodType !== undefined) {
    if (!BLOOD_TYPES.includes(body.bloodType)) {
      throw new HttpError(400, `bloodType must be one of: ${BLOOD_TYPES.join(', ')}.`);
    }
    update.bloodType = body.bloodType;
  }
  if (body.heightCm !== undefined) {
    if (body.heightCm !== null
      && (typeof body.heightCm !== 'number' || body.heightCm < 30 || body.heightCm > 260)) {
      throw new HttpError(400, 'heightCm must be a number between 30 and 260.');
    }
    update.heightCm = body.heightCm;
  }
  if (body.allergies !== undefined) {
    update.allergies = parseItems(
      body.allergies, 'allergies', ['name', 'severity', 'reaction'], (item, label) => {
        const severity = item.severity ?? 'moderate';
        if (!ALLERGY_SEVERITIES.includes(severity)) {
          throw new HttpError(400, `${label}.severity must be one of: ${ALLERGY_SEVERITIES.join(', ')}.`);
        }
        return {
          name: requireString(item.name, `${label}.name`, { max: 120 }),
          severity,
          reaction: optionalString(item.reaction, `${label}.reaction`, 240),
        };
      },
    );
  }
  if (body.chronicConditions !== undefined) {
    update.chronicConditions = parseItems(
      body.chronicConditions, 'chronicConditions', ['name', 'since', 'notes'], (item, label) => ({
        name: requireString(item.name, `${label}.name`, { max: 160 }),
        since: optionalDate(item.since, `${label}.since`),
        notes: optionalString(item.notes, `${label}.notes`, 500),
      }),
    );
  }
  if (body.history !== undefined) {
    requireObject(body.history, 'history');
    rejectUnknownFields(body.history, ['medical', 'surgical', 'family']);
    update.history = {
      medical: parseStringList(body.history.medical ?? [], 'history.medical'),
      surgical: parseStringList(body.history.surgical ?? [], 'history.surgical'),
      family: parseStringList(body.history.family ?? [], 'history.family'),
    };
  }
  if (body.currentTreatments !== undefined) {
    update.currentTreatments = parseItems(
      body.currentTreatments,
      'currentTreatments',
      ['name', 'dosage', 'frequency', 'startedAt'],
      (item, label) => ({
        name: requireString(item.name, `${label}.name`, { max: 160 }),
        dosage: optionalString(item.dosage, `${label}.dosage`, 120),
        frequency: optionalString(item.frequency, `${label}.frequency`, 120),
        startedAt: optionalDate(item.startedAt, `${label}.startedAt`),
      }),
    );
  }
  if (body.vaccinations !== undefined) {
    update.vaccinations = parseItems(
      body.vaccinations, 'vaccinations', ['name', 'date'], (item, label) => ({
        name: requireString(item.name, `${label}.name`, { max: 160 }),
        date: optionalDate(item.date, `${label}.date`),
      }),
    );
  }
  if (!Object.keys(update).length) {
    throw new HttpError(400, 'At least one medical record field is required.');
  }
  return update;
}

const CONSULTATION_FIELDS = [
  'date', 'reason', 'symptoms', 'examination', 'diagnosis', 'notes',
  'followUpAt', 'appointmentId',
];

function parseConsultation(body, { partial = false } = {}) {
  requireObject(body);
  rejectUnknownFields(body, CONSULTATION_FIELDS);
  const data = {};
  if (!partial || body.date !== undefined) {
    data.date = optionalDate(body.date, 'date') || new Date();
  }
  if (!partial || body.reason !== undefined) {
    data.reason = requireString(body.reason, 'reason', { max: 240 });
  }
  const texts = { symptoms: 1000, examination: 1000, diagnosis: 500, notes: 2000 };
  for (const [field, max] of Object.entries(texts)) {
    if (!partial || body[field] !== undefined) data[field] = optionalString(body[field], field, max);
  }
  if (!partial || body.followUpAt !== undefined) {
    data.followUpAt = optionalDate(body.followUpAt, 'followUpAt');
  }
  if (body.appointmentId !== undefined && body.appointmentId !== null) {
    data.appointmentId = requireId(body.appointmentId, 'appointmentId');
  }
  if (partial && !Object.keys(data).length) {
    throw new HttpError(400, 'At least one consultation field is required.');
  }
  return data;
}

function parseVitals(body) {
  requireObject(body);
  rejectUnknownFields(body, [...VITAL_FIELDS, 'recordedAt', 'notes']);
  const data = {
    recordedAt: optionalDate(body.recordedAt, 'recordedAt') || new Date(),
    notes: optionalString(body.notes, 'notes', 500),
  };
  if (data.recordedAt.getTime() > Date.now() + 5 * 60 * 1000) {
    throw new HttpError(400, 'recordedAt cannot be in the future.');
  }
  let measures = 0;
  for (const field of VITAL_FIELDS) {
    const value = body[field];
    if (value === undefined || value === null) continue;
    const { min, max } = VITAL_LIMITS[field];
    if (typeof value !== 'number' || !Number.isFinite(value) || value < min || value > max) {
      throw new HttpError(400, `${field} must be a number between ${min} and ${max}.`);
    }
    data[field] = value;
    measures += 1;
  }
  if (!measures) throw new HttpError(400, 'At least one vital sign measurement is required.');
  if ((data.systolic === undefined) !== (data.diastolic === undefined)) {
    throw new HttpError(400, 'systolic and diastolic must be provided together.');
  }
  if (data.systolic !== undefined && data.diastolic >= data.systolic) {
    throw new HttpError(400, 'diastolic must be lower than systolic.');
  }
  return data;
}

// ---------------------------------------------------------------------------
// Accès
// ---------------------------------------------------------------------------

function isPatientAccount(user) {
  return user.role === 'patient' || (user.roles || []).includes('patient');
}

function assertCanReadRecord(user, patientId) {
  if (user.role === 'patient' && user._id.toString() !== patientId.toString()) {
    throw new HttpError(403, 'You can only view your own medical record.');
  }
}

async function findPatient(patientId) {
  const patient = await User.findById(requireId(patientId, 'patientId')).select(PATIENT_FIELDS);
  if (!patient || !isPatientAccount(patient) || !patient.active) {
    throw new HttpError(404, 'Patient not found.');
  }
  return patient;
}

function escapeRegex(value) {
  return value.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
}

// ---------------------------------------------------------------------------
// Contrôleurs
// ---------------------------------------------------------------------------

async function searchPatients(req, res) {
  const query = { active: true, $or: [{ role: 'patient' }, { roles: 'patient' }] };
  if (req.query.q !== undefined && String(req.query.q).trim()) {
    const term = requireString(String(req.query.q), 'q', { max: 80 });
    const pattern = new RegExp(escapeRegex(term), 'i');
    query.$and = [{
      $or: [
        { username: pattern }, { firstName: pattern }, { lastName: pattern }, { email: pattern },
      ],
    }];
  }
  const patients = await User.find(query)
    .select(PATIENT_FIELDS)
    .sort({ lastName: 1, firstName: 1, username: 1 })
    .limit(40);
  const ids = patients.map((patient) => patient._id);
  const [records, lastConsultations] = await Promise.all([
    MedicalRecord.find({ patientId: { $in: ids } }),
    Consultation.aggregate([
      { $match: { patientId: { $in: ids } } },
      { $group: { _id: '$patientId', lastAt: { $max: '$date' }, count: { $sum: 1 } } },
    ]),
  ]);
  const recordsById = new Map(records.map((record) => [record.patientId.toString(), record]));
  const consultationsById = new Map(
    lastConsultations.map((item) => [item._id.toString(), item]),
  );
  res.json({
    patients: patients.map((patient) => {
      const record = recordsById.get(patient._id.toString());
      const allergies = mergeAllergies(record?.allergies, patient.allergies);
      const consultations = consultationsById.get(patient._id.toString());
      return {
        ...patientResponse(patient),
        hasRecord: Boolean(record),
        bloodType: record?.bloodType || 'unknown',
        allergyCount: allergies.length,
        hasSevereAllergy: allergies.some((allergy) => allergy.severity === 'severe'),
        chronicConditionCount: record?.chronicConditions?.length || 0,
        consultationCount: consultations?.count || 0,
        lastConsultationAt: consultations?.lastAt || null,
      };
    }),
  });
}

async function buildFullRecord(patient) {
  const [record, consultations, vitals, prescriptions, appointments] = await Promise.all([
    MedicalRecord.findOne({ patientId: patient._id }),
    Consultation.find({ patientId: patient._id })
      .populate('doctorId', PERSON_FIELDS)
      .sort({ date: -1 })
      .limit(100),
    VitalSign.find({ patientId: patient._id })
      .populate('recordedBy', PERSON_FIELDS)
      .sort({ recordedAt: 1 })
      .limit(300),
    Prescription.find({ patientId: patient._id })
      .populate('doctorId', PERSON_FIELDS)
      .sort({ createdAt: -1 })
      .limit(50),
    Appointment.find({ patientId: patient._id })
      .populate('doctorId', PERSON_FIELDS)
      .sort({ startAt: -1 })
      .limit(30),
  ]);
  return {
    patient: patientResponse(patient),
    record: medicalRecordResponse(record, patient),
    consultations: consultations.map(consultationResponse),
    vitals: vitals.map(vitalResponse),
    prescriptions: prescriptions.map(prescriptionSummary),
    appointments: appointments.map(appointmentSummary),
  };
}

async function getMine(req, res) {
  const patient = await findPatient(req.user._id.toString());
  res.json(await buildFullRecord(patient));
}

async function getRecord(req, res) {
  assertCanReadRecord(req.user, req.params.patientId);
  const patient = await findPatient(req.params.patientId);
  res.json(await buildFullRecord(patient));
}

async function updateRecord(req, res) {
  const patient = await findPatient(req.params.patientId);
  const update = parseRecordUpdate(req.body);
  const record = await MedicalRecord.findOneAndUpdate(
    { patientId: patient._id },
    { $set: { ...update, updatedBy: req.user._id }, $setOnInsert: { patientId: patient._id } },
    { new: true, upsert: true, runValidators: true },
  );
  res.json({ record: medicalRecordResponse(record, patient) });
}

async function createConsultation(req, res) {
  const patient = await findPatient(req.params.patientId);
  const data = parseConsultation(req.body);
  const consultation = await Consultation.create({
    ...data,
    patientId: patient._id,
    doctorId: req.user._id,
  });
  await consultation.populate('doctorId', PERSON_FIELDS);
  res.status(201).json({ consultation: consultationResponse(consultation) });
}

async function updateConsultation(req, res) {
  const consultation = await Consultation.findById(requireId(req.params.id, 'id'));
  if (!consultation) throw new HttpError(404, 'Consultation not found.');
  if (consultation.doctorId.toString() !== req.user._id.toString()) {
    throw new HttpError(403, 'Only the author can edit this consultation.');
  }
  Object.assign(consultation, parseConsultation(req.body, { partial: true }));
  await consultation.save();
  await consultation.populate('doctorId', PERSON_FIELDS);
  res.json({ consultation: consultationResponse(consultation) });
}

async function createVitals(req, res) {
  const patient = await findPatient(req.params.patientId);
  const data = parseVitals(req.body);
  const vital = await VitalSign.create({
    ...data,
    patientId: patient._id,
    recordedBy: req.user._id,
  });
  await vital.populate('recordedBy', PERSON_FIELDS);
  res.status(201).json({ vital: vitalResponse(vital) });
}

module.exports = {
  assertCanReadRecord,
  consultationResponse,
  createConsultation,
  createVitals,
  getMine,
  getRecord,
  medicalRecordResponse,
  mergeAllergies,
  parseConsultation,
  parseRecordUpdate,
  parseVitals,
  searchPatients,
  updateConsultation,
  updateRecord,
  vitalResponse,
};
