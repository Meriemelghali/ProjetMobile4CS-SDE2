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
  if (req.query.serviceId !== undefined) {
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
  if (!(await Service.exists({ _id: serviceId }))) {
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
