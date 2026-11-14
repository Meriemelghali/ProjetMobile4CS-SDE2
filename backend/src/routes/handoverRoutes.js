const express = require('express');
const controller = require('../controllers/handoversController');
const { authenticate } = require('../middleware/authenticate');
const { authorize } = require('../middleware/authorize');

const router = express.Router();
router.use(authenticate);
router.get('/', authorize('admin', 'doctor', 'nurse', 'secretary', 'service_head'), controller.list);
router.post('/', authorize('admin', 'doctor', 'nurse', 'service_head'), controller.create);

module.exports = router;
