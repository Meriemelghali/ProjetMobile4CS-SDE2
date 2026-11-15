const test = require('node:test');
const assert = require('node:assert/strict');
const { once } = require('node:events');
const mongoose = require('mongoose');
const app = require('../src/app');
const { authorize } = require('../src/middleware/authorize');
const {
  assertCanReadRecord,
  consultationResponse,
  medicalRecordResponse,
  mergeAllergies,
  parseConsultation,
  parseRecordUpdate,
  parseVitals,
  vitalResponse,
} = require('../src/controllers/medicalRecordsController');
const MedicalRecord = require('../src/models/MedicalRecord');
const VitalSign = require('../src/models/VitalSign');

const id = () => new mongoose.Types.ObjectId();

function runAuthorize(roles, role) {
  let result;
  authorize(...roles)({ user: { role } }, {}, (error) => { result = error; });
  return result;
}

test('medical record routes restrict content to clinicians and the patient', () => {
  // Lecture : médecin, infirmier, patient. Écriture du dossier : médecin seul.
  for (const role of ['admin', 'secretary', 'pharmacist', 'service_head']) {
    assert.equal(runAuthorize(['doctor', 'nurse', 'patient'], role)?.status, 403);
  }
  assert.equal(runAuthorize(['doctor'], 'nurse')?.status, 403);
  assert.equal(runAuthorize(['doctor', 'nurse'], 'nurse'), undefined);
  assert.equal(runAuthorize(['doctor'], 'doctor'), undefined);
});

test('a patient can only read their own medical record', () => {
  const patientId = id();
  const patient = { _id: patientId, role: 'patient' };
  assert.doesNotThrow(() => assertCanReadRecord(patient, patientId.toString()));
  assert.throws(
    () => assertCanReadRecord(patient, id().toString()),
    (error) => error.status === 403,
  );
  assert.doesNotThrow(() => assertCanReadRecord({ _id: id(), role: 'doctor' }, patientId.toString()));
});

test('medical record endpoints require bearer authentication', async (t) => {
  const server = app.listen(0);
  await once(server, 'listening');
  t.after(() => server.close());
  const base = `http://127.0.0.1:${server.address().port}/medical-records`;
  for (const path of ['/patients', '/me', `/${id()}`]) {
    const response = await fetch(`${base}${path}`);
    assert.equal(response.status, 401, path);
  }
});

test('record allergies merge with patient-declared allergies without duplicates', () => {
  const allergies = mergeAllergies(
    [{ name: 'Pénicilline', severity: 'severe', reaction: 'Œdème' }],
    ['pénicilline', 'Pollen', ' '],
  );
  assert.deepEqual(allergies, [
    { name: 'Pénicilline', severity: 'severe', reaction: 'Œdème', source: 'record' },
    { name: 'Pollen', severity: null, reaction: '', source: 'patient' },
  ]);
});

test('an empty record response is complete and marked as not created', () => {
  const patient = { _id: id(), allergies: ['Arachide'] };
  const response = medicalRecordResponse(null, patient);
  assert.equal(response.exists, false);
  assert.equal(response.bloodType, 'unknown');
  assert.deepEqual(response.history, { medical: [], surgical: [], family: [] });
  assert.equal(response.allergies[0].source, 'patient');
});

test('record updates validate blood type, severities and list sizes', () => {
  const update = parseRecordUpdate({
    bloodType: 'O+',
    heightCm: 172,
    allergies: [{ name: 'Latex', severity: 'mild' }],
    history: { surgical: ['Appendicectomie (2015)'] },
    vaccinations: [{ name: 'Tétanos', date: '2022-03-01' }],
  });
  assert.equal(update.bloodType, 'O+');
  assert.equal(update.allergies[0].reaction, '');
  assert.deepEqual(update.history.medical, []);
  assert.ok(update.vaccinations[0].date instanceof Date);

  assert.throws(() => parseRecordUpdate({ bloodType: 'Z' }), /bloodType/);
  assert.throws(() => parseRecordUpdate({ allergies: [{ name: 'X', severity: 'fatal' }] }), /severity/);
  assert.throws(() => parseRecordUpdate({ allergies: Array(51).fill({ name: 'X' }) }), /at most/);
  assert.throws(() => parseRecordUpdate({ notes: 'x' }), /Unsupported/);
  assert.throws(() => parseRecordUpdate({}), /At least one/);
});

test('consultations require a reason and accept partial edits', () => {
  const created = parseConsultation({ reason: 'Douleur thoracique', diagnosis: 'Angor stable' });
  assert.ok(created.date instanceof Date);
  assert.equal(created.followUpAt, null);
  assert.throws(() => parseConsultation({ diagnosis: 'x' }), /reason/);
  assert.deepEqual(parseConsultation({ notes: 'RAS' }, { partial: true }), { notes: 'RAS' });
  assert.throws(() => parseConsultation({}, { partial: true }), /At least one/);
});

test('vital signs reject impossible values but keep abnormal ones', () => {
  const vitals = parseVitals({ systolic: 182, diastolic: 104, heartRate: 128, spo2: 89 });
  assert.equal(vitals.systolic, 182);
  assert.equal(vitals.spo2, 89);
  assert.throws(() => parseVitals({}), /At least one/);
  assert.throws(() => parseVitals({ temperature: 52 }), /temperature/);
  assert.throws(() => parseVitals({ systolic: 120 }), /together/);
  assert.throws(() => parseVitals({ systolic: 80, diastolic: 90 }), /lower/);
  assert.throws(
    () => parseVitals({ heartRate: 70, recordedAt: new Date(Date.now() + 3600e3).toISOString() }),
    /future/,
  );
});

test('consultation and vital responses expose author names only', () => {
  const doctor = { _id: id(), firstName: 'Karim', lastName: 'Haddad', username: 'karim', specialty: 'Cardiologie', email: 'x@y.z' };
  const consultation = consultationResponse({
    _id: id(), patientId: id(), doctorId: doctor, date: new Date(), reason: 'Contrôle',
  });
  assert.deepEqual(consultation.doctor, { _id: doctor._id, name: 'Karim Haddad', specialty: 'Cardiologie' });
  assert.equal(consultation.diagnosis, '');

  const vital = vitalResponse({ _id: id(), patientId: id(), recordedBy: doctor, recordedAt: new Date(), heartRate: 72 });
  assert.equal(vital.heartRate, 72);
  assert.equal(vital.glucose, null);
  assert.equal(vital.recordedBy.name, 'Karim Haddad');
});

test('medical schemas enforce enums and physiological limits', async () => {
  const record = new MedicalRecord({ patientId: id(), bloodType: 'Z+' });
  await assert.rejects(record.validate(), /bloodType/);
  const vital = new VitalSign({ patientId: id(), recordedBy: id(), recordedAt: new Date(), spo2: 120 });
  await assert.rejects(vital.validate(), /spo2/);
});
