const mongoose = require('mongoose');
const Pharmacy = require('../models/Pharmacy');
const Medication = require('../models/Medication');
const Prescription = require('../models/Prescription');
const Dispensation = require('../models/Dispensation');
const MedicationRequest = require('../models/MedicationRequest');
const SupplyOrder = require('../models/SupplyOrder');
const User = require('../models/User');
const { HttpError } = require('../errors');
const { pharmacyIdFor: assignedPharmacyId, assertPharmacyScope } = require('../middleware/resourceAccess');
const {
  requireDate,
  requireDateOnly,
  requireId,
  requireObject,
  requireString,
  rejectUnknownFields,
} = require('../utils/validation');

function pharmacyIdFor(user) {
  if (user.role === 'admin') return null;
  const pharmacyId = assignedPharmacyId(user);
  if (!pharmacyId || user.role !== 'pharmacist') throw new HttpError(403, 'A pharmacy assignment is required.');
  assertPharmacyScope(user, pharmacyId);
  return pharmacyId;
}

function scopeQuery(user, field = 'pharmacyId') {
  const pharmacyId = pharmacyIdFor(user);
  return pharmacyId ? { [field]: pharmacyId } : {};
}

function idOf(value) {
  return value?._id || value || null;
}

function medicationResponse(item) {
  return {
    _id: item._id,
    name: item.name,
    activeIngredient: item.activeIngredient,
    form: item.form,
    dosage: item.dosage,
    stockQuantity: item.stockQuantity,
    alertThreshold: item.alertThreshold,
    lot: item.lot,
    expirationDate: item.expirationDate,
    price: item.price,
    pharmacyId: idOf(item.pharmacyId),
  };
}

function userResponse(user) {
  if (!user) return null;
  return { _id: user._id, username: user.username, firstName: user.firstName || '', lastName: user.lastName || '', allergies: user.allergies || [] };
}

function prescriptionResponse(item) {
  return {
    _id: item._id,
    patientId: idOf(item.patientId),
    patient: userResponse(item.patientId),
    doctorId: idOf(item.doctorId),
    doctor: userResponse(item.doctorId),
    pharmacyId: idOf(item.pharmacyId),
    medications: item.medications,
    status: item.status,
    rejectionReason: item.rejectionReason || '',
    validatedAt: item.validatedAt,
    dispensedAt: item.dispensedAt,
    createdAt: item.createdAt,
  };
}

function dispensationResponse(item) {
  return {
    _id: item._id,
    prescriptionId: idOf(item.prescriptionId),
    pharmacistId: idOf(item.pharmacistId),
    pharmacyId: idOf(item.pharmacyId),
    medications: item.medications,
    dispensedAt: item.dispensedAt,
  };
}

function requestResponse(item) {
  return {
    _id: item._id,
    serviceId: idOf(item.serviceId),
    pharmacyId: idOf(item.pharmacyId),
    requestedBy: idOf(item.requestedBy),
    medications: item.medications,
    status: item.status,
    rejectionReason: item.rejectionReason || '',
    createdAt: item.createdAt,
  };
}

function orderResponse(item) {
  return {
    _id: item._id,
    pharmacyId: idOf(item.pharmacyId),
    supplier: item.supplier,
    medications: item.medications,
    status: item.status,
    receivedAt: item.receivedAt,
    createdAt: item.createdAt,
  };
}

function positiveNumber(value, field, { integer = false, allowZero = false } = {}) {
  if (typeof value !== 'number' || !Number.isFinite(value) || (integer && !Number.isInteger(value))) {
    throw new HttpError(400, `${field} must be a number.`);
  }
  if (allowZero ? value < 0 : value <= 0) throw new HttpError(400, `${field} must be positive.`);
  return value;
}

function stockDelta(value) {
  if (typeof value !== 'number' || !Number.isInteger(value) || value === 0) {
    throw new HttpError(400, 'quantity must be a non-zero integer.');
  }
  return value;
}

