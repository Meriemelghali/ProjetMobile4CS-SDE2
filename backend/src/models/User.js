const mongoose = require('mongoose');

const userSchema = new mongoose.Schema({
  username: { type: String, required: true, trim: true, maxlength: 120 },
  email: { type: String, required: true, unique: true, lowercase: true, trim: true },
  passwordHash: { type: String, required: true, select: false },
  firstName: { type: String, trim: true, maxlength: 80, default: '' },
  lastName: { type: String, trim: true, maxlength: 80, default: '' },
  birthDate: { type: Date, default: null },
  phone: { type: String, trim: true, maxlength: 40, default: '' },
  address: { type: String, trim: true, maxlength: 240, default: '' },
  emergencyContact: { type: String, trim: true, maxlength: 160, default: '' },
  insurance: { type: String, trim: true, maxlength: 120, default: '' },
  language: { type: String, enum: ['fr', 'ar'], default: 'fr' },
  notificationPreferences: {
    appointments: { type: Boolean, default: true },
    results: { type: Boolean, default: true },
    reminders: { type: Boolean, default: true },
  },
  role: { type: String, required: true, enum: ['admin', 'doctor', 'nurse', 'secretary', 'patient'] },
  serviceId: { type: mongoose.Schema.Types.ObjectId, ref: 'Service', default: null },
  serviceIds: [{ type: mongoose.Schema.Types.ObjectId, ref: 'Service' }],
  specialty: { type: String, trim: true, maxlength: 120, default: '' },
  photoUrl: { type: String, trim: true, maxlength: 500, default: '' },
  active: { type: Boolean, default: true },
  bootstrapKey: { type: String, unique: true, sparse: true, select: false },
}, { timestamps: true });

module.exports = mongoose.models.User || mongoose.model('User', userSchema);
