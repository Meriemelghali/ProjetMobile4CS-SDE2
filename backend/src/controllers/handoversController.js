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

function handoverResponse(handover, userId) {
  return {
    _id: handover._id,
    serviceId: handover.serviceId,
    authorId: handover.authorId?._id || handover.authorId,
    authorName: handover.authorId?.username || '',
    title: handover.title,
    content: handover.content,
    important: handover.important,
    createdAt: handover.createdAt,
    isRead: (handover.readBy || []).some((id) => id.toString() === userId?.toString()),
  };
}

async function list(req, res) {
  const query = {};
  if (req.user.role !== 'admin') {
    const assignedServiceId = req.user.serviceId?.toString();
    if (req.query.serviceId !== undefined &&
        req.query.serviceId !== assignedServiceId) {
      throw new HttpError(403, 'You can only view handovers for your service.');
    }
    query.serviceId = assignedServiceId || null;
  } else if (req.query.serviceId !== undefined) {
    query.serviceId = requireId(req.query.serviceId, 'serviceId');
  }
  const handovers = await Handover.find(query)
    .populate('authorId', 'username')
    .sort({ createdAt: -1 })
    .limit(500);
  return res.json({
    handovers: handovers.map((handover) => handoverResponse(handover, req.user.id)),
  });
}

async function create(req, res) {
  const body = requireObject(req.body);
  rejectUnknownFields(body, ['serviceId', 'title', 'content', 'important']);
  const serviceId = requireId(body.serviceId, 'serviceId');
  if (!(await Service.exists({ _id: serviceId }))) {
    throw new HttpError(400, 'serviceId does not exist.');
  }
  if (req.user.role !== 'admin' &&
      serviceId !== req.user.serviceId?.toString()) {
    throw new HttpError(403, 'You can only create handovers for your service.');
  }
  const handover = await Handover.create({
    serviceId,
    authorId: req.user.id,
    title: requireString(body.title, 'title', { max: 160 }),
    content: requireString(body.content, 'content', { max: 5000 }),
    important: body.important === undefined ? false : requireBoolean(body.important, 'important'),
    readBy: [req.user.id],
  });
  await handover.populate('authorId', 'username');
  return res.status(201).json({
    handover: handoverResponse(handover, req.user.id),
  });
}

async function markRead(req, res) {
  const id = requireId(req.params.id, 'handover id');
  const handover = await Handover.findById(id);
  if (!handover) throw new HttpError(404, 'Handover not found.');
  if (req.user.role !== 'admin' &&
      handover.serviceId.toString() !== req.user.serviceId?.toString()) {
    throw new HttpError(403, 'You can only read handovers for your service.');
  }
  const updated = await Handover.findByIdAndUpdate(
    id,
    { $addToSet: { readBy: req.user.id } },
    { new: true },
  ).populate('authorId', 'username');
  return res.json({ handover: handoverResponse(updated, req.user.id) });
}

module.exports = { list, create, markRead, handoverResponse };
