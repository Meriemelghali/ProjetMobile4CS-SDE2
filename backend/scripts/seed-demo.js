// Comptes et dossiers médicaux de démonstration (données 100 % fictives).
// Idempotent : relancer le script réinitialise uniquement les données démo.
//   npm run seed:demo
//   DEMO_PASSWORD="..." npm run seed:demo   (mot de passe personnalisé)
const mongoose = require('mongoose');
const { getConfig } = require('../src/config');
const User = require('../src/models/User');
const MedicalRecord = require('../src/models/MedicalRecord');
const Consultation = require('../src/models/Consultation');
const VitalSign = require('../src/models/VitalSign');
const { hashPassword } = require('../src/services/auth');
const { ensureDoctorService } = require('../src/services/defaultDoctorService');
const { requirePassword } = require('../src/utils/validation');

const DEMO_PASSWORD = process.env.DEMO_PASSWORD || 'HopitalDemo2026';
const DAY = 24 * 60 * 60 * 1000;
const daysAgo = (days, hour = 9) => {
  const date = new Date(Date.now() - days * DAY);
  date.setHours(hour, 0, 0, 0);
  return date;
};
const yearsAgo = (years, month = 4, day = 12) => {
  const date = new Date();
  return new Date(Date.UTC(date.getFullYear() - years, month, day));
};

const STAFF = [
  {
    email: 'admin.demo@demo.test', username: 'admin.demo', firstName: 'Nadia', lastName: 'Admin',
    role: 'admin',
  },
  {
    email: 'dr.karim.demo@demo.test', username: 'dr.karim', firstName: 'Karim', lastName: 'Haddad',
    role: 'doctor', specialty: 'Cardiologie', withService: true,
  },
  {
    email: 'inf.sarra.demo@demo.test', username: 'inf.sarra', firstName: 'Sarra', lastName: 'Mansour',
    role: 'nurse', withService: true,
  },
  {
    email: 'sec.lina.demo@demo.test', username: 'sec.lina', firstName: 'Lina', lastName: 'Chaabane',
    role: 'secretary', withService: true,
  },
];

