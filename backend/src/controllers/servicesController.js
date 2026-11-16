// =============================================================================
// CONTROLLER : servicesController
// Gère les opérations CRUD sur les services hospitaliers.
// Les nouveaux champs sont tous optionnels → rétrocompatible avec les collègues.
// =============================================================================

const Service = require('../models/Service');
const User = require('../models/User');
const Hospital = require('../models/Hospital');
const Shift = require('../models/Shift');
const Room = require('../models/Room');
const OperatingRoom = require('../models/OperatingRoom');
const Equipment = require('../models/Equipment');
const Handover = require('../models/Handover');
const MedicationRequest = require('../models/MedicationRequest');
const Bed = require('../models/Bed');
const { HttpError } = require('../errors');
const {
  DEFAULT_DOCTOR_SERVICE_NAME,
} = require('../services/defaultDoctorService');
const { getUserRoles } = require('../utils/validation');
const { serviceIdsFor } = require('../middleware/resourceAccess');
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
  'serviceType', 'building', 'floor',
  'phone', 'email', 'headName', 'headUserId', 'openingHours', 'notes',
];

// Sérialise un document Mongoose en objet JSON renvoyé au client
function serviceResponse(service, { capacity = service.capacity ?? 0 } = {}) {
  return {
    _id:          service._id,
    name:         service.name === 'Chirurgie général'
      ? 'Chirurgie générale'
      : service.name,
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
    capacity,
    phone:        service.phone        ?? '',
    email:        service.email        ?? '',
    headName:     service.headName     ?? '',
    headUserId:   service.headUserId?._id || service.headUserId || null,
    openingHours: service.openingHours ?? '',
    notes:        service.notes        ?? '',
  };
}

async function serviceResponses(services, {
  roomModel = Room,
  bedModel = Bed,
} = {}) {
  if (!services.length) return [];
  const rooms = await roomModel.find({
    serviceId: { $in: services.map((service) => service._id) },
  }).select('_id serviceId').lean();
  const capacityByService = new Map();
  if (rooms.length) {
    const bedCounts = await bedModel.aggregate([
      { $match: { roomId: { $in: rooms.map((room) => room._id) } } },
      { $group: { _id: '$roomId', count: { $sum: 1 } } },
    ]);
    const serviceByRoom = new Map(
      rooms.map((room) => [String(room._id), String(room.serviceId)]),
    );
    for (const item of bedCounts) {
      const serviceId = serviceByRoom.get(String(item._id));
      if (serviceId) {
        capacityByService.set(
          serviceId,
          (capacityByService.get(serviceId) || 0) + item.count,
        );
      }
    }
  }
  return services.map((service) => serviceResponse(service, {
    capacity: capacityByService.get(String(service._id)) || 0,
  }));
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
    const serviceIds = serviceIdsFor(req.user);
    if (serviceIds.length > 0) {
      query._id = { $in: serviceIds };
    }
  }
  if (req.user.role === 'operating_room_manager') {
    const hospitalId = req.user.hospitalId;
    if (hospitalId) {
      const hospital = await Hospital.findById(hospitalId).select('serviceIds');
      if (hospital && hospital.serviceIds && hospital.serviceIds.length > 0) {
        query._id = { $in: hospital.serviceIds };
      }
    }
  }
  const services = await Service.find(query).sort({ name: 1 }).limit(200);
  return res.json({ services: await serviceResponses(services) });
}

// POST /services — crée un nouveau service
async function create(req, res) {
  const body = requireObject(req.body);
  rejectUnknownFields(body, FIELDS);
  const service = await Service.create(await parseFields(body, true));
  const [response] = await serviceResponses([service]);
  return res.status(201).json({ service: response });
}

// PUT /services/:id — met à jour un service existant
async function update(req, res) {
  const id = requireId(req.params.id, 'service id');
  const body = requireObject(req.body);
  const service = await Service.findById(id);
  if (!service) throw new HttpError(404, 'Service not found.');
  if (req.user.role === 'service_head') {
    if (!serviceIdsFor(req.user).includes(String(service._id))) {
      throw new HttpError(403, 'You can only manage services assigned to you.');
    }
    rejectUnknownFields(body, [
      'name',
      'description',
      'location',
      'serviceType',
      'building',
      'floor',
      'phone',
      'email',
      'openingHours',
      'notes',
    ]);
  } else {
    rejectUnknownFields(body, FIELDS);
  }
  const fields = await parseFields(body);
  if (!Object.keys(fields).length)
    throw new HttpError(400, 'At least one field must be provided.');
  const updatedService = await Service.findByIdAndUpdate(
    id,
    { $set: fields },
    { new: true, runValidators: true }
  );
  if (!updatedService) throw new HttpError(404, 'Service not found.');
  const [response] = await serviceResponses([updatedService]);
  return res.json({ service: response });
}

async function hasServiceReferences(serviceId, {
  userModel = User,
  shiftModel = Shift,
  roomModel = Room,
  operatingRoomModel = OperatingRoom,
  equipmentModel = Equipment,
  handoverModel = Handover,
  medicationRequestModel = MedicationRequest,
} = {}) {
  const references = await Promise.all([
    userModel.exists({
      $or: [{ serviceId }, { serviceIds: serviceId }],
    }),
    shiftModel.exists({ serviceId }),
    roomModel.exists({ serviceId }),
    operatingRoomModel.exists({ serviceId }),
    equipmentModel.exists({ serviceId }),
    handoverModel.exists({ serviceId }),
    medicationRequestModel.exists({ serviceId }),
  ]);
  return references.some(Boolean);
}

async function remove(req, res) {
  const id = requireId(req.params.id, 'service id');
  const service = await Service.findById(id);
  if (!service) throw new HttpError(404, 'Service not found.');
  if (service.name === DEFAULT_DOCTOR_SERVICE_NAME) {
    throw new HttpError(409, 'Le service système « Médecin » ne peut pas être supprimé.');
  }
  if (await hasServiceReferences(service._id)) {
    throw new HttpError(
      409,
      'Ce service est encore utilisé. Retirez ses rattachements ou désactivez-le avant de le supprimer.',
    );
  }
  await Hospital.updateMany(
    { serviceIds: service._id },
    { $pull: { serviceIds: service._id } },
  );
  await service.deleteOne();
  return res.json({ service: serviceResponse(service) });
}

module.exports = {
  list,
  create,
  update,
  remove,
  hasServiceReferences,
  serviceResponse,
  serviceResponses,
};
