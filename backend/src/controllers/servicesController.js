// =============================================================================
// CONTROLLER : servicesController
// Gère les opérations CRUD sur les services hospitaliers.
// Les nouveaux champs sont tous optionnels → rétrocompatible avec les collègues.
// =============================================================================

const Service = require('../models/Service');
const User = require('../models/User');
const Hospital = require('../models/Hospital');
const { HttpError } = require('../errors');
const { getUserRoles } = require('../utils/validation');
const {
  requireBoolean,
  requireId,
  requireObject,
  requireString,
  rejectUnknownFields,
} = require('../utils/validation');

// Liste de tous les champs acceptés (anciens + nouveaux)
// rejectUnknownFields refuse tout champ absent de cette liste
const FIELDS = [
  // Champs existants
  'name', 'description', 'location', 'active',
  'a_rdv', 'a_operations', 'a_gardes',
  // Nouveaux champs optionnels
  'serviceType', 'building', 'floor', 'capacity',
  'phone', 'email', 'headName', 'headUserId', 'openingHours', 'notes',
];

// Sérialise un document Mongoose en objet JSON renvoyé au client
function serviceResponse(service) {
  return {
    _id:          service._id,
    name:         service.name,
    location:     service.location,
    description:  service.description,
    active:       service.active,
    a_rdv:        service.a_rdv === true,
    a_operations: service.a_operations === true,
    a_gardes:     service.a_gardes === true,
    // Nouveaux champs — valeur par défaut '' si absent (vieux document)
    serviceType:  service.serviceType  ?? '',
    building:     service.building     ?? '',
    floor:        service.floor        ?? '',
    capacity:     service.capacity     ?? 0,
    phone:        service.phone        ?? '',
    email:        service.email        ?? '',
    headName:     service.headName     ?? '',
    headUserId:   service.headUserId?._id || service.headUserId || null,
    openingHours: service.openingHours ?? '',
    notes:        service.notes        ?? '',
  };
}

// Extrait et valide les champs du body de la requête
// creating=true : tous les champs obligatoires sont requis
// creating=false : seuls les champs présents dans le body sont traités
async function parseFields(body, creating = false) {
  const fields = {};

  // --- Champs existants ---
  if (creating || body.name !== undefined)
    fields.name = requireString(body.name, 'name', { max: 120 });

  if (creating || body.description !== undefined)
    fields.description = body.description === undefined
      ? '' : requireString(body.description, 'description', { max: 1000, min: 0 });

  if (creating || body.location !== undefined)
    fields.location = body.location === undefined
      ? '' : requireString(body.location, 'location', { max: 160, min: 0 });

  if (creating || body.active !== undefined)
    fields.active = body.active === undefined
      ? true : requireBoolean(body.active, 'active');

  for (const field of ['a_rdv', 'a_operations', 'a_gardes']) {
    if (body[field] !== undefined) {
      fields[field] = body[field] === null
        ? false
        : requireBoolean(body[field], field);
    }
  }

  // --- Nouveaux champs optionnels ---
  if (body.serviceType !== undefined)
    fields.serviceType = requireString(body.serviceType, 'serviceType', { max: 60, min: 0 });

  if (body.building !== undefined)
    fields.building = requireString(body.building, 'building', { max: 80, min: 0 });

  if (body.floor !== undefined)
    fields.floor = requireString(body.floor, 'floor', { max: 40, min: 0 });

  if (body.capacity !== undefined) {
    const cap = Number(body.capacity);
    if (!Number.isFinite(cap) || cap < 0)
      throw new HttpError(400, 'capacity must be a non-negative number.');
    fields.capacity = Math.floor(cap); // Entier positif
  }

  if (body.phone !== undefined)
    fields.phone = requireString(body.phone, 'phone', { max: 30, min: 0 });

  if (body.email !== undefined)
    fields.email = requireString(body.email, 'email', { max: 120, min: 0 });

  if (body.headName !== undefined)
    fields.headName = requireString(body.headName, 'headName', { max: 120, min: 0 });

  if (body.headUserId !== undefined) {
    if (body.headUserId === null || body.headUserId === '') {
      fields.headUserId = null;
      fields.headName = '';
    } else {
      const id = requireId(body.headUserId, 'headUserId');
      const head = await User.findById(id).select('username role roles active');
      if (!head || !getUserRoles(head).includes('service_head') || !head.active) {
        throw new HttpError(400, 'headUserId must reference an active service head.');
      }
      fields.headUserId = head._id;
      fields.headName = head.username;
    }
  }

  if (body.openingHours !== undefined)
    fields.openingHours = requireString(body.openingHours, 'openingHours', { max: 200, min: 0 });

  if (body.notes !== undefined)
    fields.notes = requireString(body.notes, 'notes', { max: 500, min: 0 });

  return fields;
}

// GET /services — liste tous les services triés par nom
async function list(req, res) {
  const query = {};
  if (req.user.role === 'patient') query.active = true;
  if (['doctor', 'nurse', 'secretary'].includes(req.user.role)) {
    const ids = [
      ...(req.user.serviceIds || []).map((id) => id.toString()),
      ...(req.user.serviceId ? [req.user.serviceId.toString()] : []),
    ];
    query._id = { $in: [...new Set(ids)] };
  }
  if (req.user.role === 'service_head') {
    query._id = req.user.serviceId
      ? req.user.serviceId
      : await Service.find({ headUserId: req.user._id }).distinct('_id');
  }
  if (req.user.role === 'operating_room_manager') {
    const hospitalId = req.user.hospitalId;
    if (!hospitalId) throw new HttpError(403, 'A hospital assignment is required.');
    const hospital = await Hospital.findById(hospitalId).select('serviceIds');
    if (!hospital) throw new HttpError(403, 'A hospital assignment is required.');
    query._id = { $in: hospital.serviceIds };
  }
  const services = await Service.find(query).sort({ name: 1 }).limit(200);
  return res.json({ services: services.map(serviceResponse) });
}

// POST /services — crée un nouveau service
async function create(req, res) {
  const body = requireObject(req.body);
  rejectUnknownFields(body, FIELDS);
  const service = await Service.create(await parseFields(body, true));
  return res.status(201).json({ service: serviceResponse(service) });
}

// PUT /services/:id — met à jour un service existant
async function update(req, res) {
  const id = requireId(req.params.id, 'service id');
  const body = requireObject(req.body);
  rejectUnknownFields(body, FIELDS);
  const fields = await parseFields(body);
  if (!Object.keys(fields).length)
    throw new HttpError(400, 'At least one field must be provided.');
  const service = await Service.findByIdAndUpdate(
    id,
    { $set: fields },
    { new: true, runValidators: true }
  );
  if (!service) throw new HttpError(404, 'Service not found.');
  return res.json({ service: serviceResponse(service) });
}

module.exports = { list, create, update, serviceResponse };
