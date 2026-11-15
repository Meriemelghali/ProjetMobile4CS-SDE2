const { HttpError } = require('../errors');

function serviceIdFor(user) {
  return user.serviceId ? user.serviceId.toString() : null;
}

function hospitalIdFor(user) {
  return user.hospitalId ? user.hospitalId.toString() : null;
}

function pharmacyIdFor(user) {
  return user.pharmacyId ? user.pharmacyId.toString() : null;
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
  const assignedHospitalId = hospitalIdFor(user);
  if (!assignedHospitalId || String(hospitalId) !== assignedHospitalId) {
    throw new HttpError(403, 'Resource is outside your hospital.');
  }
}

function assertServiceScope(user, serviceId, hospitalId = null) {
  if (user.role === 'admin') return;
  if (user.role !== 'service_head' ||
      !serviceIdFor(user) ||
      String(serviceId) !== serviceIdFor(user)) {
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
  assertHospitalScope,
  assertPharmacyScope,
  assertRoomScope,
  assertServiceScope,
  hospitalIdFor,
  pharmacyIdFor,
  serviceIdFor,
};
