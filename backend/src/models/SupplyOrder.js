const mongoose = require('mongoose');

const supplyMedicationSchema = new mongoose.Schema({
  medicationId: { type: mongoose.Schema.Types.ObjectId, ref: 'Medication', required: true },
  name: { type: String, required: true, trim: true },
  quantity: { type: Number, required: true, min: 1 },
}, { _id: false });

const supplyOrderSchema = new mongoose.Schema({
  pharmacyId: { type: mongoose.Schema.Types.ObjectId, ref: 'Pharmacy', required: true, index: true },
  supplier: { type: String, required: true, trim: true, maxlength: 160 },
  medications: { type: [supplyMedicationSchema], required: true },
  status: { type: String, enum: ['ordered', 'received'], default: 'ordered', index: true },
  receivedAt: { type: Date, default: null },
}, { timestamps: true });

module.exports = mongoose.models.SupplyOrder || mongoose.model('SupplyOrder', supplyOrderSchema);
