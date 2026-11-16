const { test } = require('node:test');
const assert = require('node:assert/strict');
const mongoose = require('mongoose');
require('dotenv').config();

const enabled = process.env.RUN_PHARMACY_INTEGRATION === '1' && Boolean(process.env.MONGODB_URI);

test('pharmacy HTTP flow enforces scope and decrements stock', { skip: !enabled }, async (t) => {
  process.env.JWT_SECRET = process.env.JWT_SECRET || 'integration-test-secret-with-at-least-32-chars';
  const app = require('../src/app');
  const { hashPassword } = require('../src/services/auth');
  const Pharmacy = require('../src/models/Pharmacy');
  const Medication = require('../src/models/Medication');
  const Prescription = require('../src/models/Prescription');
  const User = require('../src/models/User');
  await mongoose.connect(process.env.MONGODB_URI);
  const suffix = Date.now().toString();
  const password = 'PharmacyIntegration123!';
  const passwordHash = await hashPassword(password);
  await Prescription.syncIndexes();
  const [pharmacyOne, pharmacyTwo] = await Pharmacy.create([
    { name: `Integration One ${suffix}` }, { name: `Integration Two ${suffix}` },
  ]);
  const [pharmacist, otherPharmacist, patient, doctor] = await User.create([
    { username: 'Pharmacist One', email: `pharmacist-one-${suffix}@test.invalid`, passwordHash, role: 'pharmacist', roles: ['pharmacist'], pharmacyId: pharmacyOne._id },
    { username: 'Pharmacist Two', email: `pharmacist-two-${suffix}@test.invalid`, passwordHash, role: 'pharmacist', roles: ['pharmacist'], pharmacyId: pharmacyTwo._id },
    { username: 'Patient', email: `patient-${suffix}@test.invalid`, passwordHash, role: 'patient', roles: ['patient'] },
    { username: 'Doctor', email: `doctor-${suffix}@test.invalid`, passwordHash, role: 'doctor', roles: ['doctor'] },
  ]);
  const medication = await Medication.create({ name: 'Integration Medicine', activeIngredient: 'API', form: 'tablet', dosage: '10 mg', stockQuantity: 5, alertThreshold: 1, lot: `LOT-${suffix}`, expirationDate: new Date(Date.now() + 86400000 * 90), price: 1, pharmacyId: pharmacyOne._id });
  const hiddenMedication = await Medication.create({ name: 'Hidden Medicine', activeIngredient: 'API', form: 'tablet', dosage: '10 mg', stockQuantity: 5, alertThreshold: 1, lot: `HIDDEN-${suffix}`, expirationDate: new Date(Date.now() + 86400000 * 90), price: 1, pharmacyId: pharmacyTwo._id });
  const prescription = await Prescription.create({ patientId: patient._id, doctorId: doctor._id, pharmacyId: pharmacyOne._id, medications: [{ medicationId: medication._id, name: medication.name, dosage: medication.dosage, quantity: 3 }] });
  const insufficient = await Prescription.create({ patientId: patient._id, doctorId: doctor._id, pharmacyId: pharmacyOne._id, medications: [{ medicationId: medication._id, name: medication.name, dosage: medication.dosage, quantity: 99 }] });
  const server = app.listen(0);
  t.after(async () => {
    server.close();
    await Promise.all([
      Pharmacy.deleteMany({ _id: { $in: [pharmacyOne._id, pharmacyTwo._id] } }),
      Medication.deleteMany({ _id: { $in: [medication._id, hiddenMedication._id] } }),
      Prescription.deleteMany({ _id: { $in: [prescription._id, insufficient._id] } }),
      User.deleteMany({ _id: { $in: [pharmacist._id, otherPharmacist._id, patient._id, doctor._id] } }),
    ]);
    await mongoose.disconnect();
  });
  const base = `http://127.0.0.1:${server.address().port}`;
  async function login(email) {
    const response = await fetch(`${base}/auth/login`, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ email, password }) });
    assert.equal(response.status, 200);
    return (await response.json()).token;
  }
  async function request(path, token, options = {}) {
    return fetch(`${base}${path}`, { ...options, headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${token}`, ...(options.headers || {}) } });
  }
  const token = await login(pharmacist.email);
  const stock = await request('/pharmacy/medications', token);
  assert.equal(stock.status, 200);
  assert.deepEqual((await stock.json()).medications.map((item) => item._id.toString()), [medication._id.toString()]);
  for (const path of ['/users', '/appointments', '/hospitals']) assert.equal((await request(path, token)).status, 403, path);
  const dispensed = await request(`/pharmacy/prescriptions/${prescription._id}/dispense`, token, { method: 'POST' });
  assert.equal(dispensed.status, 201);
  assert.equal((await Medication.findById(medication._id)).stockQuantity, 2);
  const rejected = await request(`/pharmacy/prescriptions/${insufficient._id}/dispense`, token, { method: 'POST' });
  assert.equal(rejected.status, 409);
  assert.equal((await Medication.findById(medication._id)).stockQuantity, 2);
});
