const mongoose = require('mongoose');
const { getConfig } = require('../src/config');
const User = require('../src/models/User');
const { hashPassword } = require('../src/services/auth');
const {
  requireEmail,
  requirePassword,
  requireString,
} = require('../src/utils/validation');

async function main() {
  const [usernameArg, emailArg] = process.argv.slice(2);
  const passwordArg = process.env.BOOTSTRAP_ADMIN_PASSWORD;
  if (!usernameArg || !emailArg || !passwordArg || process.argv.length !== 4) {
    throw new Error('Usage: set BOOTSTRAP_ADMIN_PASSWORD, then run npm run bootstrap:admin -- <username> <email>');
  }
  const username = requireString(usernameArg, 'username', { max: 120 });
  const email = requireEmail(emailArg);
  const password = requirePassword(passwordArg);
  delete process.env.BOOTSTRAP_ADMIN_PASSWORD;

  await mongoose.connect(getConfig().mongoUri);
  const bootstrapKey = 'initial-admin';
  const existing = await User.findOne({ bootstrapKey }).select('+bootstrapKey');
  if (existing) {
    throw new Error(`The initial administrator already exists (${existing.email}).`);
  }

  await User.create({
    username,
    email,
    passwordHash: await hashPassword(password),
    role: 'admin',
    active: true,
    bootstrapKey,
  });
  console.log(`Initial administrator ${email} created.`);
}

main()
  .catch((error) => {
    console.error(`Administrator bootstrap failed: ${error.message}`);
    process.exitCode = 1;
  })
  .finally(async () => {
    if (mongoose.connection.readyState !== 0) await mongoose.disconnect();
  });
