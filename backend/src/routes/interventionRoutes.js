const express = require('express');
const controller = require('../controllers/operatingResourcesController');
const { authenticate } = require('../middleware/authenticate');
const { authorize } = require('../middleware/authorize');

const router = express.Router();
router.use(authenticate);
router.get('/', authorize('admin', 'doctor', 'nurse', 'secretary', 'service_head'), controller.listInterventions);
router.post('/', authorize('admin'), controller.createIntervention);
router.put('/:id', authorize('admin'), controller.updateIntervention);
router.delete('/:id', authorize('admin'), controller.deleteIntervention);

module.exports = router;
