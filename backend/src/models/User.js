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
  allergies: { type: [String], default: [] },
  language: { type: String, enum: ['fr', 'ar'], default: 'fr' },
  notificationPreferences: {
    appointments: { type: Boolean, default: true },
    results: { type: Boolean, default: true },
    reminders: { type: Boolean, default: true },
  },
  role: {
    type: String,
    required: true,
    enum: [
      'admin', 'doctor', 'nurse', 'secretary', 'service_head',
      'operating_room_manager', 'pharmacist', 'patient',
    ],
  },
  roles: {
    type: [{
      type: String,
      enum: [
        'admin', 'doctor', 'nurse', 'secretary', 'service_head',
        'operating_room_manager', 'pharmacist', 'patient',
      ],
    }],
    default: undefined,
  },
  serviceId: { type: mongoose.Schema.Types.ObjectId, ref: 'Service', default: null },
  hospitalId: { type: mongoose.Schema.Types.ObjectId, ref: 'Hospital', default: null },
  pharmacyId: { type: mongoose.Schema.Types.ObjectId, ref: 'Pharmacy', default: null },
  serviceIds: [{ type: mongoose.Schema.Types.ObjectId, ref: 'Service' }],
  specialty: { type: String, trim: true, maxlength: 120, default: '' },
  photoUrl: { type: String, trim: true, maxlength: 500, default: '' },
  active: { type: Boolean, default: true },
  bootstrapKey: { type: String, unique: true, sparse: true, select: false },
}, { timestamps: true });

module.exports = mongoose.models.User || mongoose.model('User', userSchema);
