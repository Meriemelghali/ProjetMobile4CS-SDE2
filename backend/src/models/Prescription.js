const mongoose = require('mongoose');

const prescribedMedicationSchema = new mongoose.Schema({
  medicationId: { type: mongoose.Schema.Types.ObjectId, ref: 'Medication', required: true },
  name: { type: String, required: true, trim: true, maxlength: 160 },
  dosage: { type: String, required: true, trim: true, maxlength: 120 },
  quantity: { type: Number, required: true, min: 1 },
}, { _id: false });

const prescriptionSchema = new mongoose.Schema({
  patientId: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true, index: true },
  doctorId: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },
  pharmacyId: { type: mongoose.Schema.Types.ObjectId, ref: 'Pharmacy', required: true, index: true },
  medications: { type: [prescribedMedicationSchema], required: true, validate: (items) => items.length > 0 },
  status: { type: String, enum: ['pending', 'validated', 'dispensed', 'rejected'], default: 'pending', index: true },
  rejectionReason: { type: String, trim: true, maxlength: 500, default: '' },
  validatedAt: { type: Date, default: null },
  dispensedAt: { type: Date, default: null },
}, { timestamps: true });

module.exports = mongoose.models.Prescription || mongoose.model('Prescription', prescriptionSchema);
