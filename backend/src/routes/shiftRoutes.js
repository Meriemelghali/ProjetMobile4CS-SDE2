const express = require('express');
const controller = require('../controllers/shiftsController');
const { authenticate } = require('../middleware/authenticate');
const { authorize } = require('../middleware/authorize');

const router = express.Router();
router.use(authenticate);
router.get('/', authorize('admin', 'doctor', 'nurse', 'secretary', 'service_head'), controller.list);
router.post('/', authorize('admin', 'service_head'), controller.create);
router.put('/:id', authorize('admin', 'service_head'), controller.update);
router.delete('/:id', authorize('admin', 'service_head'), controller.remove);

module.exports = router;
