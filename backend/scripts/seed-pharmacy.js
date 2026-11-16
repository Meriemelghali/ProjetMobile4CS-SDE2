const mongoose = require('mongoose');
const { getConfig } = require('../src/config');
const User = require('../src/models/User');
const Pharmacy = require('../src/models/Pharmacy');
const Medication = require('../src/models/Medication');
const Prescription = require('../src/models/Prescription');
const Appointment = require('../src/models/Appointment');
const { hashPassword } = require('../src/services/auth');

async function upsertUser({ email, username, role, pharmacyId = null }) {
  const password = process.env.PHARMACY_SEED_PASSWORD || 'PharmacyDemo123!';
  return User.findOneAndUpdate(
    { email },
    { $set: { username, role, roles: [role], pharmacyId, active: true, passwordHash: await hashPassword(password) } },
    { new: true, upsert: true, setDefaultsOnInsert: true },
  );
}

async function main() {
  await mongoose.connect(getConfig().mongoUri);
  await Prescription.syncIndexes();
  const pharmacy = await Pharmacy.findOneAndUpdate(
    { name: 'Pharmacie HôpitalConnect' },
    { $set: { name: 'Pharmacie HôpitalConnect', active: true } },
    { new: true, upsert: true, setDefaultsOnInsert: true },
  );
  const pharmacist = await upsertUser({ email: 'pharmacien.demo@hopitalconnect.test', username: 'Pharmacien Demo', role: 'pharmacist', pharmacyId: pharmacy._id });
  const patient = await upsertUser({ email: 'patient.demo@hopitalconnect.test', username: 'Patient Demo', role: 'patient' });
  const doctor = await upsertUser({ email: 'medecin.demo@hopitalconnect.test', username: 'Médecin Demo', role: 'doctor' });
  const medication = await Medication.findOneAndUpdate(
    { pharmacyId: pharmacy._id, lot: 'DEMO-2026' },
    { $set: { name: 'Paracétamol', activeIngredient: 'Paracétamol', form: 'Comprimé', dosage: '500 mg', stockQuantity: 50, alertThreshold: 10, lot: 'DEMO-2026', expirationDate: new Date('2027-12-31T00:00:00Z'), price: 2.5, pharmacyId: pharmacy._id } },
    { new: true, upsert: true, setDefaultsOnInsert: true },
  );
  await Medication.findOneAndUpdate(
    { pharmacyId: pharmacy._id, lot: 'DEMO-IBU-2026' },
    { $set: { name: 'Ibuprofène', activeIngredient: 'Ibuprofène', form: 'Comprimé', dosage: '200 mg', stockQuantity: 30, alertThreshold: 8, lot: 'DEMO-IBU-2026', expirationDate: new Date('2027-12-31T00:00:00Z'), price: 3, pharmacyId: pharmacy._id } },
    { new: true, upsert: true, setDefaultsOnInsert: true },
  );
  const appointment = await Appointment.findOneAndUpdate(
    { patientId: patient._id, doctorId: doctor._id, reason: 'Consultation pharmacie de démonstration' },
    {
      $set: {
        startAt: new Date(Date.now() + 86400000),
        status: 'accepted',
        slotKey: `${patient._id}:pharmacy-demo`,
      },
      $setOnInsert: { patientId: patient._id, doctorId: doctor._id, reason: 'Consultation pharmacie de démonstration' },
    },
    { new: true, upsert: true, setDefaultsOnInsert: true },
  );
  await Prescription.findOneAndUpdate(
    { appointmentId: appointment._id },
    { $setOnInsert: { appointmentId: appointment._id, patientId: patient._id, doctorId: doctor._id, pharmacyId: pharmacy._id, medications: [{ medicationId: medication._id, name: medication.name, dosage: medication.dosage, quantity: 2 }], status: 'pending' } },
    { upsert: true, new: true, setDefaultsOnInsert: true },
  );
  console.log(JSON.stringify({ pharmacyId: pharmacy._id.toString(), pharmacist: pharmacist.email, patient: patient.email, doctor: doctor.email, password: process.env.PHARMACY_SEED_PASSWORD || 'PharmacyDemo123!' }, null, 2));
}

main().catch((error) => { console.error(`Pharmacy seed failed: ${error.message}`); process.exitCode = 1; }).finally(async () => { if (mongoose.connection.readyState !== 0) await mongoose.disconnect(); });
