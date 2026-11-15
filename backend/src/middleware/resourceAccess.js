const { HttpError } = require('../errors');
const Service = require('../models/Service');
const Hospital = require('../models/Hospital');
const { getUserRoles } = require('../utils/validation');

function serviceIdFor(user) {
  return user.serviceId ? user.serviceId.toString() : null;
}

function serviceIdsFor(user) {
  if (user.role === 'service_head') {
    const scopedIds = user.$locals && user.$locals.serviceHeadServiceIds;
    if (Array.isArray(scopedIds)) return scopedIds.map(String);
    if (user.serviceId && !getUserRoles(user).includes('doctor')) {
      return [user.serviceId.toString()];
    }
    return [];
  }
  return user.serviceId ? [user.serviceId.toString()] : [];
}

function hospitalIdFor(user) {
  return user.hospitalId ? user.hospitalId.toString() : null;
}

function hospitalIdsFor(user) {
  if (user.role === 'service_head') {
    const scopedIds = user.$locals && user.$locals.serviceHeadHospitalIds;
    if (Array.isArray(scopedIds)) return scopedIds.map(String);
  }
  return user.hospitalId ? [user.hospitalId.toString()] : [];
}

function pharmacyIdFor(user) {
  return user.pharmacyId ? user.pharmacyId.toString() : null;
}

async function attachServiceHeadScope(user, {
  serviceModel = Service,
  hospitalModel = Hospital,
} = {}) {
  const headedIds = await serviceModel.find({
    headUserId: user._id,
  }).distinct('_id');
  const serviceIds = new Set(headedIds.map(String));
  if (user.serviceId && !getUserRoles(user).includes('doctor')) {
    serviceIds.add(user.serviceId.toString());
  }
  const ids = [...serviceIds];
  const hospitalIds = ids.length
    ? await hospitalModel.find({
      serviceIds: { $in: ids },
    }).distinct('_id')
    : [];
  if (!user.$locals) user.$locals = {};
  user.$locals.serviceHeadServiceIds = ids;
  user.$locals.serviceHeadHospitalIds = hospitalIds.map(String);
}

function assertPharmacyScope(user, pharmacyId) {
  if (user.role === 'admin') return;
  const assignedPharmacyId = pharmacyIdFor(user);
  if (user.role !== 'pharmacist' || !assignedPharmacyId || String(pharmacyId) !== assignedPharmacyId) {
    throw new HttpError(403, 'Resource is outside your pharmacy.');
  }
}

function assertHospitalScope(user, hospitalId) {
  if (user.role === 'admin') return;
  const assignedHospitalIds = hospitalIdsFor(user);
  if (!assignedHospitalIds.includes(String(hospitalId))) {
    throw new HttpError(403, 'Resource is outside your hospital.');
  }
}

function assertServiceScope(user, serviceId, hospitalId = null) {
  if (user.role === 'admin') return;
  if (user.role !== 'service_head' ||
      !serviceIdsFor(user).includes(String(serviceId))) {
    throw new HttpError(403, 'Resource is outside your service.');
  }
  if (hospitalId !== null) assertHospitalScope(user, hospitalId);
}

function assertRoomScope(user, room) {
  if (user.role === 'admin') return;
  if (user.role === 'service_head') {
    assertServiceScope(user, room.serviceId, room.hospitalId);
    return;
  }
  if (user.role === 'operating_room_manager') {
    assertHospitalScope(user, room.hospitalId);
  }
}

module.exports = {
  attachServiceHeadScope,
  assertHospitalScope,
  assertPharmacyScope,
  assertRoomScope,
  assertServiceScope,
  hospitalIdFor,
  hospitalIdsFor,
  pharmacyIdFor,
  serviceIdFor,
  serviceIdsFor,
};