function parseMedicationFields(body, creating = false) {
  const fields = {};
  for (const [field, max] of [['name', 160], ['activeIngredient', 160], ['form', 80], ['dosage', 80], ['lot', 80]]) {
    if (creating || body[field] !== undefined) fields[field] = requireString(body[field], field, { max });
  }
  if (creating || body.stockQuantity !== undefined) fields.stockQuantity = positiveNumber(body.stockQuantity, 'stockQuantity', { integer: true, allowZero: true });
  if (creating || body.alertThreshold !== undefined) fields.alertThreshold = positiveNumber(body.alertThreshold, 'alertThreshold', { integer: true, allowZero: true });
  if (creating || body.price !== undefined) fields.price = positiveNumber(body.price, 'price', { allowZero: true });
  if (creating || body.expirationDate !== undefined) fields.expirationDate = requireDateOnly(body.expirationDate);
  return fields;
}

function parseItems(value, field = 'medications') {
  if (!Array.isArray(value) || !value.length) throw new HttpError(400, `${field} must be a non-empty array.`);
  return value.map((item, index) => {
    const body = requireObject(item, `${field}[${index}]`);
    const medicationId = requireId(body.medicationId, `${field}[${index}].medicationId`);
    const quantity = positiveNumber(body.quantity, `${field}[${index}].quantity`, { integer: true });
    return { medicationId, quantity, ...(body.name ? { name: requireString(body.name, `${field}[${index}].name`, { max: 160 }) } : {}) };
  });
}

async function findScopedMedication(user, id) {
  const medication = await Medication.findOne({ _id: requireId(id, 'medicationId'), ...scopeQuery(user) });
  if (!medication) throw new HttpError(404, 'Medication not found.');
  return medication;
}

async function listPharmacies(_req, res) {
  const query = { active: true };
  if (_req.user.role === 'pharmacist') query._id = pharmacyIdFor(_req.user);
  const pharmacies = await Pharmacy.find(query).sort({ name: 1 }).limit(200);
  return res.json({ pharmacies });
}

async function listMedications(req, res) {
  const query = { ...scopeQuery(req.user) };
  if (req.query.search) query.$or = [
    { name: new RegExp(String(req.query.search).slice(0, 80), 'i') },
    { activeIngredient: new RegExp(String(req.query.search).slice(0, 80), 'i') },
    { lot: new RegExp(String(req.query.search).slice(0, 80), 'i') },
  ];
  const medications = await Medication.find(query).sort({ name: 1 }).limit(500);
  return res.json({ medications: medications.map(medicationResponse) });
}

async function createMedication(req, res) {
  const body = requireObject(req.body);
  rejectUnknownFields(body, ['name', 'activeIngredient', 'form', 'dosage', 'stockQuantity', 'alertThreshold', 'lot', 'expirationDate', 'price', 'pharmacyId']);
  const pharmacyId = pharmacyIdFor(req.user) || body.pharmacyId;
  if (!pharmacyId) throw new HttpError(400, 'pharmacyId is required.');
  const medication = await Medication.create({ ...parseMedicationFields(body, true), pharmacyId: requireId(pharmacyId, 'pharmacyId') });
  return res.status(201).json({ medication: medicationResponse(medication) });
}

async function updateMedication(req, res) {
  const body = requireObject(req.body);
  rejectUnknownFields(body, ['name', 'activeIngredient', 'form', 'dosage', 'stockQuantity', 'alertThreshold', 'lot', 'expirationDate', 'price']);
  const medication = await findScopedMedication(req.user, req.params.id);
  const fields = parseMedicationFields(body);
  if (!Object.keys(fields).length) throw new HttpError(400, 'At least one field must be provided.');
  const updated = await Medication.findByIdAndUpdate(medication._id, { $set: fields }, { new: true, runValidators: true });
  return res.json({ medication: medicationResponse(updated) });
}

