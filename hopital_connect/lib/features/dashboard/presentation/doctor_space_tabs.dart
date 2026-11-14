import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets.dart';
import '../../appointments/domain/appointment.dart';
import '../../hospital/domain/hospital_resources.dart';
import '../../planning/domain/shift.dart';
import '../../services/domain/hospital_service.dart';
import '../../transmissions/domain/handover.dart';
import '../../transmissions/presentation/transmissions_tab.dart';
import '../../users/domain/staff_role.dart';
import '../../users/domain/staff_user.dart';

class DoctorHomeTab extends StatelessWidget {
  const DoctorHomeTab({
    super.key,
    required this.user,
    required this.services,
    required this.appointments,
    required this.interventions,
    required this.shifts,
    required this.handovers,
    required this.onOpenPlanning,
    required this.onHandoverTap,
  });

  final StaffUser user;
  final List<HospitalService> services;
  final List<Appointment> appointments;
  final List<HospitalIntervention> interventions;
  final List<Shift> shifts;
  final List<Handover> handovers;
  final VoidCallback onOpenPlanning;
  final ValueChanged<Handover> onHandoverTap;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final assignedServices = _servicesFor(user, services);
    final showOperations = assignedServices.any(
      (service) => service.hasOperations,
    );
    final operationServiceIds = assignedServices
        .where((service) => service.hasOperations)
        .map((service) => service.id)
        .toSet();
    final todayAppointments =
        appointments
            .where(
              (appointment) =>
                  _isActiveAppointment(appointment) &&
                  _sameDay(appointment.startAt, now),
            )
            .toList()
          ..sort((left, right) => left.startAt.compareTo(right.startAt));
    final todayOperations =
        (showOperations ? interventions : <HospitalIntervention>[])
            .where(
              (intervention) =>
                  operationServiceIds.contains(intervention.serviceId) &&
                  intervention.status != 'cancelled' &&
                  _sameDay(intervention.start, now),
            )
            .toList()
          ..sort((left, right) => left.start.compareTo(right.start));
    final upcomingAppointments =
        appointments
            .where(
              (appointment) =>
                  _isActiveAppointment(appointment) &&
                  appointment.startAt.isAfter(now),
            )
            .toList()
          ..sort((left, right) => left.startAt.compareTo(right.startAt));
    final upcomingShifts =
        shifts.where((shift) => shift.end.isAfter(now)).toList()
          ..sort((left, right) => left.start.compareTo(right.start));
    final tomorrow = DateTime(now.year, now.month, now.day + 1);
    final tomorrowOperations =
        (showOperations ? interventions : <HospitalIntervention>[])
            .where(
              (intervention) =>
                  operationServiceIds.contains(intervention.serviceId) &&
                  intervention.status != 'cancelled' &&
                  _sameDay(intervention.start, tomorrow),
            )
            .toList()
          ..sort((left, right) => left.start.compareTo(right.start));
    final dueSoon = upcomingAppointments
        .where(
          (appointment) =>
              appointment.startAt.isBefore(now.add(const Duration(hours: 1))),
        )
        .toList();
    final unreadCount = handovers.where((handover) => !handover.isRead).length;
    final todayMetrics = <Widget>[
      _DoctorMetricCard(
        icon: Icons.calendar_month_outlined,
        title: 'RDV aujourd’hui',
        value: '${todayAppointments.length}',
        color: AppColors.blue,
      ),
      if (showOperations)
        _DoctorMetricCard(
          icon: Icons.local_hospital_outlined,
          title: 'Opérations aujourd’hui',
          value: '${todayOperations.length}',
          color: AppColors.mint,
        ),
    ];

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
                'Bonjour ${user.displayName.isEmpty ? user.email.split('@').first : user.displayName} 👋',
                style: const TextStyle(color: Colors.white70, fontSize: 15),
              ),
              const SizedBox(height: 8),
              const Text(
                'Votre espace médecin, en un coup d’œil.',
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
        const SectionIntro(
          title: 'Aujourd’hui',
          subtitle: 'Votre activité et les prochains temps forts',
        ),
        const SizedBox(height: 12),
        if (todayMetrics.length == 1)
          todayMetrics.single
        else
          Row(
            children: [
              Expanded(child: todayMetrics[0]),
              const SizedBox(width: 10),
              Expanded(child: todayMetrics[1]),
            ],
          ),
        const SizedBox(height: 10),
        _DoctorMetricCard(
          icon: Icons.person_outline,
          title: 'Prochain patient',
          value: upcomingAppointments.isEmpty
              ? 'Aucun rendez-vous à venir'
              : '${upcomingAppointments.first.patientName} · ${_formatTime(upcomingAppointments.first.startAt)}',
          color: AppColors.blue,
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: onOpenPlanning,
          icon: const Icon(Icons.view_agenda_outlined),
          label: const Text('Ouvrir mon planning'),
        ),
        const SizedBox(height: 20),
        _DoctorMetricCard(
          icon: Icons.medical_services_outlined,
          title: 'Mon service',
          value: assignedServices.isEmpty
              ? 'Aucun service attribué'
              : assignedServices.map((service) => service.name).join(', '),
          color: AppColors.blue,
        ),
        const SizedBox(height: 10),
        _DoctorMetricCard(
          icon: Icons.access_time,
          title: 'Prochaine garde',
          value: upcomingShifts.isEmpty
              ? 'Aucune garde prévue'
              : '${upcomingShifts.first.day} · ${upcomingShifts.first.time}',
          color: AppColors.mint,
        ),
        const SizedBox(height: 22),
        const SectionIntro(
          title: 'Rappels',
          subtitle: 'Les éléments qui méritent votre attention',
        ),
        const SizedBox(height: 8),
        for (final appointment in dueSoon)
          _ReminderTile(
            icon: Icons.notifications_active_outlined,
            text:
                'RDV dans l’heure · ${appointment.patientName} à ${_formatTime(appointment.startAt)}',
          ),
        if (upcomingShifts.isNotEmpty)
          _ReminderTile(
            icon: Icons.access_time,
            text:
                'Garde à venir · ${upcomingShifts.first.day}, ${upcomingShifts.first.time}',
          ),
        if (unreadCount > 0)
          _ReminderTile(
            icon: Icons.forum_outlined,
            text:
                '$unreadCount transmission${unreadCount > 1 ? 's' : ''} non lue${unreadCount > 1 ? 's' : ''}',
          ),
        if (showOperations && tomorrowOperations.isNotEmpty)
          _ReminderTile(
            icon: Icons.local_hospital_outlined,
            text:
                'Opération prévue demain · ${tomorrowOperations.first.title} à ${_formatTime(tomorrowOperations.first.start)}',
          ),
        if (dueSoon.isEmpty &&
            upcomingShifts.isEmpty &&
            unreadCount == 0 &&
            (!showOperations || tomorrowOperations.isEmpty))
          const Text('Aucun rappel pour le moment.'),
        const SizedBox(height: 22),
        const SectionIntro(
          title: 'À retenir',
          subtitle: 'Dernières transmissions de votre service',
        ),
        const SizedBox(height: 10),
        if (handovers.isEmpty)
          const Text('Aucune transmission pour le moment.')
        else
          for (final handover in handovers.take(3)) ...[
            HandoverCard(
              handover: handover,
              onTap: () => onHandoverTap(handover),
            ),
            const SizedBox(height: 10),
          ],
        const SizedBox(height: 24),
      ],
    );
  }
}

