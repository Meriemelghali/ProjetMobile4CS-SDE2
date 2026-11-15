const mongoose = require('mongoose');

const hospitalSchema = new mongoose.Schema({
  name: { type: String, required: true, trim: true, maxlength: 160, unique: true },
  address: { type: String, default: '', trim: true, maxlength: 240 },
  phone: { type: String, default: '', trim: true, maxlength: 30 },
  active: { type: Boolean, default: true },
  serviceIds: [{ type: mongoose.Schema.Types.ObjectId, ref: 'Service' }],
}, { timestamps: true });

module.exports = mongoose.models.Hospital || mongoose.model('Hospital', hospitalSchema);
