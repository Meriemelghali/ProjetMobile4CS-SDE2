import 'staff_role.dart';

/// Compte d'un membre du personnel dans le modèle de l'application.
///
/// Ce modèle ne sauvegarde pas encore les comptes : il décrit seulement leurs
/// données. La persistance et l'authentification seront ajoutées séparément.
class StaffUser {
  const StaffUser({
    required this.id,
    required this.displayName,
    required this.email,
    required this.role,
    this.serviceId,
    this.isActive = true,
  });

  final String id;
  final String displayName;
  final String email;
  final StaffRole role;
  final String? serviceId;
  final bool isActive;
}