class DoctorPlanningTab extends StatefulWidget {
  const DoctorPlanningTab({
    super.key,
    required this.appointments,
    required this.interventions,
    required this.shifts,
    required this.hasService,
    required this.hasOperations,
    required this.operationServiceIds,
  });

  final List<Appointment> appointments;
  final List<HospitalIntervention> interventions;
  final List<Shift> shifts;
  final bool hasService;
  final bool hasOperations;
  final Set<String> operationServiceIds;

  @override
  State<DoctorPlanningTab> createState() => _DoctorPlanningTabState();
}

class _DoctorPlanningTabState extends State<DoctorPlanningTab> {
  DateTime _date = DateTime.now();
  bool _weekView = false;
  bool _showAppointments = true;
  bool _showOperations = true;
  bool _showOnCall = true;

  DateTime get _rangeStart {
    final date = DateTime(_date.year, _date.month, _date.day);
    if (!_weekView) return date;
    return date.subtract(Duration(days: date.weekday - DateTime.monday));
  }

  DateTime get _rangeEnd => _weekView
      ? _rangeStart.add(const Duration(days: 7))
      : _rangeStart.add(const Duration(days: 1));

  bool _inRange(DateTime value) {
    final local = value.toLocal();
    return !local.isBefore(_rangeStart) && local.isBefore(_rangeEnd);
  }

