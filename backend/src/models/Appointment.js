const mongoose = require('mongoose');

const appointmentSchema = new mongoose.Schema({
  patientId: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },
  doctorId: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },
  startAt: { type: Date, required: true },
  reason: { type: String, trim: true, maxlength: 500, default: '' },
  status: {
    type: String,
    required: true,
    enum: ['pending', 'accepted', 'in_progress', 'completed', 'proposed', 'rejected', 'cancelled'],
    default: 'pending',
  },
  rejectionReason: { type: String, trim: true, maxlength: 500, default: '' },
  proposedStartAt: { type: Date, default: null },
  proposalNote: { type: String, trim: true, maxlength: 500, default: '' },
  claimedBy: { type: mongoose.Schema.Types.ObjectId, ref: 'User', default: null },
  claimedAt: { type: Date, default: null },
  slotKey: { type: String, default: undefined },
}, { timestamps: true });

appointmentSchema.index(
  { doctorId: 1, slotKey: 1 },
  { unique: true, partialFilterExpression: { slotKey: { $type: 'string' } } },
);
module.exports = mongoose.models.Appointment || mongoose.model('Appointment', appointmentSchema);
