const User = require('../models/User');
const { getConfig } = require('../config');
const { verifyToken } = require('../services/auth');
const { getUserRoles } = require('../utils/validation');
const { attachServiceHeadScope } = require('./resourceAccess');

async function authenticate(req, _res, next) {
  const header = req.get('authorization') || '';
  const match = /^Bearer\s+([^\s]+)$/i.exec(header);
  if (!match) {
    return next({ status: 401, message: 'A bearer token is required.' });
  }

  let payload;
  try {
    payload = verifyToken(match[1], getConfig());
  } catch {
    return next({ status: 401, message: 'Invalid or expired bearer token.' });
  }

  const user = await User.findById(payload.sub);
  if (!user || !user.active) {
    return next({ status: 401, message: 'Authentication is no longer valid.' });
  }
  if (!getUserRoles(user).includes(payload.role)) {
    return next({ status: 401, message: 'This role is no longer assigned to the account.' });
  }
  user.role = payload.role;
  if (user.role === 'service_head') await attachServiceHeadScope(user);
  req.user = user;
  return next();
}

module.exports = { authenticate };
