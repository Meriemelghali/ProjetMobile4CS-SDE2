const Service = require('../models/Service');
const { HttpError } = require('../errors');
const {
  requireBoolean,
  requireId,
  requireObject,
  requireString,
  rejectUnknownFields,
} = require('../utils/validation');

const FIELDS = ['name', 'description', 'location', 'active'];

function serviceResponse(service) {
  return {
    _id: service._id,
    name: service.name,
    location: service.location,
    description: service.description,
    active: service.active,
  };
}

function parseFields(body, creating = false) {
  const fields = {};
  if (creating || body.name !== undefined) fields.name = requireString(body.name, 'name', { max: 120 });
  if (creating || body.description !== undefined) {
    fields.description = body.description === undefined ? '' : requireString(body.description, 'description', { max: 1000, min: 0 });
  }
  if (creating || body.location !== undefined) {
    fields.location = body.location === undefined ? '' : requireString(body.location, 'location', { max: 160, min: 0 });
  }
  if (creating || body.active !== undefined) {
    fields.active = body.active === undefined ? true : requireBoolean(body.active, 'active');
  }
  return fields;
}

async function list(_req, res) {
  const services = await Service.find().sort({ name: 1 }).limit(200);
  return res.json({ services: services.map(serviceResponse) });
}

async function create(req, res) {
  const body = requireObject(req.body);
  rejectUnknownFields(body, FIELDS);
  const service = await Service.create(parseFields(body, true));
  return res.status(201).json({ service: serviceResponse(service) });
}

async function update(req, res) {
  const id = requireId(req.params.id, 'service id');
  const body = requireObject(req.body);
  rejectUnknownFields(body, FIELDS);
  const fields = parseFields(body);
  if (!Object.keys(fields).length) throw new HttpError(400, 'At least one field must be provided.');
  const service = await Service.findByIdAndUpdate(id, { $set: fields }, {
    new: true,
    runValidators: true,
  });
  if (!service) throw new HttpError(404, 'Service not found.');
  return res.json({ service: serviceResponse(service) });
}

module.exports = { list, create, update, serviceResponse };
