const mongoose = require('mongoose');
const { HttpError } = require('../errors');

const ROLES = ['admin', 'doctor', 'nurse', 'patient'];

function requireObject(value, label = 'Request body') {
  if (!value || typeof value !== 'object' || Array.isArray(value)) {
    throw new HttpError(400, `${label} must be a JSON object.`);
  }
  return value;
}

function requireString(value, field, { max = 200, min = 1 } = {}) {
  if (typeof value !== 'string') {
    throw new HttpError(400, `${field} must be a string.`);
  }
  const result = value.trim();
  if (result.length < min || result.length > max) {
    throw new HttpError(400, `${field} must be between ${min} and ${max} characters.`);
  }
  return result;
}

function requireEmail(value) {
  const email = requireString(value, 'email', { max: 254 }).toLowerCase();
  if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) {
    throw new HttpError(400, 'email must be a valid email address.');
  }
  return email;
}

function requirePassword(value) {
  if (typeof value !== 'string' || value.length < 10 || Buffer.byteLength(value, 'utf8') > 72) {
    throw new HttpError(400, 'password must be between 10 and 72 characters.');
  }
  return value;
}

function requireRole(value) {
  if (!ROLES.includes(value)) {
    throw new HttpError(400, `role must be one of: ${ROLES.join(', ')}.`);
  }
  return value;
}

function requireBoolean(value, field) {
  if (typeof value !== 'boolean') {
    throw new HttpError(400, `${field} must be a boolean.`);
  }
  return value;
}

function requireId(value, field) {
  if (typeof value !== 'string' || !mongoose.isObjectIdOrHexString(value)) {
    throw new HttpError(400, `${field} must be a valid identifier.`);
  }
  return value;
}

function requireDate(value, field) {
  const isoDateTime = /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d{1,3})?(?:Z|[+-]\d{2}:\d{2})$/;
  if (typeof value !== 'string' || !isoDateTime.test(value) || Number.isNaN(Date.parse(value))) {
    throw new HttpError(400, `${field} must be an ISO 8601 date-time with a timezone.`);
  }
  return new Date(value);
}

function requireDateOnly(value) {
  if (typeof value !== 'string' || !/^\d{4}-\d{2}-\d{2}$/.test(value)) {
    throw new HttpError(400, 'date must use YYYY-MM-DD format.');
  }
  const date = new Date(`${value}T00:00:00.000Z`);
  if (date.toISOString().slice(0, 10) !== value) {
    throw new HttpError(400, 'date must be a valid calendar date.');
  }
  return date;
}

function rejectUnknownFields(body, allowed) {
  const unknown = Object.keys(body).filter((key) => !allowed.includes(key));
  if (unknown.length) {
    throw new HttpError(400, `Unsupported field(s): ${unknown.join(', ')}.`);
  }
}

module.exports = {
  ROLES,
  requireObject,
  requireString,
  requireEmail,
  requirePassword,
  requireRole,
  requireBoolean,
  requireId,
  requireDate,
  requireDateOnly,
  rejectUnknownFields,
};
