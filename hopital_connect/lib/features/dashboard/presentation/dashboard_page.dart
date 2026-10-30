import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../users/domain/staff_role.dart';
import '../../users/domain/staff_user.dart';
import '../../users/presentation/user_management_page.dart';
import '../../planning/presentation/planning_tab.dart';
import '../../services/presentation/services_tab.dart';
import '../../transmissions/presentation/transmissions_tab.dart';
import '../../admin/presentation/admin_tab.dart';
import '../../../shared/widgets.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key, required this.email, required this.role});

  final String email;
  final StaffRole role;

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  int _selectedIndex = 0;
  final List<StaffUser> _users = [
    const StaffUser(
      id: 'demo-doctor',
      displayName: 'Samira Benali',
      email: 'samira.benali@demo.local',
      role: StaffRole.doctor,
      serviceId: 'urgences',
    ),
    const StaffUser(
      id: 'demo-nurse',
      displayName: 'Yassine Amrani',
      email: 'yassine.amrani@demo.local',
      role: StaffRole.nurse,
      serviceId: 'urgences',
    ),
    const StaffUser(
      id: 'demo-staff',
      displayName: 'Nour Haddad',
      email: 'nour.haddad@demo.local',
      role: StaffRole.nurse,
      serviceId: 'urgences',
    ),
  ];
  final List<HospitalService> _services = [
    const HospitalService(
      name: 'Urgences',
      location: 'Bâtiment A, niveau 1',
      description: 'Service de démonstration pour l’équipe hospitalière.',
    ),
  ];
  final List<Shift> _shifts = [
    const Shift(
      day: 'Aujourd’hui',
      time: '15:00 – 23:00',
      role: 'Équipe de soirée',
      service: 'Urgences',
      color: AppColors.blue,
    ),
    const Shift(
      day: 'Demain',
      time: '07:00 – 15:00',
      role: 'Équipe du matin',
      service: 'Urgences',
      color: AppColors.mint,
    ),
    const Shift(
      day: 'Vendredi',
      time: 'Repos',
      role: 'Aucune garde prévue',
      service: '—',
      color: Color(0xFF8797A0),
    ),
  ];
  final List<Handover> _handovers = [
    const Handover(
      title: 'Relève de l’équipe du matin',
      message: 'Le chariot de soins est prêt pour la prochaine équipe.',
      time: 'Aujourd’hui · 14:45',
      author: 'Équipe du matin',
      important: true,
    ),
    const Handover(
      title: 'Matériel du service',
      message: 'Le contrôle du matériel partagé est terminé.',
      time: 'Aujourd’hui · 12:20',
      author: 'Équipe du service',
    ),
  ];

  static const _titles = [
    'Mon espace',
    'Mon planning',
    'Mon service',
    'Transmissions',
    'Administration',
  ];

  Future<void> _addHandover() async {
    final result = await showDialog<Handover>(
      context: context,
      builder: (context) => const NewHandoverDialog(),
    );
    if (result == null || !mounted) return;
    setState(() => _handovers.insert(0, result));
  }

  Future<void> _addShift() async {
    final result = await showDialog<Shift>(
      context: context,
      builder: (context) => NewShiftDialog(
        services: _services.map((service) => service.name).toList(),
      ),
    );
    if (result == null || !mounted) return;
    setState(() => _shifts.insert(0, result));
  }

  Future<void> _addService() async {
    final result = await showDialog<HospitalService>(
      context: context,
      builder: (context) => const NewServiceDialog(),
    );
    if (result == null || !mounted) return;
    setState(() => _services.add(result));
  }

  Future<void> _manageUsers() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (context) => UserManagementPage(
          users: _users,
          onUsersChanged: (users) {
            setState(() {
              _users
                ..clear()
                ..addAll(users);
            });
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = widget.role == StaffRole.administrator;
    final pages = <Widget>[
      HomeTab(email: widget.email, role: widget.role),
      ScheduleTab(shifts: _shifts),
      ServiceTab(services: _services),
      HandoversTab(handovers: _handovers),
      if (isAdmin)
        AdminTab(
          usersCount: _users.length,
          shiftsCount: _shifts.length,
          servicesCount: _services.length,
          onManageUsers: _manageUsers,
          onAddShift: _addShift,
          onAddService: _addService,
        ),
    ];
    final destinations = <NavigationDestination>[
      const NavigationDestination(
        icon: Icon(Icons.grid_view_outlined),
        selectedIcon: Icon(Icons.grid_view_rounded),
        label: 'Accueil',
      ),
      const NavigationDestination(
        icon: Icon(Icons.calendar_month_outlined),
        selectedIcon: Icon(Icons.calendar_month_rounded),
        label: 'Planning',
      ),
      const NavigationDestination(
        icon: Icon(Icons.local_hospital_outlined),
        selectedIcon: Icon(Icons.local_hospital_rounded),
        label: 'Service',
      ),
      const NavigationDestination(
        icon: Icon(Icons.forum_outlined),
        selectedIcon: Icon(Icons.forum_rounded),
        label: 'Transmissions',
      ),
      if (isAdmin)
        const NavigationDestination(
          icon: Icon(Icons.admin_panel_settings_outlined),
          selectedIcon: Icon(Icons.admin_panel_settings),
          label: 'Admin',
        ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(_titles[_selectedIndex]),
        foregroundColor: AppColors.navy,
        backgroundColor: AppColors.background,
        actions: [
          IconButton(
            tooltip: 'Se déconnecter',
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.logout_rounded),
          ),
        ],
      ),
      body: IndexedStack(index: _selectedIndex, children: pages),
      floatingActionButton: _selectedIndex == 3
          ? FloatingActionButton.extended(
              onPressed: _addHandover,
              backgroundColor: AppColors.blue,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add),
              label: const Text('Nouvelle note'),
            )
          : isAdmin && _selectedIndex == 1
          ? FloatingActionButton.extended(
              onPressed: _addShift,
              backgroundColor: AppColors.blue,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add),
              label: const Text('Ajouter une garde'),
            )
          : null,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) =>
            setState(() => _selectedIndex = index),
        destinations: destinations,
      ),
    );
  }
}

class HomeTab extends StatelessWidget {
  const HomeTab({super.key, required this.email, required this.role});

  final String email;
  final StaffRole role;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: AppColors.navy,
            borderRadius: BorderRadius.circular(22),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Bonjour ${email.split('@').first} 👋',
                style: TextStyle(color: Colors.white70, fontSize: 15),
              ),
              SizedBox(height: 8),
              Text(
                'Votre espace ${role.label.toLowerCase()},\nen un coup d’œil.',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 25,
                  height: 1.2,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        const InfoCard(
          icon: Icons.medical_services_outlined,
          title: 'Mon service',
          value: 'Urgences · Démonstration',
          color: AppColors.blue,
        ),
        const SizedBox(height: 12),
        const InfoCard(
          icon: Icons.calendar_month_outlined,
          title: 'Prochaine garde',
          value: 'Aujourd’hui · 15:00–23:00',
          color: AppColors.mint,
        ),
        const SizedBox(height: 24),
        const Text(
          'À retenir',
          style: TextStyle(
            color: AppColors.navy,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 12),
        const HandoverCard(
          handover: Handover(
            title: 'Relève de l’équipe du matin',
            message: 'Le chariot de soins est prêt pour la prochaine équipe.',
            time: 'Aujourd’hui · 14:45',
            author: 'Équipe du matin',
            important: true,
          ),
        ),
        const SizedBox(height: 18),
        const DemoNotice(),
      ],
    );
  }
}
