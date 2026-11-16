const mongoose = require('mongoose');

const consultationSchema = new mongoose.Schema({
  patientId: {
    type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true, index: true,
  },
  doctorId: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },
  appointmentId: { type: mongoose.Schema.Types.ObjectId, ref: 'Appointment', default: null },
  date: { type: Date, required: true },
  reason: { type: String, required: true, trim: true, maxlength: 240 },
  symptoms: { type: String, trim: true, maxlength: 1000, default: '' },
  examination: { type: String, trim: true, maxlength: 1000, default: '' },
  diagnosis: { type: String, trim: true, maxlength: 500, default: '' },
  notes: { type: String, trim: true, maxlength: 2000, default: '' },
  followUpAt: { type: Date, default: null },
}, { timestamps: true });

module.exports = mongoose.models.Consultation
  || mongoose.model('Consultation', consultationSchema);
