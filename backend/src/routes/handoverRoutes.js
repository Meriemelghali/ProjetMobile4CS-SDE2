const express = require('express');
const controller = require('../controllers/handoversController');
const { authenticate } = require('../middleware/authenticate');
const { authorize } = require('../middleware/authorize');

const router = express.Router();
router.use(authenticate);
router.get('/', authorize('admin', 'doctor', 'nurse'), controller.list);
router.post('/', authorize('admin', 'doctor', 'nurse'), controller.create);

module.exports = router;
