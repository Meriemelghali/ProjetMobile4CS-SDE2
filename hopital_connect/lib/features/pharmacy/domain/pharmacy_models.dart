class Pharmacy {
  const Pharmacy({required this.id, required this.name});

  final String id;
  final String name;

  factory Pharmacy.fromJson(Map<String, dynamic> json) => Pharmacy(
    id: _id(json['_id'] ?? json['id']),
    name: json['name'] as String? ?? '',
  );
}

class Medication {
  const Medication({
    required this.id,
    required this.name,
    required this.activeIngredient,
    required this.form,
    required this.dosage,
    required this.stockQuantity,
    required this.alertThreshold,
    required this.lot,
    required this.expirationDate,
    required this.price,
  });

  final String id;
  final String name;
  final String activeIngredient;
  final String form;
  final String dosage;
  final int stockQuantity;
  final int alertThreshold;
  final String lot;
  final DateTime expirationDate;
  final double price;

  bool get isOutOfStock => stockQuantity == 0;
  bool get isUnderThreshold => stockQuantity <= alertThreshold;
  bool get isNearExpiry =>
      expirationDate.isBefore(DateTime.now().add(const Duration(days: 30)));

  factory Medication.fromJson(Map<String, dynamic> json) => Medication(
    id: _id(json['_id'] ?? json['id']),
    name: json['name'] as String? ?? '',
    activeIngredient: json['activeIngredient'] as String? ?? '',
    form: json['form'] as String? ?? '',
    dosage: json['dosage'] as String? ?? '',
    stockQuantity: (json['stockQuantity'] as num?)?.toInt() ?? 0,
    alertThreshold: (json['alertThreshold'] as num?)?.toInt() ?? 0,
    lot: json['lot'] as String? ?? '',
    expirationDate:
        DateTime.tryParse(json['expirationDate'] as String? ?? '') ??
        DateTime(2100),
    price: (json['price'] as num?)?.toDouble() ?? 0,
  );
}

class PharmacyLine {
  const PharmacyLine({
    required this.medicationId,
    required this.name,
    required this.dosage,
    required this.quantity,
  });
  final String medicationId;
  final String name;
  final String dosage;
  final int quantity;

  factory PharmacyLine.fromJson(Map<String, dynamic> json) => PharmacyLine(
    medicationId: _id(json['medicationId']),
    name: json['name'] as String? ?? '',
    dosage: json['dosage'] as String? ?? '',
    quantity: (json['quantity'] as num?)?.toInt() ?? 0,
  );
}

enum PrescriptionStatus { pending, validated, dispensed, rejected }

class Prescription {
  const Prescription({
    required this.id,
    required this.appointmentId,
    required this.patientName,
    required this.doctorName,
    required this.patientAllergies,
    required this.medications,
    required this.status,
    required this.rejectionReason,
    required this.createdAt,
  });
  final String id;
  final String appointmentId;
  final String patientName;
  final String doctorName;
  final List<String> patientAllergies;
  final List<PharmacyLine> medications;
  final PrescriptionStatus status;
  final String rejectionReason;
  final DateTime? createdAt;

  factory Prescription.fromJson(Map<String, dynamic> json) {
    String person(Object? value) {
      if (value is Map<String, dynamic>) {
        final first = value['firstName'] as String? ?? '';
        final last = value['lastName'] as String? ?? '';
        return '$first $last'.trim().isEmpty
            ? value['username'] as String? ?? ''
            : '$first $last'.trim();
      }
      return '';
    }

    return Prescription(
      id: _id(json['_id'] ?? json['id']),
      appointmentId: _id(json['appointmentId']),
      patientName: person(json['patient']),
      doctorName: person(json['doctor']),
      patientAllergies:
          (json['patient'] is Map<String, dynamic> &&
              (json['patient'] as Map<String, dynamic>)['allergies'] is List)
          ? ((json['patient'] as Map<String, dynamic>)['allergies'] as List)
                .whereType<String>()
                .toList()
          : const [],
      medications: (json['medications'] as List? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(PharmacyLine.fromJson)
          .toList(),
      status: PrescriptionStatus.values.firstWhere(
        (item) => item.name == json['status'],
        orElse: () => PrescriptionStatus.pending,
      ),
      rejectionReason: json['rejectionReason'] as String? ?? '',
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? ''),
    );
  }
}

class Dispensation {
  const Dispensation({
    required this.id,
    required this.prescriptionId,
    required this.medications,
    required this.dispensedAt,
  });
  final String id;
  final String prescriptionId;
  final List<PharmacyLine> medications;
  final DateTime? dispensedAt;

  factory Dispensation.fromJson(Map<String, dynamic> json) => Dispensation(
    id: _id(json['_id'] ?? json['id']),
    prescriptionId: _id(json['prescriptionId']),
    medications: (json['medications'] as List? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(PharmacyLine.fromJson)
        .toList(),
    dispensedAt: DateTime.tryParse(json['dispensedAt'] as String? ?? ''),
  );
}

class MedicationRequest {
  const MedicationRequest({
    required this.id,
    required this.serviceId,
    required this.medications,
    required this.status,
    required this.rejectionReason,
  });
  final String id;
  final String serviceId;
  final List<PharmacyLine> medications;
  final String status;
  final String rejectionReason;

  factory MedicationRequest.fromJson(Map<String, dynamic> json) =>
      MedicationRequest(
        id: _id(json['_id'] ?? json['id']),
        serviceId: _id(json['serviceId']),
        medications: (json['medications'] as List? ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(PharmacyLine.fromJson)
            .toList(),
        status: json['status'] as String? ?? 'pending',
        rejectionReason: json['rejectionReason'] as String? ?? '',
      );
}

class SupplyOrder {
  const SupplyOrder({
    required this.id,
    required this.supplier,
    required this.medications,
    required this.status,
  });
  final String id;
  final String supplier;
  final List<PharmacyLine> medications;
  final String status;

  factory SupplyOrder.fromJson(Map<String, dynamic> json) => SupplyOrder(
    id: _id(json['_id'] ?? json['id']),
    supplier: json['supplier'] as String? ?? '',
    medications: (json['medications'] as List? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(PharmacyLine.fromJson)
        .toList(),
    status: json['status'] as String? ?? 'ordered',
  );
}

String _id(Object? value) {
  if (value is Map<String, dynamic>) return _id(value['_id'] ?? value['id']);
  return value?.toString() ?? '';
}
