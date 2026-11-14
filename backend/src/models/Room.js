const mongoose = require('mongoose');

const roomSchema = new mongoose.Schema({
  hospitalId: { type: mongoose.Schema.Types.ObjectId, ref: 'Hospital', required: true, index: true },
  serviceId: { type: mongoose.Schema.Types.ObjectId, ref: 'Service', required: true },
  name: { type: String, select: false },
  number: { type: Number, required: true, min: 1, validate: Number.isInteger },
  floor: { type: String, required: true, trim: true, maxlength: 40 },
  type: { type: String, required: true, enum: ['single', 'double', 'intensive_care'] },
  status: { type: String, required: true, enum: ['available', 'full', 'maintenance'], default: 'available' },
  capacity: { type: Number, required: true, min: 1, max: 500, validate: Number.isInteger, default: 1 },
}, { timestamps: true });

roomSchema.index({ hospitalId: 1, number: 1 }, { unique: true });

module.exports = mongoose.models.Room || mongoose.model('Room', roomSchema);
