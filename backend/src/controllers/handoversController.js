const Handover = require('../models/Handover');
const Service = require('../models/Service');
const { HttpError } = require('../errors');
const {
  requireBoolean,
  requireId,
  requireObject,
  requireString,
  rejectUnknownFields,
} = require('../utils/validation');

function handoverResponse(handover) {
  return {
    _id: handover._id,
    serviceId: handover.serviceId,
    authorId: handover.authorId?._id || handover.authorId,
    authorName: handover.authorId?.username || '',
    title: handover.title,
    content: handover.content,
    important: handover.important,
    createdAt: handover.createdAt,
  };
}

async function list(req, res) {
  const query = {};
  if (req.user.role === 'service_head') {
    const service = await Service.findOne({ headUserId: req.user._id }).select('_id');
    if (!service) throw new HttpError(403, 'No service is assigned to this service head.');
    query.serviceId = service._id;
  } else if (req.user.role === 'secretary') {
    if (!req.user.serviceId) return res.json({ handovers: [] });
    query.serviceId = req.user.serviceId;
  } else if (req.query.serviceId !== undefined) {
    query.serviceId = requireId(req.query.serviceId, 'serviceId');
  }
  const handovers = await Handover.find(query)
    .populate('authorId', 'username')
    .sort({ createdAt: -1 })
    .limit(500);
  return res.json({ handovers: handovers.map(handoverResponse) });
}

async function create(req, res) {
  const body = requireObject(req.body);
  rejectUnknownFields(body, ['serviceId', 'title', 'content', 'important']);
  const serviceId = requireId(body.serviceId, 'serviceId');
  const serviceQuery = { _id: serviceId };
  if (req.user.role === 'service_head') serviceQuery.headUserId = req.user._id;
  if (!(await Service.exists(serviceQuery))) {
    throw new HttpError(400, 'serviceId does not exist.');
  }
  const handover = await Handover.create({
    serviceId,
    authorId: req.user.id,
    title: requireString(body.title, 'title', { max: 160 }),
    content: requireString(body.content, 'content', { max: 5000 }),
    important: body.important === undefined ? false : requireBoolean(body.important, 'important'),
  });
  await handover.populate('authorId', 'username');
  return res.status(201).json({ handover: handoverResponse(handover) });
}

module.exports = { list, create, handoverResponse };
