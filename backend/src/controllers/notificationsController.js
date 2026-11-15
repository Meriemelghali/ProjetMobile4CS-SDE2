const Notification = require('../models/Notification');
const { HttpError } = require('../errors');
const { requireId } = require('../utils/validation');

function notificationResponse(notification) {
  return {
    _id: notification._id,
    appointmentId: notification.appointmentId,
    title: notification.title,
    message: notification.message,
    createdAt: notification.createdAt,
    readAt: notification.readAt,
  };
}

async function list(req, res) {
  const notifications = await Notification.find({ recipientId: req.user._id })
    .sort({ createdAt: -1 })
    .limit(100);
  return res.json({ notifications: notifications.map(notificationResponse) });
}

async function markRead(req, res) {
  const id = requireId(req.params.id, 'notification id');
  const notification = await Notification.findOneAndUpdate(
    { _id: id, recipientId: req.user._id, readAt: null },
    { $set: { readAt: new Date() } },
    { new: true },
  );
  if (!notification) {
    const existing = await Notification.exists({ _id: id, recipientId: req.user._id });
    if (!existing) throw new HttpError(404, 'Notification not found.');
    return res.json({ notification: notificationResponse(await Notification.findById(id)) });
  }
  return res.json({ notification: notificationResponse(notification) });
}

async function markAllRead(req, res) {
  await Notification.updateMany(
    { recipientId: req.user._id, readAt: null },
    { $set: { readAt: new Date() } },
  );
  return res.json({ updated: true });
}

module.exports = { list, markRead, markAllRead, notificationResponse };
