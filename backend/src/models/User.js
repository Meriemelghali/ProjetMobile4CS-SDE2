const mongoose = require('mongoose');

const userSchema = new mongoose.Schema({
  username: { type: String, required: true, trim: true, maxlength: 120 },
  email: { type: String, required: true, unique: true, lowercase: true, trim: true },
  passwordHash: { type: String, required: true, select: false },
  role: {
    type: String,
    required: true,
    enum: ['admin', 'doctor', 'nurse', 'secretary', 'service_head', 'patient'],
  },
  roles: {
    type: [{
      type: String,
      enum: ['admin', 'doctor', 'nurse', 'secretary', 'service_head', 'patient'],
    }],
    default: undefined,
  },
  serviceId: { type: mongoose.Schema.Types.ObjectId, ref: 'Service', default: null },
  active: { type: Boolean, default: true },
  bootstrapKey: { type: String, unique: true, sparse: true, select: false },
}, { timestamps: true });

module.exports = mongoose.models.User || mongoose.model('User', userSchema);
