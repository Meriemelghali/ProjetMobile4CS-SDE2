const mongoose = require('mongoose');
const app = require('./app');
const { getConfig } = require('./config');

async function start() {
  const config = getConfig();
  await mongoose.connect(config.mongoUri);
  const server = app.listen(config.port, () => {
    console.log(`HôpitalConnect API listening on port ${config.port}.`);
  });

  const shutdown = async () => {
    server.close(async () => {
      await mongoose.disconnect();
      process.exit(0);
    });
  };
  process.once('SIGINT', shutdown);
  process.once('SIGTERM', shutdown);
}

start().catch((error) => {
  console.error('Unable to start the API:', error.message);
  process.exitCode = 1;
});
