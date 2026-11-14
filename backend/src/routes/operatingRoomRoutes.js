const express = require('express');
const controller = require('../controllers/operatingResourcesController');
const { authenticate } = require('../middleware/authenticate');
const { authorize } = require('../middleware/authorize');

const router = express.Router();
router.use(authenticate);
router.get('/', authorize('admin', 'doctor', 'nurse', 'secretary', 'service_head'), controller.listOperatingRooms);
router.post('/', authorize('admin'), controller.createOperatingRoom);
router.put('/:id', authorize('admin'), controller.updateOperatingRoom);
router.delete('/:id', authorize('admin'), controller.deleteOperatingRoom);

module.exports = router;
