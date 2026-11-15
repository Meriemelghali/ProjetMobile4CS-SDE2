const express = require('express');
const controller = require('../controllers/operatingResourcesController');
const { authenticate } = require('../middleware/authenticate');
const { authorize } = require('../middleware/authorize');

const router = express.Router();
router.use(authenticate);
router.get('/', authorize(
  'admin', 'doctor', 'nurse', 'secretary', 'service_head',
  'operating_room_manager',
), controller.listEquipment);
router.post('/', authorize(
  'admin', 'service_head', 'operating_room_manager',
), controller.createEquipment);
router.put('/:id', authorize(
  'admin', 'service_head', 'operating_room_manager',
), controller.updateEquipment);
router.put('/:id/maintenance', authorize(
  'admin', 'service_head', 'operating_room_manager',
), controller.updateMaintenance);
router.delete('/:id', authorize('admin'), controller.deleteEquipment);

module.exports = router;
