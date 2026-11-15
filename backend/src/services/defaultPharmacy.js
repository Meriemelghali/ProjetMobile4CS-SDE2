const Pharmacy = require('../models/Pharmacy');

const DEFAULT_PHARMACY_NAME = 'Pharmacie hospitalière';

async function ensureDefaultPharmacy() {
  const existing = await Pharmacy.findOne({ name: DEFAULT_PHARMACY_NAME });
  if (existing) return false;
  await Pharmacy.create({ name: DEFAULT_PHARMACY_NAME, active: true });
  return true;
}

module.exports = { DEFAULT_PHARMACY_NAME, ensureDefaultPharmacy };
