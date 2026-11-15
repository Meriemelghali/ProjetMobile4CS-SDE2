const Hospital = require('../models/Hospital');
const Service = require('../models/Service');

const DEFAULT_HOSPITAL_NAME = 'Hôpital principal';

async function ensureDefaultHospital({
  hospitalModel = Hospital,
  serviceModel = Service,
} = {}) {
  if (await hospitalModel.findOne()) return false;

  const serviceIds = await serviceModel.distinct('_id');
  try {
    await hospitalModel.create({
      name: DEFAULT_HOSPITAL_NAME,
      serviceIds,
    });
    return true;
  } catch (error) {
    if (error?.code === 11000 && await hospitalModel.findOne()) return false;
    throw error;
  }
}

module.exports = { DEFAULT_HOSPITAL_NAME, ensureDefaultHospital };
