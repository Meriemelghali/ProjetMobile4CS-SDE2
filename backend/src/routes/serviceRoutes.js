const express = require('express');
const controller = require('../controllers/servicesController');
const pdfController = require('../controllers/servicePdfController');
const { authenticate } = require('../middleware/authenticate');
const { authorize } = require('../middleware/authorize');

const router = express.Router();

// Route PDF publique — accessible sans token pour le scan QR depuis n'importe quel téléphone
router.get('/:id/pdf', pdfController.getPdf);

router.use(authenticate);
router.get('/', authorize('admin', 'doctor', 'nurse', 'patient'), controller.list);
router.post('/', authorize('admin'), controller.create);
router.put('/:id', authorize('admin'), controller.update);

module.exports = router;
