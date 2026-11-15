const mongoose = require('mongoose');
const app = require('./app');
const { getConfig } = require('./config');
const { ensureDefaultHospital } = require('./services/defaultHospital');
const Room = require('./models/Room');
const OperatingRoom = require('./models/OperatingRoom');
const { ensureDefaultPharmacy } = require('./services/defaultPharmacy');

async function start() {
  const config = getConfig();
  await mongoose.connect(config.mongoUri);
  const removedRoomIndexes = await Room.syncIndexes();
  if (removedRoomIndexes.some((index) => [
    'serviceId_1_number_1',
    'hospitalId_1_number_1',
    'hospitalId_1_floor_1_number_1',
  ].includes(index))) {
    console.log('Updated room number uniqueness to include its floor.');
  }
  const removedOperatingRoomIndexes = await OperatingRoom.syncIndexes();
  if (removedOperatingRoomIndexes.length > 0) {
    console.log('Synchronized operating room indexes.');
  }
  const createdDefaultHospital = await ensureDefaultHospital();
  if (createdDefaultHospital) {
    console.log('Created default hospital "Hôpital principal".');
  }
  const createdDefaultPharmacy = await ensureDefaultPharmacy();
  if (createdDefaultPharmacy) {
    console.log('Created default pharmacy "Pharmacie hospitalière".');
  }
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
