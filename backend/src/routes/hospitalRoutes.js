const express = require('express');
const controller = require('../controllers/hospitalResourcesController');
const { authenticate } = require('../middleware/authenticate');
const { authorize } = require('../middleware/authorize');

const router = express.Router();
router.use(authenticate);
router.get('/', authorize(
  'admin', 'doctor', 'nurse', 'secretary', 'service_head',
  'operating_room_manager',
), controller.listHospitals);
router.post('/', authorize('admin'), controller.createHospital);
router.put('/:id', authorize('admin'), controller.updateHospital);
router.delete('/:id', authorize('admin'), controller.deleteHospital);

module.exports = router;
