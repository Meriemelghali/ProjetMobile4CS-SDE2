const mongoose = require('mongoose');

const pharmacySchema = new mongoose.Schema({
  name: { type: String, required: true, trim: true, maxlength: 160 },
  address: { type: String, trim: true, maxlength: 240, default: '' },
  phone: { type: String, trim: true, maxlength: 40, default: '' },
  active: { type: Boolean, default: true },
}, { timestamps: true });

module.exports = mongoose.models.Pharmacy || mongoose.model('Pharmacy', pharmacySchema);