  void _moveRange(int amount) {
    setState(() {
      _date = _date.add(Duration(days: amount * (_weekView ? 7 : 1)));
    });
  }

  Future<void> _chooseDate() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      helpText: 'Choisir une date',
    );
    if (selected != null) setState(() => _date = selected);
  }

  @override
  Widget build(BuildContext context) {
    final appointments = _showAppointments
        ? widget.appointments
              .where((appointment) => _inRange(appointment.startAt))
              .toList()
        : <Appointment>[];
    final shifts = _showOnCall
        ? widget.shifts.where((shift) => _inRange(shift.start)).toList()
        : <Shift>[];
    final interventions = widget.hasOperations && _showOperations
        ? widget.interventions
              .where(
                (intervention) =>
                    widget.operationServiceIds.contains(
                      intervention.serviceId,
                    ) &&
                    intervention.status != 'cancelled' &&
                    _inRange(intervention.start),
              )
              .toList()
        : <HospitalIntervention>[];
    final entries = <_DoctorAgendaEntry>[
      for (final appointment in appointments)
        _DoctorAgendaEntry(
          start: appointment.startAt,
          appointment: appointment,
        ),
      for (final shift in shifts)
        _DoctorAgendaEntry(start: shift.start, shift: shift),
      for (final intervention in interventions)
        _DoctorAgendaEntry(
          start: intervention.start,
          intervention: intervention,
        ),
    ]..sort((left, right) => left.start.compareTo(right.start));

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        SectionIntro(
          title: 'Mon planning',
          subtitle: widget.hasService
              ? 'Vos activités · lecture seule'
              : 'Aucun service attribué · lecture seule',
        ),
        const SizedBox(height: 14),
        SegmentedButton<bool>(
          segments: const [
            ButtonSegment(value: false, label: Text('Jour')),
            ButtonSegment(value: true, label: Text('Semaine')),
          ],
          selected: {_weekView},
          onSelectionChanged: (selection) =>
              setState(() => _weekView = selection.first),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            IconButton(
              tooltip: 'Période précédente',
              onPressed: () => _moveRange(-1),
              icon: const Icon(Icons.chevron_left),
            ),
            Expanded(
              child: TextButton.icon(
                onPressed: _chooseDate,
                icon: const Icon(Icons.calendar_today_outlined),
                label: Text(_periodLabel(_rangeStart, _rangeEnd, _weekView)),
              ),
            ),
            IconButton(
              tooltip: 'Période suivante',
              onPressed: () => _moveRange(1),
              icon: const Icon(Icons.chevron_right),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            FilterChip(
              label: const Text('RDV'),
              selected: _showAppointments,
              onSelected: (value) => setState(() => _showAppointments = value),
            ),
            if (widget.hasOperations)
              FilterChip(
                label: const Text('Opérations'),
                selected: _showOperations,
                onSelected: (value) => setState(() => _showOperations = value),
              ),
            FilterChip(
              label: const Text('Gardes'),
              selected: _showOnCall,
              onSelected: (value) => setState(() => _showOnCall = value),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 14,
          runSpacing: 8,
          children: [
            _LegendItem(
              color: AppColors.blue,
              label: '${appointments.length} RDV',
            ),
            if (widget.hasOperations)
              _LegendItem(
                color: AppColors.mint,
                label: '${interventions.length} opérations',
              ),
            _LegendItem(color: Colors.orange, label: '${shifts.length} gardes'),
          ],
        ),
        const SizedBox(height: 14),
        if (entries.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 28),
            child: Text(
              'Aucune activité autorisée sur cette période.',
              textAlign: TextAlign.center,
            ),
          ),
        for (final entry in entries) ...[
          if (entry.appointment case final appointment?)
            _DoctorAppointmentCard(appointment: appointment)
          else if (entry.shift case final shift?)
            _DoctorShiftCard(shift: shift)
          else if (entry.intervention case final intervention?)
            _DoctorInterventionCard(intervention: intervention),
          const SizedBox(height: 10),
        ],
        const SizedBox(height: 24),
      ],
    );
  }
}

