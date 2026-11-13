const User = require('../models/User');
const { getConfig } = require('../config');
const { verifyToken } = require('../services/auth');

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
  req.user = user;
  return next();
}

module.exports = { authenticate };