const PATIENTS = [
  {
    user: {
      email: 'patient.yasmine.demo@demo.test', username: 'yasmine.bs', firstName: 'Yasmine',
      lastName: 'Ben Salah', birthDate: yearsAgo(34), phone: '+216 20 000 101',
      emergencyContact: 'Hichem Ben Salah (frère) · +216 20 000 102', insurance: 'CNAM',
      allergies: ['Pollen'],
    },
    record: {
      bloodType: 'A+',
      heightCm: 165,
      allergies: [
        { name: 'Pénicilline', severity: 'severe', reaction: 'Œdème de Quincke' },
        { name: 'Arachide', severity: 'moderate', reaction: 'Urticaire' },
      ],
      chronicConditions: [
        { name: 'Asthme allergique', since: yearsAgo(20), notes: 'Crises saisonnières (printemps).' },
      ],
      history: {
        medical: ['Bronchiolite sévère (enfance)'],
        surgical: ['Appendicectomie (2014)'],
        family: ['Mère : asthme', 'Père : hypertension artérielle'],
      },
      currentTreatments: [
        { name: 'Salbutamol 100 µg', dosage: '2 bouffées', frequency: 'Si besoin', startedAt: yearsAgo(10) },
        { name: 'Budésonide 200 µg', dosage: '1 inhalation', frequency: '2 fois / jour', startedAt: daysAgo(150) },
      ],
      vaccinations: [
        { name: 'Grippe saisonnière', date: daysAgo(60) },
        { name: 'Tétanos - Diphtérie', date: yearsAgo(3) },
      ],
    },
    consultations: [
      { days: 170, reason: 'Crise d’asthme', symptoms: 'Dyspnée sifflante, toux nocturne.', examination: 'Sibilants diffus, SpO2 92 %.', diagnosis: 'Exacerbation d’asthme modérée', notes: 'Nébulisation, mise en place d’un traitement de fond.' },
      { days: 140, reason: 'Contrôle asthme', symptoms: 'Amélioration nette.', examination: 'Auscultation claire.', diagnosis: 'Asthme partiellement contrôlé', notes: 'Poursuite du budésonide.' },
      { days: 95, reason: 'Réaction cutanée', symptoms: 'Urticaire après repas.', examination: 'Plaques érythémateuses du tronc.', diagnosis: 'Allergie alimentaire (arachide)', notes: 'Éviction, antihistaminique.' },
      { days: 40, reason: 'Bilan annuel', symptoms: 'Aucun.', examination: 'Examen normal.', diagnosis: 'Asthme contrôlé', notes: 'Spirométrie à prévoir.', followUp: -60 },
    ],
    vitals: (i) => ({
      systolic: 112 + (i % 3) * 3, diastolic: 72 + (i % 2) * 4,
      heartRate: i === 1 ? 112 : 74 + (i % 4) * 2,
      temperature: i === 1 ? 37.9 : 36.6 + (i % 3) * 0.1,
      spo2: i === 1 ? 92 : 97 + (i % 2),
      weightKg: 61 + (i % 3) * 0.4,
    }),
  },
  {
    user: {
      email: 'patient.omar.demo@demo.test', username: 'omar.g', firstName: 'Omar',
      lastName: 'Gharbi', birthDate: yearsAgo(58, 1, 3), phone: '+216 20 000 201',
      emergencyContact: 'Leila Gharbi (épouse) · +216 20 000 202', insurance: 'CNAM',
      allergies: [],
    },
    record: {
      bloodType: 'O+',
      heightCm: 176,
      allergies: [{ name: 'Iode (produits de contraste)', severity: 'moderate', reaction: 'Éruption cutanée' }],
      chronicConditions: [
        { name: 'Hypertension artérielle', since: yearsAgo(8), notes: 'Objectif < 135/85 mmHg.' },
        { name: 'Diabète de type 2', since: yearsAgo(5), notes: 'HbA1c 7,4 % au dernier bilan.' },
      ],
      history: {
        medical: ['Dyslipidémie'],
        surgical: ['Cure de hernie inguinale (2010)'],
        family: ['Père : infarctus à 62 ans', 'Frère : diabète de type 2'],
      },
      currentTreatments: [
        { name: 'Amlodipine 10 mg', dosage: '1 comprimé', frequency: 'Le matin', startedAt: daysAgo(120) },
        { name: 'Metformine 1000 mg', dosage: '1 comprimé', frequency: 'Matin et soir', startedAt: yearsAgo(5) },
        { name: 'Atorvastatine 20 mg', dosage: '1 comprimé', frequency: 'Le soir', startedAt: yearsAgo(4) },
      ],
      vaccinations: [
        { name: 'Grippe saisonnière', date: daysAgo(45) },
        { name: 'Pneumocoque', date: yearsAgo(2) },
      ],
    },
    consultations: [
      { days: 175, reason: 'Céphalées et tension élevée', symptoms: 'Céphalées matinales.', examination: 'TA 168/102 mmHg.', diagnosis: 'HTA non contrôlée', notes: 'Introduction amlodipine 5 mg, MAPA.' },
      { days: 120, reason: 'Suivi HTA', symptoms: 'Moins de céphalées.', examination: 'TA 150/94 mmHg.', diagnosis: 'HTA en amélioration', notes: 'Amlodipine augmentée à 10 mg.' },
      { days: 75, reason: 'Suivi diabète', symptoms: 'Polyurie modérée.', examination: 'Glycémie à jeun 1,62 g/L.', diagnosis: 'Diabète déséquilibré', notes: 'Renforcement diététique, bilan HbA1c.' },
      { days: 30, reason: 'Contrôle cardiovasculaire', symptoms: 'Asymptomatique.', examination: 'TA 134/84 mmHg, ECG normal.', diagnosis: 'HTA contrôlée', notes: 'Poursuite du traitement.', followUp: -90 },
      { days: 6, reason: 'Résultats biologiques', symptoms: 'Aucun.', examination: 'HbA1c 7,4 %.', diagnosis: 'Diabète en amélioration', notes: 'Objectif HbA1c < 7 %.' },
    ],
    vitals: (i) => ({
      systolic: Math.round(168 - i * 3.2), diastolic: Math.round(102 - i * 1.6),
      heartRate: 82 - (i % 3), weightKg: 91 - i * 0.35,
      glucose: Number((1.68 - i * 0.04).toFixed(2)), spo2: 97,
    }),
  },
  {
    user: {
      email: 'patient.amal.demo@demo.test', username: 'amal.j', firstName: 'Amal',
      lastName: 'Jaziri', birthDate: yearsAgo(72, 9, 21), phone: '+216 20 000 301',
      emergencyContact: 'Sami Jaziri (fils) · +216 20 000 302', insurance: 'Assurance privée',
      allergies: ['Aspirine'],
    },
    record: {
      bloodType: 'B-',
      heightCm: 158,
      allergies: [{ name: 'Aspirine', severity: 'severe', reaction: 'Bronchospasme' }],
      chronicConditions: [
        { name: 'Insuffisance cardiaque (FEVG 40 %)', since: yearsAgo(3), notes: 'Surveillance du poids quotidienne.' },
        { name: 'Fibrillation atriale', since: yearsAgo(2), notes: 'Anticoagulation au long cours.' },
      ],
      history: {
        medical: ['Hypothyroïdie', 'Arthrose des genoux'],
        surgical: ['Prothèse totale de hanche droite (2019)', 'Cataracte bilatérale (2021)'],
        family: ['Sœur : insuffisance cardiaque'],
      },
      currentTreatments: [
        { name: 'Bisoprolol 5 mg', dosage: '1 comprimé', frequency: 'Le matin', startedAt: yearsAgo(3) },
        { name: 'Apixaban 5 mg', dosage: '1 comprimé', frequency: 'Matin et soir', startedAt: yearsAgo(2) },
        { name: 'Furosémide 40 mg', dosage: '1 comprimé', frequency: 'Le matin', startedAt: daysAgo(80) },
        { name: 'Lévothyroxine 75 µg', dosage: '1 comprimé', frequency: 'À jeun', startedAt: yearsAgo(10) },
      ],
      vaccinations: [
        { name: 'Grippe saisonnière', date: daysAgo(50) },
        { name: 'COVID-19 (rappel)', date: daysAgo(200) },
        { name: 'Pneumocoque', date: yearsAgo(1) },
      ],
    },
    consultations: [
      { days: 160, reason: 'Palpitations', symptoms: 'Palpitations et fatigue.', examination: 'Pouls irrégulier à 118/min.', diagnosis: 'FA à réponse ventriculaire rapide', notes: 'Adaptation du bêtabloquant.' },
      { days: 82, reason: 'Œdèmes des membres inférieurs', symptoms: 'Prise de 3 kg en une semaine, essoufflement.', examination: 'Œdèmes bilatéraux, crépitants des bases.', diagnosis: 'Décompensation cardiaque', notes: 'Furosémide 40 mg, surveillance du poids.' },
      { days: 50, reason: 'Suivi insuffisance cardiaque', symptoms: 'Amélioration.', examination: 'Œdèmes régressifs.', diagnosis: 'Insuffisance cardiaque stabilisée', notes: 'Échocardiographie de contrôle.' },
      { days: 12, reason: 'Contrôle trimestriel', symptoms: 'Dyspnée d’effort stable.', examination: 'Poids stable, FC 72/min.', diagnosis: 'État stable', notes: 'Poursuite du traitement.', followUp: -80 },
    ],
    vitals: (i) => ({
      systolic: 128 + (i % 3) * 4, diastolic: 76 + (i % 2) * 3,
      heartRate: i <= 1 ? 116 - i * 10 : 74 - (i % 3),
      weightKg: i === 5 ? 66.5 : 63.2 + (i % 2) * 0.3,
      spo2: i === 5 ? 91 : 95 + (i % 2),
      temperature: 36.7,
    }),
  },
];

