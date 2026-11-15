const express = require('express');
const controller = require('../controllers/medicalRecordsController');
const { authenticate } = require('../middleware/authenticate');
const { authorize } = require('../middleware/authorize');

// Dossier médical : contenu réservé aux soignants et au patient concerné.
// L'administrateur gère les comptes mais n'accède pas au contenu médical.
const router = express.Router();
router.use(authenticate);
router.get('/patients', authorize('doctor', 'nurse'), controller.searchPatients);
router.get('/me', authorize('patient'), controller.getMine);
router.put('/consultations/:id', authorize('doctor'), controller.updateConsultation);
router.get('/:patientId', authorize('doctor', 'nurse', 'patient'), controller.getRecord);
router.put('/:patientId', authorize('doctor'), controller.updateRecord);
router.post('/:patientId/consultations', authorize('doctor'), controller.createConsultation);
router.post('/:patientId/vitals', authorize('doctor', 'nurse'), controller.createVitals);

module.exports = router;