async function adjustStock(req, res) {
  const body = requireObject(req.body);
  rejectUnknownFields(body, ['quantity']);
  const quantity = stockDelta(body.quantity);
  const medication = await findScopedMedication(req.user, req.params.id);
  const updated = await Medication.findOneAndUpdate(
    { _id: medication._id, stockQuantity: { $gte: quantity < 0 ? Math.abs(quantity) : 0 } },
    { $inc: { stockQuantity: quantity } }, { new: true },
  );
  if (!updated) throw new HttpError(409, 'Stock cannot become negative.');
  return res.json({ medication: medicationResponse(updated) });
}

async function listPrescriptions(req, res) {
  const query = { ...scopeQuery(req.user) };
  if (req.query.status) query.status = String(req.query.status);
  const prescriptions = await Prescription.find(query)
    .populate('patientId', 'username firstName lastName allergies')
    .populate('doctorId', 'username firstName lastName')
    .sort({ createdAt: -1 }).limit(500);
  return res.json({ prescriptions: prescriptions.map(prescriptionResponse) });
}

async function createPrescription(req, res) {
  const body = requireObject(req.body);
  rejectUnknownFields(body, ['patientId', 'doctorId', 'pharmacyId', 'medications']);
  const pharmacyId = pharmacyIdFor(req.user) || requireId(body.pharmacyId, 'pharmacyId');
  const items = parseItems(body.medications).map((item) => ({ ...item, name: item.name || '' }));
  for (const item of items) {
    const medication = await findScopedMedication({ role: req.user.role, pharmacyId }, item.medicationId);
    item.name = medication.name;
  }
  const prescription = await Prescription.create({
    patientId: requireId(body.patientId, 'patientId'), doctorId: requireId(body.doctorId, 'doctorId'), pharmacyId, medications: items,
  });
  return res.status(201).json({ prescription: prescriptionResponse(prescription) });
}

async function changePrescriptionStatus(req, res) {
  const body = requireObject(req.body);
  rejectUnknownFields(body, ['reason']);
  const prescription = await Prescription.findOne({ _id: requireId(req.params.id, 'prescription id'), ...scopeQuery(req.user) });
  if (!prescription) throw new HttpError(404, 'Prescription not found.');
  const action = req.params.action;
  if (action === 'validate') {
    if (prescription.status !== 'pending') throw new HttpError(409, 'Only pending prescriptions can be validated.');
    prescription.status = 'validated'; prescription.validatedAt = new Date(); prescription.rejectionReason = '';
  } else if (action === 'reject') {
    const reason = requireString(body.reason, 'reason', { max: 500 });
    if (prescription.status === 'dispensed') throw new HttpError(409, 'A dispensed prescription cannot be rejected.');
    prescription.status = 'rejected'; prescription.rejectionReason = reason;
  } else throw new HttpError(400, 'Unsupported prescription action.');
  await prescription.save();
  return res.json({ prescription: prescriptionResponse(prescription) });
}

async function dispense(req, res) {
  const prescription = await Prescription.findOne({ _id: requireId(req.params.id, 'prescription id'), ...scopeQuery(req.user) });
  if (!prescription) throw new HttpError(404, 'Prescription not found.');
  if (!['pending', 'validated'].includes(prescription.status)) throw new HttpError(409, 'This prescription cannot be dispensed.');
  const now = new Date();
  const changed = [];
  try {
    for (const item of prescription.medications) {
      const medication = await Medication.findOneAndUpdate(
        { _id: item.medicationId, ...scopeQuery(req.user), stockQuantity: { $gte: item.quantity }, expirationDate: { $gt: now } },
        { $inc: { stockQuantity: -item.quantity } }, { new: true },
      );
      if (!medication) throw new HttpError(409, `Insufficient stock or expired lot for ${item.name}.`);
      changed.push({ medication, quantity: item.quantity });
    }
    prescription.status = 'dispensed'; prescription.dispensedAt = now;
    await prescription.save();
    const dispensation = await Dispensation.create({
      prescriptionId: prescription._id, pharmacistId: req.user._id, pharmacyId: prescription.pharmacyId,
      medications: prescription.medications.map((item) => ({ medicationId: item.medicationId, name: item.name, quantity: item.quantity })),
      dispensedAt: now,
    });
    return res.status(201).json({ dispensation: dispensationResponse(dispensation), prescription: prescriptionResponse(prescription) });
  } catch (error) {
    await Promise.all(changed.map((item) => Medication.updateOne({ _id: item.medication._id }, { $inc: { stockQuantity: item.quantity } })));
    throw error;
  }
}

