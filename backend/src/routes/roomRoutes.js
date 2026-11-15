const express = require('express');
const controller = require('../controllers/hospitalResourcesController');
const { authenticate } = require('../middleware/authenticate');
const { authorize } = require('../middleware/authorize');

const router = express.Router();
router.use(authenticate);
router.get('/', authorize(
  'admin', 'doctor', 'nurse', 'secretary', 'service_head',
  'operating_room_manager',
), controller.listRooms);
router.post('/', authorize('admin', 'service_head'), controller.createRoom);
router.get('/:id/occupancy', authorize(
  'admin', 'doctor', 'nurse', 'secretary', 'service_head',
  'operating_room_manager',
), controller.roomOccupancy);
router.put('/:id', authorize('admin', 'service_head'), controller.updateRoom);
router.delete('/:id', authorize('admin', 'service_head'), controller.deleteRoom);

module.exports = router;
