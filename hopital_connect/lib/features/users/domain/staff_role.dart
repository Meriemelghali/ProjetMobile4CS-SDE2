enum StaffRole {
  administrator('Administrateur', 'admin'),
  doctor('Médecin', 'doctor'),
  nurse('Personnel soignant', 'nurse'),
  patient('Patient', 'patient');

  const StaffRole(this.label, this.apiValue);
  final String label;
  final String apiValue;

  static StaffRole fromApiValue(String value) => switch (value) {
    'admin' || 'administrator' => StaffRole.administrator,
    'doctor' => StaffRole.doctor,
    'nurse' => StaffRole.nurse,
    'patient' => StaffRole.patient,
    _ => throw FormatException('Rôle utilisateur inconnu : $value'),
  };
}
