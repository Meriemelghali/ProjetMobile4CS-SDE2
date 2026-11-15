const mongoose = require('mongoose');

const interventionSchema = new mongoose.Schema({
  surgeonId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    required: true,
    index: true,
  },
  patientId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    required: true,
    index: true,
  },
  operatingRoomId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'OperatingRoom',
    required: true,
    index: true,
    immutable: true,
  },
  equipmentIds: [{ type: mongoose.Schema.Types.ObjectId, ref: 'Equipment' }],
  title: { type: String, required: true, trim: true, maxlength: 160 },
  start: { type: Date, required: true, index: true },
  end: { type: Date, required: true },
  status: {
    type: String,
    required: true,
    enum: ['scheduled', 'in_progress', 'completed', 'cancelled'],
    default: 'scheduled',
  },
}, { timestamps: true });

interventionSchema.pre('validate', function validateRange() {
  if (this.start && this.end && this.end <= this.start) {
    this.invalidate('end', 'Intervention end must be after start.');
  }
});

module.exports = mongoose.models.Intervention
  || mongoose.model('Intervention', interventionSchema);
