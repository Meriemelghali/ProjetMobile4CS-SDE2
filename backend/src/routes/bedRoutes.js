const express = require('express');
const controller = require('../controllers/hospitalResourcesController');
const { authenticate } = require('../middleware/authenticate');
const { authorize } = require('../middleware/authorize');

const router = express.Router();
router.use(authenticate);
router.get('/', authorize('admin', 'doctor', 'nurse', 'secretary', 'service_head'), controller.listBeds);
router.post('/', authorize('admin'), controller.createBed);
router.put('/:id', authorize('admin'), controller.updateBed);
router.delete('/:id', authorize('admin'), controller.deleteBed);
router.put('/:id/assignment', authorize('admin'), controller.assignBed);
router.delete('/:id/assignment', authorize('admin'), controller.dischargeBed);

module.exports = router;
