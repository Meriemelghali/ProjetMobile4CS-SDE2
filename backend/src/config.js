const dotenv = require('dotenv');

dotenv.config();

function getConfig() {
  const jwtSecret = process.env.JWT_SECRET;
  if (
    !jwtSecret ||
    jwtSecret.length < 32 ||
    jwtSecret.includes('replace-with-a-random-secret')
  ) {
    throw new Error('JWT_SECRET must be set to at least 32 characters.');
  }

  const port = Number(process.env.PORT || 3000);
  if (!Number.isInteger(port) || port < 1 || port > 65535) {
    throw new Error('PORT must be a valid TCP port.');
  }

  return {
    nodeEnv: process.env.NODE_ENV || 'development',
    port,
    mongoUri: process.env.MONGODB_URI || 'mongodb://127.0.0.1:27017/hopital_connect',
    jwtSecret,
    jwtExpiresIn: process.env.JWT_EXPIRES_IN || '8h',
  };
}

module.exports = { getConfig };
