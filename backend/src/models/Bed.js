const mongoose = require('mongoose');

const bedSchema = new mongoose.Schema({
  roomId: { type: mongoose.Schema.Types.ObjectId, ref: 'Room', required: true, index: true },
  bedNumber: { type: String, select: false },
  number: { type: Number, required: true, min: 1, validate: Number.isInteger },
  status: { type: String, required: true, enum: ['free', 'occupied', 'reserved', 'cleaning'], default: 'free' },
  patientId: { type: mongoose.Schema.Types.ObjectId, ref: 'User' },
  assignedAt: Date,
}, { timestamps: true });

bedSchema.index({ roomId: 1, number: 1 }, { unique: true });
bedSchema.index(
  { patientId: 1 },
  { unique: true, partialFilterExpression: { patientId: { $type: 'objectId' } } },
);

bedSchema.pre('validate', function validateAssignment() {
  if (this.status === 'occupied' && !this.patientId) {
    this.invalidate('patientId', 'An occupied bed must have a patient assignment.');
  }
  if (this.patientId && this.status !== 'occupied') {
    this.invalidate('status', 'An assigned bed must have occupied status.');
  }
});

module.exports = mongoose.models.Bed || mongoose.model('Bed', bedSchema);
