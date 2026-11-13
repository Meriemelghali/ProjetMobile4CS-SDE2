const mongoose = require('mongoose');

const handoverSchema = new mongoose.Schema({
  serviceId: { type: mongoose.Schema.Types.ObjectId, ref: 'Service', required: true, index: true },
  authorId: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },
  title: { type: String, required: true, trim: true, maxlength: 160 },
  content: { type: String, required: true, trim: true, maxlength: 5000 },
  important: { type: Boolean, default: false },
  createdAt: { type: Date, default: Date.now, immutable: true },
}, { timestamps: true });

module.exports = mongoose.models.Handover || mongoose.model('Handover', handoverSchema);
