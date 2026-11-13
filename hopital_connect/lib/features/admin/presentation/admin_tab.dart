import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets.dart';

class AdminTab extends StatelessWidget {
  const AdminTab({
    super.key,
    required this.usersCount,
    required this.shiftsCount,
    required this.servicesCount,
    required this.onManageUsers,
    required this.onAddShift,
    required this.onAddService,
  });

  final int usersCount;
  final int shiftsCount;
  final int servicesCount;
  final VoidCallback onManageUsers;
  final VoidCallback onAddShift;
  final VoidCallback onAddService;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const SectionIntro(
          title: 'Espace administrateur',
          subtitle: 'Aperçu des éléments à gérer dans le MVP',
        ),
        const SizedBox(height: 18),
        InfoCard(
          icon: Icons.groups_outlined,
          title: 'Comptes du personnel',
          value: '$usersCount compte(s)',
          color: AppColors.blue,
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: onManageUsers,
          icon: const Icon(Icons.manage_accounts_outlined),
          label: const Text('Gérer les comptes'),
        ),
        const SizedBox(height: 12),
        InfoCard(
          icon: Icons.local_hospital_outlined,
          title: 'Services',
          value: '$servicesCount service(s)',
          color: AppColors.mint,
        ),
        const SizedBox(height: 12),
        InfoCard(
          icon: Icons.calendar_month_outlined,
          title: 'Plannings',
          value: '$shiftsCount garde(s) planifiée(s)',
          color: Color(0xFF8797A0),
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: onAddShift,
          icon: const Icon(Icons.add),
          label: const Text('Ajouter une garde'),
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: onAddService,
          icon: const Icon(Icons.add_business_outlined),
          label: const Text('Ajouter un service'),
        ),
      ],
    );
  }
}
