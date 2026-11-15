const express = require('express');
const controller = require('../controllers/authController');
const { authenticate } = require('../middleware/authenticate');

const router = express.Router();
router.post('/login', controller.login);
router.post('/select-role', controller.selectRole);
router.post('/register', controller.register);
router.post('/switch-role', authenticate, controller.switchRole);
router.get('/me', authenticate, controller.me);
router.put('/me', authenticate, controller.updateMe);

module.exports = router;
