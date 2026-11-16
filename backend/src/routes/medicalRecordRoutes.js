const express = require('express');
const controller = require('../controllers/medicalRecordsController');
const { authenticate } = require('../middleware/authenticate');
const { authorize } = require('../middleware/authorize');

// Dossier médical : accessible aux soignants, aux patients pour leur dossier, et aux administrateurs.
const router = express.Router();
router.use(authenticate);
router.get('/patients', authorize('doctor', 'nurse', 'admin', 'administrator'), controller.searchPatients);
router.get('/me', authorize('patient'), controller.getMine);
router.put('/consultations/:id', authorize('doctor', 'admin', 'administrator'), controller.updateConsultation);
router.get('/:patientId', authorize('doctor', 'nurse', 'patient', 'admin', 'administrator'), controller.getRecord);
router.put('/:patientId', authorize('doctor', 'admin', 'administrator'), controller.updateRecord);
router.post('/:patientId/consultations', authorize('doctor', 'admin', 'administrator'), controller.createConsultation);
router.post('/:patientId/vitals', authorize('doctor', 'nurse', 'admin', 'administrator'), controller.createVitals);

module.exports = router;
