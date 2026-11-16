const mongoose = require('mongoose');

const BLOOD_TYPES = ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-', 'unknown'];
const ALLERGY_SEVERITIES = ['mild', 'moderate', 'severe'];

const allergySchema = new mongoose.Schema({
  name: { type: String, required: true, trim: true, maxlength: 120 },
  severity: { type: String, enum: ALLERGY_SEVERITIES, default: 'moderate' },
  reaction: { type: String, trim: true, maxlength: 240, default: '' },
}, { _id: false });

const conditionSchema = new mongoose.Schema({
  name: { type: String, required: true, trim: true, maxlength: 160 },
  since: { type: Date, default: null },
  notes: { type: String, trim: true, maxlength: 500, default: '' },
}, { _id: false });

const treatmentSchema = new mongoose.Schema({
  name: { type: String, required: true, trim: true, maxlength: 160 },
  dosage: { type: String, trim: true, maxlength: 120, default: '' },
  frequency: { type: String, trim: true, maxlength: 120, default: '' },
  startedAt: { type: Date, default: null },
}, { _id: false });

const vaccinationSchema = new mongoose.Schema({
  name: { type: String, required: true, trim: true, maxlength: 160 },
  date: { type: Date, default: null },
}, { _id: false });

const medicalRecordSchema = new mongoose.Schema({
  patientId: {
    type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true, unique: true,
  },
  bloodType: { type: String, enum: BLOOD_TYPES, default: 'unknown' },
  heightCm: { type: Number, min: 30, max: 260, default: null },
  allergies: { type: [allergySchema], default: [] },
  chronicConditions: { type: [conditionSchema], default: [] },
  history: {
    medical: { type: [String], default: [] },
    surgical: { type: [String], default: [] },
    family: { type: [String], default: [] },
  },
  currentTreatments: { type: [treatmentSchema], default: [] },
  vaccinations: { type: [vaccinationSchema], default: [] },
  updatedBy: { type: mongoose.Schema.Types.ObjectId, ref: 'User', default: null },
}, { timestamps: true });

module.exports = mongoose.models.MedicalRecord
  || mongoose.model('MedicalRecord', medicalRecordSchema);
module.exports.BLOOD_TYPES = BLOOD_TYPES;
module.exports.ALLERGY_SEVERITIES = ALLERGY_SEVERITIES;
