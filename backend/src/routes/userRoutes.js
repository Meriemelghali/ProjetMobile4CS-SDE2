const express = require('express');
const controller = require('../controllers/usersController');
const { authenticate } = require('../middleware/authenticate');
const { authorize } = require('../middleware/authorize');

const router = express.Router();
router.use(authenticate);
router.get('/', authorize('admin'), controller.list);
router.get('/patients', authorize('admin', 'nurse', 'service_head'), controller.listAssignablePatients);
router.get('/intervention-participants', authorize('admin', 'doctor', 'secretary'), controller.listInterventionParticipants);
router.get('/service/:serviceId', authorize('admin', 'doctor', 'nurse'), controller.listServiceMembers);
router.post('/', authorize('admin'), controller.create);
router.put('/:id', authorize('admin'), controller.update);

module.exports = router;
