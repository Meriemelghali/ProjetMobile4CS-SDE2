const express = require('express');
const controller = require('../controllers/hospitalResourcesController');
const { authenticate } = require('../middleware/authenticate');
const { authorize } = require('../middleware/authorize');

const router = express.Router();
router.use(authenticate);
router.get('/', authorize('admin', 'doctor', 'nurse', 'secretary', 'service_head'), controller.listRooms);
router.post('/', authorize('admin'), controller.createRoom);
router.get('/:id/occupancy', authorize('admin', 'doctor', 'nurse', 'secretary', 'service_head'), controller.roomOccupancy);
router.put('/:id', authorize('admin'), controller.updateRoom);
router.delete('/:id', authorize('admin'), controller.deleteRoom);

module.exports = router;
