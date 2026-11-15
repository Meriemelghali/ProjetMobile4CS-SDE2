const mongoose = require('mongoose');

const medicationSchema = new mongoose.Schema({
  name: { type: String, required: true, trim: true, maxlength: 160 },
  activeIngredient: { type: String, required: true, trim: true, maxlength: 160 },
  form: { type: String, required: true, trim: true, maxlength: 80 },
  dosage: { type: String, required: true, trim: true, maxlength: 80 },
  stockQuantity: { type: Number, required: true, min: 0 },
  alertThreshold: { type: Number, required: true, min: 0 },
  lot: { type: String, required: true, trim: true, maxlength: 80 },
  expirationDate: { type: Date, required: true },
  price: { type: Number, required: true, min: 0 },
  pharmacyId: { type: mongoose.Schema.Types.ObjectId, ref: 'Pharmacy', required: true, index: true },
}, { timestamps: true });

medicationSchema.index({ pharmacyId: 1, name: 1 });

module.exports = mongoose.models.Medication || mongoose.model('Medication', medicationSchema);