async function listDispensations(req, res) {
  const items = await Dispensation.find(scopeQuery(req.user)).sort({ dispensedAt: -1 }).limit(500);
  return res.json({ dispensations: items.map(dispensationResponse) });
}

async function listRequests(req, res) {
  const items = await MedicationRequest.find(scopeQuery(req.user)).sort({ createdAt: -1 }).limit(500);
  return res.json({ requests: items.map(requestResponse) });
}

async function changeRequestStatus(req, res) {
  const body = requireObject(req.body);
  rejectUnknownFields(body, ['reason']);
  const item = await MedicationRequest.findOne({ _id: requireId(req.params.id, 'request id'), ...scopeQuery(req.user) });
  if (!item) throw new HttpError(404, 'Medication request not found.');
  const action = req.params.action;
  const next = { approve: 'approved', reject: 'rejected', deliver: 'delivered' }[action];
  if (!next) throw new HttpError(400, 'Unsupported request action.');
  if (next === 'rejected') item.rejectionReason = requireString(body.reason, 'reason', { max: 500 });
  item.status = next;
  await item.save();
  return res.json({ request: requestResponse(item) });
}

async function listOrders(req, res) {
  const items = await SupplyOrder.find(scopeQuery(req.user)).sort({ createdAt: -1 }).limit(500);
  return res.json({ orders: items.map(orderResponse) });
}

async function createOrder(req, res) {
  const body = requireObject(req.body);
  rejectUnknownFields(body, ['supplier', 'medications', 'pharmacyId']);
  const pharmacyId = pharmacyIdFor(req.user) || body.pharmacyId;
  const items = parseItems(body.medications).map((item) => ({ ...item, name: item.name || '' }));
  for (const item of items) {
    const medication = await findScopedMedication({ role: req.user.role, pharmacyId }, item.medicationId);
    item.name = medication.name;
  }
  const order = await SupplyOrder.create({ pharmacyId, supplier: requireString(body.supplier, 'supplier', { max: 160 }), medications: items });
  return res.status(201).json({ order: orderResponse(order) });
}

async function receiveOrder(req, res) {
  const order = await SupplyOrder.findOne({ _id: requireId(req.params.id, 'order id'), ...scopeQuery(req.user) });
  if (!order) throw new HttpError(404, 'Supply order not found.');
  if (order.status === 'received') throw new HttpError(409, 'Supply order is already received.');
  for (const item of order.medications) {
    await Medication.updateOne({ _id: item.medicationId, ...scopeQuery(req.user) }, { $inc: { stockQuantity: item.quantity } });
  }
  order.status = 'received'; order.receivedAt = new Date(); await order.save();
  return res.json({ order: orderResponse(order) });
}

async function alerts(req, res) {
  const scope = scopeQuery(req.user);
  const now = new Date();
  const soon = new Date(now.getTime() + 30 * 24 * 60 * 60 * 1000);
  const medications = await Medication.find({ ...scope, $or: [{ stockQuantity: 0 }, { $expr: { $lte: ['$stockQuantity', '$alertThreshold'] } }, { expirationDate: { $gt: now, $lte: soon } }] }).sort({ expirationDate: 1 });
  return res.json({ medications: medications.map(medicationResponse) });
}

module.exports = {
  listPharmacies, listMedications, createMedication, updateMedication, adjustStock,
  listPrescriptions, createPrescription, changePrescriptionStatus, dispense,
  listDispensations, listRequests, changeRequestStatus, listOrders, createOrder,
  receiveOrder, alerts, medicationResponse, prescriptionResponse,
};