class DoctorServiceTab extends StatelessWidget {
  const DoctorServiceTab({
    super.key,
    required this.user,
    required this.services,
    required this.colleagues,
  });

  final StaffUser user;
  final List<HospitalService> services;
  final List<ServiceColleague> colleagues;

  @override
  Widget build(BuildContext context) {
    final assignedServices = _servicesFor(user, services);
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const SectionIntro(
          title: 'Mon service',
          subtitle: 'Informations et équipe',
        ),
        const SizedBox(height: 14),
        if (assignedServices.isEmpty)
          const Text('Aucun service ne vous a été attribué.')
        else
          for (final service in assignedServices) ...[
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFFE5ECEF)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    service.name,
                    style: const TextStyle(
                      color: AppColors.navy,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (service.description.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(service.description),
                  ],
                  const SizedBox(height: 12),
                  _ServiceInfoRow(
                    icon: Icons.location_on_outlined,
                    label: service.location,
                  ),
                  if (service.building.isNotEmpty || service.floor.isNotEmpty)
                    _ServiceInfoRow(
                      icon: Icons.apartment_outlined,
                      label: [
                        service.building,
                        if (service.floor.isNotEmpty) 'Étage ${service.floor}',
                      ].where((value) => value.isNotEmpty).join(' · '),
                    ),
                  if (service.phone.isNotEmpty)
                    _ServiceInfoRow(
                      icon: Icons.phone_outlined,
                      label: service.phone,
                    ),
                  if (service.email.isNotEmpty)
                    _ServiceInfoRow(
                      icon: Icons.email_outlined,
                      label: service.email,
                    ),
                  if (service.openingHours.isNotEmpty)
                    _ServiceInfoRow(
                      icon: Icons.schedule_outlined,
                      label: service.openingHours,
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],
        if (assignedServices.isNotEmpty) ...[
          const SizedBox(height: 8),
          const SectionIntro(
            title: 'Collègues',
            subtitle: 'Personnel actif de vos services',
          ),
          const SizedBox(height: 10),
          if (colleagues.isEmpty)
            const Text('Aucun collègue actif renseigné.')
          else
            for (final colleague in colleagues)
              Card(
                child: ListTile(
                  leading: const CircleAvatar(
                    child: Icon(Icons.person_outline),
                  ),
                  title: Text(colleague.name),
                  subtitle: Text(
                    [
                      _roleLabel(colleague.role),
                      if (colleague.specialty.isNotEmpty) colleague.specialty,
                    ].join(' · '),
                  ),
                ),
              ),
        ],
      ],
    );
  }
}

