const express = require('express');
const controller = require('../controllers/hospitalResourcesController');
const { authenticate } = require('../middleware/authenticate');
const { authorize } = require('../middleware/authorize');

const router = express.Router();
router.use(authenticate);
router.get('/', authorize(
  'admin', 'doctor', 'nurse', 'secretary', 'service_head',
  'operating_room_manager',
), controller.listBeds);
router.post('/', authorize('admin', 'service_head'), controller.createBed);
router.put('/:id', authorize(
  'admin', 'service_head', 'doctor', 'nurse',
), controller.updateBed);
router.delete('/:id', authorize('admin', 'service_head'), controller.deleteBed);
router.put('/:id/assignment', authorize(
  'admin', 'service_head', 'nurse',
), controller.assignBed);
router.delete('/:id/assignment', authorize(
  'admin', 'service_head', 'nurse',
), controller.dischargeBed);

module.exports = router;
