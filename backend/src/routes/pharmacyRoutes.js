const express = require('express');
const controller = require('../controllers/pharmacyController');
const { authenticate } = require('../middleware/authenticate');
const { authorize } = require('../middleware/authorize');

const router = express.Router();
router.use(authenticate);
router.get('/prescriptions/mine', authorize('patient'), controller.listPatientPrescriptions);
router.get('/medications', authorize('admin', 'pharmacist', 'doctor'), controller.listMedications);
router.post('/prescriptions', authorize('admin', 'pharmacist', 'doctor'), controller.createPrescription);
router.use(authorize('admin', 'pharmacist'));

router.get('/pharmacies', controller.listPharmacies);
router.post('/medications', controller.createMedication);
router.put('/medications/:id', controller.updateMedication);
router.put('/medications/:id/stock', controller.adjustStock);
router.get('/alerts', controller.alerts);
router.get('/prescriptions', controller.listPrescriptions);
router.post('/prescriptions/:id/dispense', controller.dispense);
router.post('/prescriptions/:id/:action', controller.changePrescriptionStatus);
router.get('/dispensations', controller.listDispensations);
router.get('/requests', controller.listRequests);
router.post('/requests/:id/:action', controller.changeRequestStatus);
router.get('/orders', controller.listOrders);
router.post('/orders', controller.createOrder);
router.post('/orders/:id/receive', controller.receiveOrder);

module.exports = router;