class _DoctorMetricCard extends StatelessWidget {
  const _DoctorMetricCard({
    required this.icon,
    required this.title,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String title;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE5ECEF)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: Color(0xFF687B86))),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    color: AppColors.navy,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ReminderTile extends StatelessWidget {
  const _ReminderTile({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: EdgeInsets.zero,
    dense: true,
    leading: Icon(icon, color: AppColors.blue),
    title: Text(text),
  );
}

class _DoctorAgendaEntry {
  const _DoctorAgendaEntry({
    required this.start,
    this.appointment,
    this.shift,
    this.intervention,
  });

  final DateTime start;
  final Appointment? appointment;
  final Shift? shift;
  final HospitalIntervention? intervention;
}

class _DoctorAppointmentCard extends StatelessWidget {
  const _DoctorAppointmentCard({required this.appointment});

  final Appointment appointment;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: const Icon(
          Icons.calendar_month_outlined,
          color: AppColors.blue,
        ),
        title: Text(
          '${_formatTime(appointment.startAt)} · ${appointment.patientName}',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 5),
          child: Text(
            [
              if (appointment.reason.isNotEmpty) appointment.reason,
              appointment.status.label,
            ].join(' · '),
          ),
        ),
        trailing: const Icon(Icons.visibility_outlined),
        onTap: () => showDialog<void>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Rendez-vous · lecture seule'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Patient : ${appointment.patientName}'),
                Text('Date : ${_formatDateTime(appointment.startAt)}'),
                Text('Statut : ${appointment.status.label}'),
                if (appointment.reason.isNotEmpty)
                  Text('Motif : ${appointment.reason}'),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Fermer'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DoctorShiftCard extends StatelessWidget {
  const _DoctorShiftCard({required this.shift});

  final Shift shift;

  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(
      leading: const Icon(Icons.access_time, color: AppColors.mint),
      title: Text(
        '${_formatTime(shift.start)} – ${_formatTime(shift.end)} · Garde',
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
      subtitle: Text(
        shift.serviceName.isEmpty ? shift.role : shift.serviceName,
      ),
    ),
  );
}

class _DoctorInterventionCard extends StatelessWidget {
  const _DoctorInterventionCard({required this.intervention});

  final HospitalIntervention intervention;

  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(
      leading: const Icon(Icons.local_hospital_outlined, color: AppColors.mint),
      title: Text(
        '${_formatTime(intervention.start)} · ${intervention.title}',
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
      subtitle: Text(
        '${_formatTime(intervention.end)} · ${intervention.status}',
      ),
      trailing: const Icon(Icons.visibility_outlined),
      onTap: () => showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Opération · lecture seule'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Intervention : ${intervention.title}'),
              Text('Début : ${_formatDateTime(intervention.start)}'),
              Text('Fin : ${_formatDateTime(intervention.end)}'),
              Text('Statut : ${intervention.status}'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Fermer'),
            ),
          ],
        ),
      ),
    ),
  );
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      CircleAvatar(radius: 5, backgroundColor: color),
      const SizedBox(width: 6),
      Text(label),
    ],
  );
}

class _ServiceInfoRow extends StatelessWidget {
  const _ServiceInfoRow({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 8),
    child: Row(
      children: [
        Icon(icon, size: 18, color: AppColors.blue),
        const SizedBox(width: 8),
        Expanded(child: Text(label)),
      ],
    ),
  );
}

List<HospitalService> _servicesFor(
  StaffUser user,
  List<HospitalService> services,
) {
  final serviceIds = {
    ...user.serviceIds,
    if (user.serviceId != null) user.serviceId!,
  };
  return services.where((service) => serviceIds.contains(service.id)).toList();
}

String _periodLabel(DateTime start, DateTime end, bool weekView) {
  if (!weekView) return _formatDate(start);
  final lastDay = end.subtract(const Duration(days: 1));
  return '${_formatDate(start)} – ${_formatDate(lastDay)}';
}

String _formatDate(DateTime value) =>
    '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}';

String _formatDateTime(DateTime value) =>
    '${_formatDate(value)} · ${_formatTime(value)}';

String _formatTime(DateTime value) =>
    '${value.toLocal().hour.toString().padLeft(2, '0')}:${value.toLocal().minute.toString().padLeft(2, '0')}';

bool _sameDay(DateTime left, DateTime right) {
  final first = left.toLocal();
  final second = right.toLocal();
  return first.year == second.year &&
      first.month == second.month &&
      first.day == second.day;
}

bool _isActiveAppointment(Appointment appointment) =>
    appointment.status != AppointmentStatus.cancelled &&
    appointment.status != AppointmentStatus.rejected;

String _roleLabel(String role) => switch (StaffRole.fromApiValue(role)) {
  StaffRole.doctor => 'Médecin',
  StaffRole.nurse => 'Infirmier·ère',
  StaffRole.secretary => 'Secrétaire',
  _ => role,
};
