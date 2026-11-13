const mongoose = require('mongoose');

const serviceSchema = new mongoose.Schema({
  name: { type: String, required: true, trim: true, maxlength: 120, unique: true },
  description: { type: String, default: '', trim: true, maxlength: 1000 },
  location: { type: String, default: '', trim: true, maxlength: 160 },
  active: { type: Boolean, default: true },
}, { timestamps: true });

module.exports = mongoose.models.Service || mongoose.model('Service', serviceSchema);
