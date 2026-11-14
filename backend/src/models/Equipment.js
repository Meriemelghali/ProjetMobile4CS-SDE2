const mongoose = require('mongoose');

const scheduleEntrySchema = new mongoose.Schema({
  interventionId: { type: mongoose.Schema.Types.ObjectId, ref: 'Intervention', required: true },
  start: { type: Date, required: true },
  end: { type: Date, required: true },
  status: { type: String, required: true, enum: ['scheduled', 'in_progress', 'completed', 'cancelled'] },
}, { _id: false });

const equipmentSchema = new mongoose.Schema({
  hospitalId: { type: mongoose.Schema.Types.ObjectId, ref: 'Hospital', required: true, index: true },
  serviceId: { type: mongoose.Schema.Types.ObjectId, ref: 'Service', default: null },
  operatingRoomId: { type: mongoose.Schema.Types.ObjectId, ref: 'OperatingRoom', default: null },
  assetTag: { type: String, select: false },
  name: { type: String, required: true, trim: true, maxlength: 120 },
  type: { type: String, required: true, trim: true, maxlength: 100 },
  serialNumber: { type: String, required: true, trim: true, maxlength: 100, unique: true },
  status: {
    type: String,
    required: true,
    enum: ['functional', 'broken', 'maintenance'],
    default: 'functional',
  },
  lastMaintenanceAt: Date,
  maintenanceDueAt: Date,
  schedule: { type: [scheduleEntrySchema], default: [] },
}, { timestamps: true });

equipmentSchema.pre('validate', function validateAssignment() {
  if (Boolean(this.serviceId) === Boolean(this.operatingRoomId)) {
    this.invalidate('serviceId', 'Equipment must be assigned to exactly one service or operating room.');
  }
});

module.exports = mongoose.models.Equipment || mongoose.model('Equipment', equipmentSchema);