async function upsertUser(data, passwordHash, serviceId) {
  const { withService, ...fields } = data;
  const update = {
    ...fields,
    passwordHash,
    roles: [fields.role],
    active: true,
    ...(withService && serviceId ? { serviceId, serviceIds: [serviceId] } : {}),
  };
  return User.findOneAndUpdate(
    { email: fields.email },
    { $set: update },
    { new: true, upsert: true, runValidators: true, setDefaultsOnInsert: true },
  );
}

async function main() {
  const password = requirePassword(DEMO_PASSWORD);
  await mongoose.connect(getConfig().mongoUri);
  const passwordHash = await hashPassword(password);
  const service = await ensureDoctorService();

  const staff = {};
  for (const member of STAFF) {
    staff[member.role] = await upsertUser(member, passwordHash, service._id);
  }
  const doctor = staff.doctor;
  const nurse = staff.nurse;

  for (const entry of PATIENTS) {
    const patient = await upsertUser({ ...entry.user, role: 'patient' }, passwordHash);
    await Promise.all([
      MedicalRecord.deleteMany({ patientId: patient._id }),
      Consultation.deleteMany({ patientId: patient._id }),
      VitalSign.deleteMany({ patientId: patient._id }),
    ]);
    await MedicalRecord.create({ ...entry.record, patientId: patient._id, updatedBy: doctor._id });
    await Consultation.insertMany(entry.consultations.map((item) => ({
      patientId: patient._id,
      doctorId: doctor._id,
      date: daysAgo(item.days, 10),
      reason: item.reason,
      symptoms: item.symptoms,
      examination: item.examination,
      diagnosis: item.diagnosis,
      notes: item.notes,
      followUpAt: item.followUp ? daysAgo(item.followUp, 10) : null,
    })));
    // 12 mesures réparties sur ~6 mois, de la plus ancienne à la plus récente.
    await VitalSign.insertMany(Array.from({ length: 12 }, (_, i) => ({
      patientId: patient._id,
      recordedBy: i % 2 ? doctor._id : nurse._id,
      recordedAt: daysAgo(176 - i * 15, 8 + (i % 4)),
      ...entry.vitals(i),
    })));
  }

  console.log('Demo data ready. Accounts (password shared by all):');
  for (const user of [...STAFF, ...PATIENTS.map((entry) => ({ ...entry.user, role: 'patient' }))]) {
    console.log(`  ${user.role.padEnd(10)} ${user.email}`);
  }
}

main()
  .catch((error) => {
    console.error(error.message);
    process.exitCode = 1;
  })
  .finally(() => mongoose.disconnect());
