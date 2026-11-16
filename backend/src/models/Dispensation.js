const mongoose = require('mongoose');

const dispensedMedicationSchema = new mongoose.Schema({
  medicationId: { type: mongoose.Schema.Types.ObjectId, ref: 'Medication', required: true },
  name: { type: String, required: true, trim: true },
  dosage: { type: String, required: true, trim: true, maxlength: 120 },
  quantity: { type: Number, required: true, min: 1 },
}, { _id: false });

const dispensationSchema = new mongoose.Schema({
  prescriptionId: { type: mongoose.Schema.Types.ObjectId, ref: 'Prescription', required: true, unique: true },
  pharmacistId: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },
  pharmacyId: { type: mongoose.Schema.Types.ObjectId, ref: 'Pharmacy', required: true, index: true },
  medications: { type: [dispensedMedicationSchema], required: true },
  dispensedAt: { type: Date, default: Date.now },
}, { timestamps: true });

module.exports = mongoose.models.Dispensation || mongoose.model('Dispensation', dispensationSchema);
