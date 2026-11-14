// =============================================================================
// PAGE DE DÉMONSTRATION : ServicesDemoPage
// Point d'entrée STANDALONE du module Services.
// Fonctionne SANS backend, SANS login — utilise MockServiceRepository.
// La persistance est en mémoire RAM (dure le temps de la session).
// Pour activer : main.dart → runApp(const ServicesDemoApp())
// =============================================================================

import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../data/mock_service_repository.dart';
import '../domain/hospital_service.dart';
import 'service_form_dialog.dart';
import 'services_tab.dart';

// =============================================================================
// Application Flutter autonome
// =============================================================================

/// App minimale qui démarre directement sur le module Services.
/// Utilisée pour développer et tester sans le reste de l'application.
class ServicesDemoApp extends StatelessWidget {
  const ServicesDemoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Services – Démo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: AppColors.background,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.blue,
          primary: AppColors.blue,
          secondary: AppColors.mint,
          surface: Colors.white,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFFF8FAFB),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 17),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFFE1E9EC)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFFE1E9EC)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: AppColors.blue, width: 1.5),
          ),
        ),
      ),
      home: const ServicesDemoPage(),
    );
  }
}

// =============================================================================
// Page principale de démo
// =============================================================================

/// Page complète du module Services en mode démonstration.
/// Toutes les opérations CRUD sont persistées dans MockServiceRepository
/// (mémoire RAM — les données durent le temps de la session Flutter).
class ServicesDemoPage extends StatefulWidget {
  const ServicesDemoPage({super.key});

  @override
  State<ServicesDemoPage> createState() => _ServicesDemoPageState();
}

class _ServicesDemoPageState extends State<ServicesDemoPage> {
  // Référence au dépôt mock Singleton
  final _repo = MockServiceRepository.instance;

  // Liste des services affichés — rechargée depuis le mock après chaque action
  late List<HospitalService> _services;

  @override
  void initState() {
    super.initState();
    _services = _repo.getAll(); // Charge les 8 services de démo au démarrage
  }

  // --------------------------------------------------------------------------
  // Rafraîchissement
  // --------------------------------------------------------------------------

  /// Recharge la liste depuis le mock et déclenche un rebuild.
  void _refresh() {
    // setState provoque un rebuild du widget → ServiceTab reçoit la nouvelle liste
    setState(() => _services = _repo.getAll());
  }

  // --------------------------------------------------------------------------
  // Feedback utilisateur
  // --------------------------------------------------------------------------

  /// Affiche une SnackBar flottante avec un message de confirmation.
  void _snack(String message, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        backgroundColor: error ? const Color(0xFFD64045) : AppColors.navy,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // --------------------------------------------------------------------------
  // Actions CRUD — toutes persistées dans MockServiceRepository
  // --------------------------------------------------------------------------

  /// Ouvre le dialog de création et sauvegarde le nouveau service dans le mock.
  Future<void> _addService() async {
    // Affiche le dialog — retourne null si l'utilisateur annule
    final draft = await showDialog<HospitalService>(
      context: context,
      builder: (_) => const ServiceFormDialog(), // Mode création
    );
    if (draft == null) return; // Annulé

    // Crée dans le mock (génère un id 'mock-XXX' et l'ajoute à la liste)
    final created = _repo.create(draft);
    _refresh(); // Met à jour l'affichage
    _snack('Service "${created.name}" créé avec succès.');
  }

  /// Ouvre le dialog d'édition pré-rempli et sauvegarde les modifications.
  Future<void> _editService(HospitalService service) async {
    // Affiche le dialog en mode édition (champs pré-remplis)
    final edited = await showDialog<HospitalService>(
      context: context,
      builder: (_) => ServiceFormDialog(service: service),
    );
    if (edited == null) return; // Annulé

    // Met à jour dans le mock (cherche par id et remplace)
    _repo.update(edited);
    _refresh();
    _snack('Service "${edited.name}" modifié.');
  }

  /// Demande confirmation puis bascule le statut actif/inactif.
  Future<void> _toggleActive(HospitalService service) async {
    final action = service.isActive ? 'désactiver' : 'réactiver';

    // Dialog de confirmation avant l'action
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(
              Icons.warning_amber_rounded,
              color: service.isActive
                  ? const Color(0xFFD64045) // Rouge pour désactiver
                  : AppColors.mint,         // Vert pour réactiver
            ),
            const SizedBox(width: 8),
            const Expanded(
              child: Text('Confirmer',
                  style: TextStyle(fontSize: 17)),
            ),
          ],
        ),
        content: Text(
            'Voulez-vous $action le service "${service.name}" ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: service.isActive
                  ? const Color(0xFFD64045)
                  : AppColors.mint,
            ),
            child: Text(service.isActive ? 'Désactiver' : 'Réactiver'),
          ),
        ],
      ),
    );

    if (confirmed != true) return; // L'utilisateur a annulé

    // Inverse le statut dans le mock et rafraîchit
    final updated = _repo.toggleActive(service);
    _refresh();
    _snack(updated.isActive
        ? 'Service "${updated.name}" réactivé.'
        : 'Service "${updated.name}" désactivé.');
  }

  // --------------------------------------------------------------------------
  // Build
  // --------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        // Titre avec icône
        title: const Row(
          children: [
            Icon(Icons.medical_services_outlined,
                color: AppColors.navy, size: 22),
            SizedBox(width: 8),
            Text('Services hospitaliers',
                style: TextStyle(
                    color: AppColors.navy,
                    fontWeight: FontWeight.w700,
                    fontSize: 18)),
          ],
        ),
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.navy,
        elevation: 0,
        actions: [
          // Badge DÉMO
          Container(
            margin: const EdgeInsets.only(right: 4),
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.mint.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                  color: AppColors.mint.withValues(alpha: 0.4)),
            ),
            child: const Text('DÉMO',
                style: TextStyle(
                    color: AppColors.mint,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5)),
          ),
          // Bouton réinitialiser les données
          IconButton(
            tooltip: 'Réinitialiser les données de démo',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () {
              _repo.reset(); // Remet les 8 services initiaux
              _refresh();
              _snack('Données réinitialisées.');
            },
          ),
        ],
      ),

      // Corps : onglet liste des services
      body: ServiceTab(
        services: _services,       // Liste fraîche depuis le mock
        canEdit: true,             // Mode admin = tout est permis en démo
        onAdd: _addService,        // Création
        onEdit: _editService,      // Édition
        onToggleActive: _toggleActive, // Toggle actif/inactif
      ),
    );
  }
}
