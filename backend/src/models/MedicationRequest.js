const mongoose = require('mongoose');

const requestedMedicationSchema = new mongoose.Schema({
  medicationId: { type: mongoose.Schema.Types.ObjectId, ref: 'Medication', required: true },
  name: { type: String, required: true, trim: true },
  quantity: { type: Number, required: true, min: 1 },
}, { _id: false });

const medicationRequestSchema = new mongoose.Schema({
  serviceId: { type: mongoose.Schema.Types.ObjectId, ref: 'Service', required: true },
  pharmacyId: { type: mongoose.Schema.Types.ObjectId, ref: 'Pharmacy', required: true, index: true },
  requestedBy: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },
  medications: { type: [requestedMedicationSchema], required: true },
  status: { type: String, enum: ['pending', 'approved', 'rejected', 'delivered'], default: 'pending', index: true },
  rejectionReason: { type: String, trim: true, maxlength: 500, default: '' },
}, { timestamps: true });

module.exports = mongoose.models.MedicationRequest || mongoose.model('MedicationRequest', medicationRequestSchema);
