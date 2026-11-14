const mongoose = require('mongoose');

const scheduleEntrySchema = new mongoose.Schema({
  interventionId: { type: mongoose.Schema.Types.ObjectId, ref: 'Intervention', required: true },
  start: { type: Date, required: true },
  end: { type: Date, required: true },
  status: { type: String, required: true, enum: ['scheduled', 'in_progress', 'completed', 'cancelled'] },
}, { _id: false });

const operatingRoomSchema = new mongoose.Schema({
  hospitalId: { type: mongoose.Schema.Types.ObjectId, ref: 'Hospital', required: true, index: true },
  serviceId: { type: mongoose.Schema.Types.ObjectId, ref: 'Service', default: null },
  name: { type: String, required: true, trim: true, maxlength: 100 },
  number: { type: Number, required: true, min: 1, validate: Number.isInteger },
  status: { type: String, required: true, enum: ['free', 'in_progress', 'sterilization'], default: 'free' },
  schedule: { type: [scheduleEntrySchema], default: [] },
}, { timestamps: true });

operatingRoomSchema.index({ hospitalId: 1, number: 1 }, { unique: true });

module.exports = mongoose.models.OperatingRoom
  || mongoose.model('OperatingRoom', operatingRoomSchema);
