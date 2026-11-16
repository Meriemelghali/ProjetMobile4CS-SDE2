const mongoose = require('mongoose');

// Limites physiologiques larges : elles rejettent les fautes de saisie
// évidentes, pas les valeurs anormales (qui doivent pouvoir être signalées).
const VITAL_LIMITS = {
  systolic: { min: 40, max: 300 },
  diastolic: { min: 20, max: 200 },
  heartRate: { min: 20, max: 250 },
  temperature: { min: 30, max: 45 },
  spo2: { min: 50, max: 100 },
  weightKg: { min: 1, max: 400 },
  glucose: { min: 0.2, max: 6 },
};

const measure = (field) => ({
  type: Number,
  min: VITAL_LIMITS[field].min,
  max: VITAL_LIMITS[field].max,
  default: null,
});

const vitalSignSchema = new mongoose.Schema({
  patientId: {
    type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true, index: true,
  },
  recordedBy: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },
  recordedAt: { type: Date, required: true },
  systolic: measure('systolic'),
  diastolic: measure('diastolic'),
  heartRate: measure('heartRate'),
  temperature: measure('temperature'),
  spo2: measure('spo2'),
  weightKg: measure('weightKg'),
  glucose: measure('glucose'),
  notes: { type: String, trim: true, maxlength: 500, default: '' },
}, { timestamps: true });

module.exports = mongoose.models.VitalSign || mongoose.model('VitalSign', vitalSignSchema);
module.exports.VITAL_LIMITS = VITAL_LIMITS;
