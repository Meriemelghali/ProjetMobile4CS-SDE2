const express = require('express');
const controller = require('../controllers/appointmentsController');
const { authenticate } = require('../middleware/authenticate');
const { authorize } = require('../middleware/authorize');

const router = express.Router();
router.use(authenticate);
router.get('/doctors', authorize('admin', 'secretary', 'patient'), controller.listDoctors);
router.get('/availability', authorize('admin', 'secretary', 'patient'), controller.available);
router.get('/', authorize('admin', 'doctor', 'secretary', 'patient'), controller.list);
router.post('/', authorize('patient'), controller.create);
router.put('/:id', authorize('admin', 'doctor', 'secretary', 'patient'), controller.update);
router.post('/:id/claim', authorize('admin', 'secretary'), controller.claim);
router.post('/:id/release', authorize('admin', 'secretary'), controller.release);
router.post('/:id/decision', authorize('admin', 'secretary'), controller.decide);
router.post('/:id/proposal-response', authorize('patient'), controller.respondToProposal);

module.exports = router;
