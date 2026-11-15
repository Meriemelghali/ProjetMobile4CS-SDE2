const express = require('express');
const controller = require('../controllers/operatingResourcesController');
const { authenticate } = require('../middleware/authenticate');
const { authorize } = require('../middleware/authorize');

const router = express.Router();
router.use(authenticate);
router.get('/', authorize(
  'admin', 'doctor', 'nurse', 'secretary', 'service_head',
  'operating_room_manager',
), controller.listOperatingRooms);
router.post('/', authorize('admin', 'operating_room_manager'), controller.createOperatingRoom);
router.put('/:id', authorize(
  'admin', 'operating_room_manager', 'nurse',
), controller.updateOperatingRoom);
router.delete('/:id', authorize('admin', 'operating_room_manager'), controller.deleteOperatingRoom);

module.exports = router;
