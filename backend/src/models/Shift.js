const mongoose = require('mongoose');

const shiftSchema = new mongoose.Schema({
  userId: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true, index: true },
  serviceId: { type: mongoose.Schema.Types.ObjectId, ref: 'Service', required: true, index: true },
  start: { type: Date, required: true, index: true },
  end: { type: Date, required: true },
  role: { type: String, required: true, trim: true, maxlength: 100 },
}, { timestamps: true });

shiftSchema.pre('validate', function validateRange() {
  if (this.start && this.end && this.end <= this.start) {
    this.invalidate('end', 'Shift end must be after start.');
  }
});

module.exports = mongoose.models.Shift || mongoose.model('Shift', shiftSchema);
