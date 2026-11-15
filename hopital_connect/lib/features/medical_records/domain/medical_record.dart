// =============================================================================
// DOSSIER MÉDICAL — modèles métier
// Données de démonstration uniquement : ne saisissez aucune donnée réelle.
// =============================================================================

DateTime? _date(Object? value) =>
    value is String ? DateTime.tryParse(value)?.toLocal() : null;

double? _number(Object? value) => value is num ? value.toDouble() : null;

String _string(Object? value) => value is String ? value : '';

List<Map<String, dynamic>> _maps(Object? value) =>
    value is List ? value.whereType<Map<String, dynamic>>().toList() : const [];

List<String> _strings(Object? value) =>
    value is List ? value.whereType<String>().toList() : const [];

String _dateOnly(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-'
    '${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';

// -----------------------------------------------------------------------------
// Groupe sanguin et allergies
// -----------------------------------------------------------------------------

enum BloodType {
  aPositive('A+'),
  aNegative('A-'),
  bPositive('B+'),
  bNegative('B-'),
  abPositive('AB+'),
  abNegative('AB-'),
  oPositive('O+'),
  oNegative('O-'),
  unknown('unknown');

  const BloodType(this.apiValue);
  final String apiValue;

  String get label => this == BloodType.unknown ? '—' : apiValue;

  static BloodType fromApi(Object? value) => BloodType.values.firstWhere(
    (type) => type.apiValue == value,
    orElse: () => BloodType.unknown,
  );
}

enum AllergySeverity {
  mild('mild', 'Légère', 'خفيفة'),
  moderate('moderate', 'Modérée', 'متوسطة'),
  severe('severe', 'Sévère', 'شديدة');

  const AllergySeverity(this.apiValue, this.label, this.arabicLabel);
  final String apiValue;
  final String label;
  final String arabicLabel;

  static AllergySeverity? fromApi(Object? value) {
    for (final severity in AllergySeverity.values) {
      if (severity.apiValue == value) return severity;
    }
    return null;
  }
}

class Allergy {
  const Allergy({
    required this.name,
    this.severity,
    this.reaction = '',
    this.declaredByPatient = false,
  });

  factory Allergy.fromJson(Map<String, dynamic> json) => Allergy(
    name: _string(json['name']),
    severity: AllergySeverity.fromApi(json['severity']),
    reaction: _string(json['reaction']),
    declaredByPatient: json['source'] == 'patient',
  );

  final String name;

  /// `null` pour une allergie déclarée par le patient et non qualifiée.
  final AllergySeverity? severity;
  final String reaction;
  final bool declaredByPatient;

  bool get isSevere => severity == AllergySeverity.severe;

  Map<String, Object?> toJson() => {
    'name': name,
    'severity': (severity ?? AllergySeverity.moderate).apiValue,
    'reaction': reaction,
  };
}

class ChronicCondition {
  const ChronicCondition({required this.name, this.since, this.notes = ''});

  factory ChronicCondition.fromJson(Map<String, dynamic> json) =>
      ChronicCondition(
        name: _string(json['name']),
        since: _date(json['since']),
        notes: _string(json['notes']),
      );

  final String name;
  final DateTime? since;
  final String notes;

  Map<String, Object?> toJson() => {
    'name': name,
    'since': since == null ? null : _dateOnly(since!),
    'notes': notes,
  };
}

class Treatment {
  const Treatment({
    required this.name,
    this.dosage = '',
    this.frequency = '',
    this.startedAt,
  });

  factory Treatment.fromJson(Map<String, dynamic> json) => Treatment(
    name: _string(json['name']),
    dosage: _string(json['dosage']),
    frequency: _string(json['frequency']),
    startedAt: _date(json['startedAt']),
  );

  final String name;
  final String dosage;
  final String frequency;
  final DateTime? startedAt;

  String get posology =>
      [dosage, frequency].where((part) => part.trim().isNotEmpty).join(' · ');

  Map<String, Object?> toJson() => {
    'name': name,
    'dosage': dosage,
    'frequency': frequency,
    'startedAt': startedAt == null ? null : _dateOnly(startedAt!),
  };
}

class Vaccination {
  const Vaccination({required this.name, this.date});

  factory Vaccination.fromJson(Map<String, dynamic> json) =>
      Vaccination(name: _string(json['name']), date: _date(json['date']));

  final String name;
  final DateTime? date;

  Map<String, Object?> toJson() => {
    'name': name,
    'date': date == null ? null : _dateOnly(date!),
  };
}

class MedicalHistory {
  const MedicalHistory({
    this.medical = const [],
    this.surgical = const [],
    this.family = const [],
  });

  factory MedicalHistory.fromJson(Object? json) {
    final map = json is Map<String, dynamic> ? json : const <String, dynamic>{};
    return MedicalHistory(
      medical: _strings(map['medical']),
      surgical: _strings(map['surgical']),
      family: _strings(map['family']),
    );
  }

  final List<String> medical;
  final List<String> surgical;
  final List<String> family;

  bool get isEmpty => medical.isEmpty && surgical.isEmpty && family.isEmpty;

  Map<String, Object?> toJson() => {
    'medical': medical,
    'surgical': surgical,
    'family': family,
  };
}

class MedicalRecord {
  const MedicalRecord({
    this.exists = false,
    this.bloodType = BloodType.unknown,
    this.heightCm,
    this.allergies = const [],
    this.chronicConditions = const [],
    this.history = const MedicalHistory(),
    this.currentTreatments = const [],
    this.vaccinations = const [],
    this.updatedAt,
  });

  factory MedicalRecord.fromJson(Map<String, dynamic> json) => MedicalRecord(
    exists: json['exists'] == true,
    bloodType: BloodType.fromApi(json['bloodType']),
    heightCm: _number(json['heightCm']),
    allergies: _maps(json['allergies']).map(Allergy.fromJson).toList(),
    chronicConditions: _maps(json['chronicConditions'])
        .map(ChronicCondition.fromJson)
        .toList(),
    history: MedicalHistory.fromJson(json['history']),
    currentTreatments: _maps(json['currentTreatments'])
        .map(Treatment.fromJson)
        .toList(),
    vaccinations: _maps(json['vaccinations'])
        .map(Vaccination.fromJson)
        .toList(),
    updatedAt: _date(json['updatedAt']),
  );

  final bool exists;
  final BloodType bloodType;
  final double? heightCm;
  final List<Allergy> allergies;
  final List<ChronicCondition> chronicConditions;
  final MedicalHistory history;
  final List<Treatment> currentTreatments;
  final List<Vaccination> vaccinations;
  final DateTime? updatedAt;

  List<Allergy> get severeAllergies =>
      allergies.where((allergy) => allergy.isSevere).toList();

  /// Corps de `PUT /medical-records/:patientId`. Les allergies déclarées
  /// par le patient restent sur son profil et ne sont pas recopiées.
  Map<String, Object?> toUpdateJson() => {
    'bloodType': bloodType.apiValue,
    'heightCm': heightCm,
    'allergies': allergies
        .where((allergy) => !allergy.declaredByPatient)
        .map((allergy) => allergy.toJson())
        .toList(),
    'chronicConditions': chronicConditions
        .map((item) => item.toJson())
        .toList(),
    'history': history.toJson(),
    'currentTreatments': currentTreatments
        .map((item) => item.toJson())
        .toList(),
    'vaccinations': vaccinations.map((item) => item.toJson()).toList(),
  };
}

// -----------------------------------------------------------------------------
// Personnes
// -----------------------------------------------------------------------------

class PersonRef {
  const PersonRef({required this.id, required this.name, this.specialty = ''});

  factory PersonRef.fromJson(Object? json) {
    final map = json is Map<String, dynamic> ? json : const <String, dynamic>{};
    return PersonRef(
      id: _string(map['_id']),
      name: _string(map['name']),
      specialty: _string(map['specialty']),
    );
  }

  final String id;
  final String name;
  final String specialty;
}

String initialsOf(String name) {
  final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
  if (parts.isEmpty) return '?';
  final letters = parts.take(2).map((part) => part[0].toUpperCase()).join();
  return letters;
}

int? ageFrom(DateTime? birthDate, {DateTime? now}) {
  if (birthDate == null) return null;
  final today = now ?? DateTime.now();
  var age = today.year - birthDate.year;
  if (today.month < birthDate.month ||
      (today.month == birthDate.month && today.day < birthDate.day)) {
    age -= 1;
  }
  return age;
}

class PatientIdentity {
  const PatientIdentity({
    required this.id,
    required this.displayName,
    this.email = '',
    this.birthDate,
    this.phone = '',
    this.emergencyContact = '',
    this.insurance = '',
  });

  factory PatientIdentity.fromJson(Map<String, dynamic> json) =>
      PatientIdentity(
        id: _string(json['_id']),
        displayName: _string(json['displayName']),
        email: _string(json['email']),
        birthDate: _date(json['birthDate']),
        phone: _string(json['phone']),
        emergencyContact: _string(json['emergencyContact']),
        insurance: _string(json['insurance']),
      );

  final String id;
  final String displayName;
  final String email;
  final DateTime? birthDate;
  final String phone;
  final String emergencyContact;
  final String insurance;

  String get initials => initialsOf(displayName);
  int? get age => ageFrom(birthDate);
}

class PatientSummary {
  const PatientSummary({
    required this.identity,
    this.hasRecord = false,
    this.bloodType = BloodType.unknown,
    this.allergyCount = 0,
    this.hasSevereAllergy = false,
    this.chronicConditionCount = 0,
    this.consultationCount = 0,
    this.lastConsultationAt,
  });

  factory PatientSummary.fromJson(Map<String, dynamic> json) => PatientSummary(
    identity: PatientIdentity.fromJson(json),
    hasRecord: json['hasRecord'] == true,
    bloodType: BloodType.fromApi(json['bloodType']),
    allergyCount: (json['allergyCount'] as num?)?.toInt() ?? 0,
    hasSevereAllergy: json['hasSevereAllergy'] == true,
    chronicConditionCount:
        (json['chronicConditionCount'] as num?)?.toInt() ?? 0,
    consultationCount: (json['consultationCount'] as num?)?.toInt() ?? 0,
    lastConsultationAt: _date(json['lastConsultationAt']),
  );

  final PatientIdentity identity;
  final bool hasRecord;
  final BloodType bloodType;
  final int allergyCount;
  final bool hasSevereAllergy;
  final int chronicConditionCount;
  final int consultationCount;
  final DateTime? lastConsultationAt;
}

// -----------------------------------------------------------------------------
// Consultations, ordonnances et rendez-vous
// -----------------------------------------------------------------------------

class Consultation {
  const Consultation({
    required this.id,
    required this.date,
    required this.reason,
    required this.doctor,
    this.symptoms = '',
    this.examination = '',
    this.diagnosis = '',
    this.notes = '',
    this.followUpAt,
  });

  factory Consultation.fromJson(Map<String, dynamic> json) => Consultation(
    id: _string(json['_id']),
    date: _date(json['date']) ?? DateTime.now(),
    reason: _string(json['reason']),
    doctor: PersonRef.fromJson(json['doctor']),
    symptoms: _string(json['symptoms']),
    examination: _string(json['examination']),
    diagnosis: _string(json['diagnosis']),
    notes: _string(json['notes']),
    followUpAt: _date(json['followUpAt']),
  );

  final String id;
  final DateTime date;
  final String reason;
  final PersonRef doctor;
  final String symptoms;
  final String examination;
  final String diagnosis;
  final String notes;
  final DateTime? followUpAt;
}

class ConsultationDraft {
  const ConsultationDraft({
    required this.date,
    required this.reason,
    this.symptoms = '',
    this.examination = '',
    this.diagnosis = '',
    this.notes = '',
    this.followUpAt,
  });

  final DateTime date;
  final String reason;
  final String symptoms;
  final String examination;
  final String diagnosis;
  final String notes;
  final DateTime? followUpAt;

  Map<String, Object?> toJson() => {
    'date': date.toUtc().toIso8601String(),
    'reason': reason,
    'symptoms': symptoms,
    'examination': examination,
    'diagnosis': diagnosis,
    'notes': notes,
    'followUpAt': followUpAt?.toUtc().toIso8601String(),
  };
}

class PrescriptionLine {
  const PrescriptionLine({
    required this.name,
    this.dosage = '',
    this.quantity = 0,
  });

  final String name;
  final String dosage;
  final int quantity;
}

class PrescriptionSummary {
  const PrescriptionSummary({
    required this.id,
    required this.createdAt,
    required this.doctor,
    required this.status,
    this.medications = const [],
  });

  factory PrescriptionSummary.fromJson(Map<String, dynamic> json) =>
      PrescriptionSummary(
        id: _string(json['_id']),
        createdAt: _date(json['createdAt']) ?? DateTime.now(),
        doctor: PersonRef.fromJson(json['doctor']),
        status: _string(json['status']),
        medications: _maps(json['medications'])
            .map(
              (item) => PrescriptionLine(
                name: _string(item['name']),
                dosage: _string(item['dosage']),
                quantity: (item['quantity'] as num?)?.toInt() ?? 0,
              ),
            )
            .toList(),
      );

  final String id;
  final DateTime createdAt;
  final PersonRef doctor;
  final String status;
  final List<PrescriptionLine> medications;

  String get statusLabel => switch (status) {
    'pending' => 'En attente',
    'validated' => 'Validée',
    'dispensed' => 'Délivrée',
    'rejected' => 'Refusée',
    _ => status,
  };
}

class AppointmentSummary {
  const AppointmentSummary({
    required this.id,
    required this.startAt,
    required this.doctor,
    required this.status,
    this.reason = '',
  });

  factory AppointmentSummary.fromJson(Map<String, dynamic> json) =>
      AppointmentSummary(
        id: _string(json['_id']),
        startAt: _date(json['startAt']) ?? DateTime.now(),
        doctor: PersonRef.fromJson(json['doctor']),
        status: _string(json['status']),
        reason: _string(json['reason']),
      );

  final String id;
  final DateTime startAt;
  final PersonRef doctor;
  final String status;
  final String reason;

  String get statusLabel => switch (status) {
    'pending' => 'En attente',
    'accepted' => 'Confirmé',
    'in_progress' => 'En cours',
    'proposed' => 'Créneau proposé',
    'rejected' => 'Refusé',
    'cancelled' => 'Annulé',
    _ => status,
  };
}

// -----------------------------------------------------------------------------
// Constantes vitales
// -----------------------------------------------------------------------------

enum VitalStatus { normal, warning, critical }

enum VitalKind {
  bloodPressure('Tension', 'الضغط', 'mmHg', 90, 139, 80, 159),
  heartRate('Fréquence cardiaque', 'نبض القلب', 'bpm', 60, 100, 50, 120),
  temperature('Température', 'الحرارة', '°C', 36.1, 37.5, 35.5, 38.4),
  spo2('Saturation O₂', 'تشبع الأكسجين', '%', 95, 100, 92, 100),
  glucose('Glycémie', 'السكر في الدم', 'g/L', 0.7, 1.10, 0.6, 1.25),
  weight('Poids', 'الوزن', 'kg', 0, 999, 0, 999);

  const VitalKind(
    this.label,
    this.arabicLabel,
    this.unit,
    this.normalMin,
    this.normalMax,
    this.warningMin,
    this.warningMax,
  );

  final String label;
  final String arabicLabel;
  final String unit;
  final double normalMin;
  final double normalMax;
  final double warningMin;
  final double warningMax;

  /// Le poids n'a pas de plage « normale » universelle.
  bool get hasRange => this != VitalKind.weight;

  /// Classe une valeur (pour la tension : la systolique).
  VitalStatus classify(double value) {
    if (!hasRange) return VitalStatus.normal;
    if (value >= normalMin && value <= normalMax) return VitalStatus.normal;
    if (value >= warningMin && value <= warningMax) return VitalStatus.warning;
    return VitalStatus.critical;
  }

  String format(double value) => switch (this) {
    VitalKind.temperature || VitalKind.weight => value.toStringAsFixed(1),
    VitalKind.glucose => value.toStringAsFixed(2),
    _ => value.round().toString(),
  };
}

/// Plage de la diastolique, utilisée avec la systolique.
VitalStatus classifyDiastolic(double value) {
  if (value >= 60 && value <= 89) return VitalStatus.normal;
  if (value >= 50 && value <= 99) return VitalStatus.warning;
  return VitalStatus.critical;
}

VitalStatus worstStatus(Iterable<VitalStatus> statuses) {
  var worst = VitalStatus.normal;
  for (final status in statuses) {
    if (status.index > worst.index) worst = status;
  }
  return worst;
}

class VitalSign {
  const VitalSign({
    required this.id,
    required this.recordedAt,
    required this.recordedBy,
    this.systolic,
    this.diastolic,
    this.heartRate,
    this.temperature,
    this.spo2,
    this.weightKg,
    this.glucose,
    this.notes = '',
  });

  factory VitalSign.fromJson(Map<String, dynamic> json) => VitalSign(
    id: _string(json['_id']),
    recordedAt: _date(json['recordedAt']) ?? DateTime.now(),
    recordedBy: PersonRef.fromJson(json['recordedBy']),
    systolic: _number(json['systolic']),
    diastolic: _number(json['diastolic']),
    heartRate: _number(json['heartRate']),
    temperature: _number(json['temperature']),
    spo2: _number(json['spo2']),
    weightKg: _number(json['weightKg']),
    glucose: _number(json['glucose']),
    notes: _string(json['notes']),
  );

  final String id;
  final DateTime recordedAt;
  final PersonRef recordedBy;
  final double? systolic;
  final double? diastolic;
  final double? heartRate;
  final double? temperature;
  final double? spo2;
  final double? weightKg;
  final double? glucose;
  final String notes;

  /// Valeur principale pour un type de constante (systolique pour la tension).
  double? valueOf(VitalKind kind) => switch (kind) {
    VitalKind.bloodPressure => systolic,
    VitalKind.heartRate => heartRate,
    VitalKind.temperature => temperature,
    VitalKind.spo2 => spo2,
    VitalKind.glucose => glucose,
    VitalKind.weight => weightKg,
  };

  VitalStatus? statusOf(VitalKind kind) {
    final value = valueOf(kind);
    if (value == null) return null;
    if (kind == VitalKind.bloodPressure && diastolic != null) {
      return worstStatus([kind.classify(value), classifyDiastolic(diastolic!)]);
    }
    return kind.classify(value);
  }

  String? display(VitalKind kind) {
    final value = valueOf(kind);
    if (value == null) return null;
    if (kind == VitalKind.bloodPressure) {
      return '${value.round()}/${diastolic?.round() ?? '—'}';
    }
    return kind.format(value);
  }
}

class VitalDraft {
  const VitalDraft({
    required this.recordedAt,
    this.systolic,
    this.diastolic,
    this.heartRate,
    this.temperature,
    this.spo2,
    this.weightKg,
    this.glucose,
    this.notes = '',
  });

  final DateTime recordedAt;
  final double? systolic;
  final double? diastolic;
  final double? heartRate;
  final double? temperature;
  final double? spo2;
  final double? weightKg;
  final double? glucose;
  final String notes;

  bool get isEmpty => [
    systolic,
    diastolic,
    heartRate,
    temperature,
    spo2,
    weightKg,
    glucose,
  ].every((value) => value == null);

  Map<String, Object?> toJson() => {
    'recordedAt': recordedAt.toUtc().toIso8601String(),
    'systolic': ?systolic,
    'diastolic': ?diastolic,
    'heartRate': ?heartRate,
    'temperature': ?temperature,
    'spo2': ?spo2,
    'weightKg': ?weightKg,
    'glucose': ?glucose,
    if (notes.trim().isNotEmpty) 'notes': notes.trim(),
  };
}

// -----------------------------------------------------------------------------
// Dossier complet et chronologie
// -----------------------------------------------------------------------------

enum TimelineKind { consultation, prescription, appointment }

class TimelineEntry {
  const TimelineEntry({
    required this.kind,
    required this.date,
    required this.title,
    required this.subtitle,
    this.details = '',
    this.badge = '',
    this.consultation,
  });

  final TimelineKind kind;
  final DateTime date;
  final String title;
  final String subtitle;
  final String details;
  final String badge;
  final Consultation? consultation;
}

class PatientMedicalFile {
  const PatientMedicalFile({
    required this.patient,
    required this.record,
    this.consultations = const [],
    this.vitals = const [],
    this.prescriptions = const [],
    this.appointments = const [],
  });

  factory PatientMedicalFile.fromJson(Map<String, dynamic> json) {
    final vitals = _maps(json['vitals']).map(VitalSign.fromJson).toList()
      ..sort((a, b) => a.recordedAt.compareTo(b.recordedAt));
    final consultations =
        _maps(json['consultations']).map(Consultation.fromJson).toList()
          ..sort((a, b) => b.date.compareTo(a.date));
    return PatientMedicalFile(
      patient: PatientIdentity.fromJson(
        json['patient'] as Map<String, dynamic>? ?? const {},
      ),
      record: MedicalRecord.fromJson(
        json['record'] as Map<String, dynamic>? ?? const {},
      ),
      consultations: consultations,
      vitals: vitals,
      prescriptions: _maps(json['prescriptions'])
          .map(PrescriptionSummary.fromJson)
          .toList(),
      appointments: _maps(json['appointments'])
          .map(AppointmentSummary.fromJson)
          .toList(),
    );
  }

  final PatientIdentity patient;
  final MedicalRecord record;
  final List<Consultation> consultations;

  /// Triées de la plus ancienne à la plus récente.
  final List<VitalSign> vitals;
  final List<PrescriptionSummary> prescriptions;
  final List<AppointmentSummary> appointments;

  /// Dernière mesure disponible pour un type de constante.
  VitalSign? latestVital(VitalKind kind) {
    for (final vital in vitals.reversed) {
      if (vital.valueOf(kind) != null) return vital;
    }
    return null;
  }

  /// IMC calculé à partir de la taille du dossier et du dernier poids.
  double? get bmi {
    final height = record.heightCm;
    final weight = latestVital(VitalKind.weight)?.weightKg;
    if (height == null || weight == null || height <= 0) return null;
    final meters = height / 100;
    return weight / (meters * meters);
  }

  /// Alertes : constantes récentes hors norme.
  List<VitalKind> get alertingVitals => VitalKind.values
      .where(
        (kind) => latestVital(kind)?.statusOf(kind) == VitalStatus.critical,
      )
      .toList();

  Consultation? get nextFollowUp {
    final now = DateTime.now();
    final upcoming =
        consultations
            .where((item) => item.followUpAt?.isAfter(now) ?? false)
            .toList()
          ..sort((a, b) => a.followUpAt!.compareTo(b.followUpAt!));
    return upcoming.isEmpty ? null : upcoming.first;
  }

  List<TimelineEntry> get timeline {
    final entries = <TimelineEntry>[
      for (final item in consultations)
        TimelineEntry(
          kind: TimelineKind.consultation,
          date: item.date,
          title: item.reason,
          subtitle: item.doctor.name.isEmpty
              ? 'Consultation'
              : 'Dr ${item.doctor.name}',
          details: item.diagnosis,
          consultation: item,
        ),
      for (final item in prescriptions)
        TimelineEntry(
          kind: TimelineKind.prescription,
          date: item.createdAt,
          title: 'Ordonnance · ${item.medications.length} médicament(s)',
          subtitle: item.doctor.name.isEmpty ? '' : 'Dr ${item.doctor.name}',
          details: item.medications
              .map((line) => '${line.name} ${line.dosage}'.trim())
              .join(', '),
          badge: item.statusLabel,
        ),
      for (final item in appointments)
        TimelineEntry(
          kind: TimelineKind.appointment,
          date: item.startAt,
          title: item.reason.isEmpty ? 'Rendez-vous' : item.reason,
          subtitle: item.doctor.name.isEmpty ? '' : 'Dr ${item.doctor.name}',
          badge: item.statusLabel,
        ),
    ]..sort((a, b) => b.date.compareTo(a.date));
    return entries;
  }
}
