const Hospital = require('../models/Hospital');
const Service = require('../models/Service');
const User = require('../models/User');

const DEFAULT_DOCTOR_SERVICE_NAME = 'Médecin';

async function ensureDoctorService({
  hospitalModel = Hospital,
  serviceModel = Service,
} = {}) {
  const service = await serviceModel.findOneAndUpdate(
    { name: DEFAULT_DOCTOR_SERVICE_NAME },
    {
      $set: {
        active: true,
        a_rdv: true,
        serviceType: 'medical',
      },
      $setOnInsert: {
        description: 'Service commun des médecins.',
      },
    },
    { new: true, upsert: true, setDefaultsOnInsert: true },
  );
  await hospitalModel.updateMany(
    {},
    { $addToSet: { serviceIds: service._id } },
  );
  return service;
}

async function assignExistingDoctorsToDefaultService({
  userModel = User,
  serviceId,
} = {}) {
  if (!serviceId) throw new Error('A default doctor service ID is required.');
  const doctors = { $or: [{ role: 'doctor' }, { roles: 'doctor' }] };
  await userModel.updateMany(
    { $and: [doctors, { roles: 'secretary' }] },
    { $set: { serviceId } },
  );
  await userModel.updateMany(
    { $and: [doctors, { roles: { $ne: 'secretary' } }] },
    { $set: { serviceId, serviceIds: [serviceId] } },
  );
}

module.exports = {
  DEFAULT_DOCTOR_SERVICE_NAME,
  ensureDoctorService,
  assignExistingDoctorsToDefaultService,
};
