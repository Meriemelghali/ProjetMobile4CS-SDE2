const express = require('express');
const controller = require('../controllers/usersController');
const { authenticate } = require('../middleware/authenticate');
const { authorize } = require('../middleware/authorize');

const router = express.Router();
router.use(authenticate);
router.get('/', authorize('admin'), controller.list);
router.post('/', authorize('admin'), controller.create);
router.put('/:id', authorize('admin'), controller.update);

module.exports = router;
