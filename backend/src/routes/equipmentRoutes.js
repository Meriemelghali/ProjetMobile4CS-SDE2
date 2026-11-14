const express = require('express');
const controller = require('../controllers/operatingResourcesController');
const { authenticate } = require('../middleware/authenticate');
const { authorize } = require('../middleware/authorize');

const router = express.Router();
router.use(authenticate);
router.get('/', authorize('admin', 'doctor', 'nurse', 'secretary', 'service_head'), controller.listEquipment);
router.post('/', authorize('admin'), controller.createEquipment);
router.put('/:id', authorize('admin'), controller.updateEquipment);
router.put('/:id/maintenance', authorize('admin'), controller.updateMaintenance);
router.delete('/:id', authorize('admin'), controller.deleteEquipment);

module.exports = router;
