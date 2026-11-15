const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');

const PASSWORD_ROUNDS = 12;

function hashPassword(password) {
  return bcrypt.hash(password, PASSWORD_ROUNDS);
}

function verifyPassword(password, hash) {
  return bcrypt.compare(password, hash);
}

function createToken(user, config, role = user.role) {
  return jwt.sign({ sub: user.id, role, tokenType: 'access' }, config.jwtSecret, {
    expiresIn: config.jwtExpiresIn,
    issuer: 'hopital-connect',
    audience: 'hopital-connect-api',
  });
}

function createRoleSelectionToken(user, config) {
  return jwt.sign({ sub: user.id, purpose: 'role_selection' }, config.jwtSecret, {
    expiresIn: '5m',
    issuer: 'hopital-connect',
    audience: 'hopital-connect-api',
  });
}

function verifyToken(token, config) {
  return jwt.verify(token, config.jwtSecret, {
    issuer: 'hopital-connect',
    audience: 'hopital-connect-api',
  });
}

module.exports = {
  hashPassword,
  verifyPassword,
  createToken,
  createRoleSelectionToken,
  verifyToken,
};
