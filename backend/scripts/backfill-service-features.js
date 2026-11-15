const mongoose = require('mongoose');
const { getConfig } = require('../src/config');
const Service = require('../src/models/Service');

async function main() {
  await mongoose.connect(getConfig().mongoUri);
  try {
    for (const field of ['a_rdv', 'a_operations', 'a_gardes']) {
      const result = await Service.updateMany(
        { $or: [{ [field]: { $exists: false } }, { [field]: null }] },
        { $set: { [field]: false } },
      );
      console.log(`${field}: ${result.modifiedCount} service(s) set to false.`);
    }

    const result = await Service.updateMany(
      { name: /p[eé]diatrie/i },
      { $set: { a_operations: false } },
    );
    const pediatricServices = await Service.find({ name: /p[eé]diatrie/i })
      .select('name a_operations');
    if (!pediatricServices.length) {
      throw new Error('No service matching Pédiatrie was found in MongoDB.');
    }
    console.log(
      `Pédiatrie: ${result.modifiedCount} service(s) updated; verification:`,
      pediatricServices.map(({ name, a_operations }) => ({
        name,
        a_operations: a_operations === true,
      })),
    );
  } finally {
    await mongoose.disconnect();
  }
}

main().catch((error) => {
  console.error('Service feature migration failed:', error.message);
  process.exitCode = 1;
});
