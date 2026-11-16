import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../users/domain/staff_user.dart';
import '../domain/appointment.dart';
import '../domain/appointment_notification.dart';
import 'appointments_tab.dart';

class PatientHomeTab extends StatelessWidget {
  const PatientHomeTab({
    super.key,
    required this.user,
    required this.appointments,
    required this.onBookAppointment,
    required this.onOpenAppointments,
    required this.onOpenFollowUps,
    required this.onOpenProfile,
    required this.onShowAppointmentDetails,
    required this.onEditAppointment,
    required this.onCancelAppointment,
    required this.onOpenDirections,
    required this.onContactHospital,
    required this.onEmergency,
    this.notifications = const [],
    this.onMarkNotificationsRead,
    this.onRespondToProposal,
    this.medicalRecordCard,
  });

  /// Carte « Mon dossier médical » (module dossier médical), optionnelle.
  final Widget? medicalRecordCard;

  final StaffUser user;
  final List<Appointment> appointments;
  final VoidCallback onBookAppointment;
  final VoidCallback onOpenAppointments;
  final ValueChanged<PatientRecordType> onOpenFollowUps;
  final VoidCallback onOpenProfile;
  final ValueChanged<Appointment> onShowAppointmentDetails;
  final ValueChanged<Appointment> onEditAppointment;
  final ValueChanged<Appointment> onCancelAppointment;
  final ValueChanged<Appointment?> onOpenDirections;
  final ValueChanged<Appointment?> onContactHospital;
  final VoidCallback onEmergency;
  final List<AppointmentNotification> notifications;
  final VoidCallback? onMarkNotificationsRead;
  final void Function(Appointment, bool accept)? onRespondToProposal;

  bool get _isArabic => user.language == 'ar';
  String _text(String french, String arabic) => _isArabic ? arabic : french;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final upcoming =
        appointments
            .where(
              (appointment) =>
                  _appointmentTime(appointment).isAfter(now) &&
                  appointment.status != AppointmentStatus.cancelled &&
                  appointment.status != AppointmentStatus.rejected,
            )
            .toList()
          ..sort(
            (left, right) =>
                _appointmentTime(left).compareTo(_appointmentTime(right)),
          );
    final nextAppointment = upcoming.firstOrNull;
    final pastAppointments =
        appointments
            .where((appointment) => appointment.startAt.isBefore(now))
            .toList()
          ..sort((left, right) => right.startAt.compareTo(left.startAt));
    final tomorrow = DateTime(now.year, now.month, now.day + 1);
    final tomorrowAppointment = user.reminderNotifications
        ? upcoming
              .where(
                (appointment) => DateUtils.isSameDay(
                  _appointmentTime(appointment),
                  tomorrow,
                ),
              )
              .firstOrNull
        : null;
    final pendingCount = user.appointmentNotifications
        ? appointments
              .where(
                (appointment) =>
                    appointment.status == AppointmentStatus.pending,
              )
              .length
        : 0;
    final unreadCount = notifications.where((item) => !item.isRead).length;
    final notificationsCount =
        pendingCount + (tomorrowAppointment == null ? 0 : 1) + unreadCount;

    return ListView(
      padding: const EdgeInsets.all(18),
      children: [
        Container(
          padding: const EdgeInsetsDirectional.fromSTEB(18, 16, 14, 16),
          decoration: BoxDecoration(
            color: AppColors.navy,
            borderRadius: BorderRadius.circular(22),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _text('Bonjour,', 'مرحباً،'),
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      user.firstName.isNotEmpty
                          ? user.firstName
                          : user.displayName.split(' ').firstOrNull ??
                                user.email,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 25,
                      ),
                    ),
                  ],
                ),
              ),
              Stack(
                clipBehavior: Clip.none,
                children: [
                  IconButton(
                    tooltip: _text('Notifications', 'الإشعارات'),
                    onPressed: onMarkNotificationsRead == null
                        ? () => _showNotifications(
                            context,
                            pendingCount: pendingCount,
                            tomorrowAppointment: tomorrowAppointment,
                          )
                        : () => _showNotifications(
                            context,
                            pendingCount: pendingCount,
                            tomorrowAppointment: tomorrowAppointment,
                            notifications: notifications,
                            onMarkRead: onMarkNotificationsRead,
                          ),
                    icon: const Icon(
                      Icons.notifications_none_rounded,
                      color: Colors.white,
                      size: 27,
                    ),
                  ),
                  if (notificationsCount > 0)
                    PositionedDirectional(
                      top: 5,
                      end: 5,
                      child: Container(
                        width: 10,
                        height: 10,
                        decoration: const BoxDecoration(
                          color: Color(0xFFFF7777),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 4),
              InkWell(
                onTap: onOpenProfile,
                customBorder: const CircleBorder(),
                child: CircleAvatar(
                  radius: 22,
                  backgroundColor: AppColors.mint,
                  child: Text(
                    (user.firstName.isNotEmpty
                                ? user.firstName
                                : user.displayName)
                            .characters
                            .firstOrNull
                            ?.toUpperCase() ??
                        '?',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        _HomeSectionTitle(
          title: _text('Prochain rendez-vous', 'الموعد القادم'),
          action: nextAppointment == null
              ? null
              : TextButton(
                  onPressed: onOpenAppointments,
                  child: Text(_text('Mes RDV', 'مواعيدي')),
                ),
        ),
        const SizedBox(height: 8),
        if (nextAppointment == null)
          _EmptyAppointmentCard(
            label: _text('Aucun rendez-vous prévu', 'لا يوجد موعد محدد'),
            actionLabel: _text('Prendre rendez-vous', 'حجز موعد'),
            onPressed: onBookAppointment,
          )
        else
          _NextAppointmentCard(
            appointment: nextAppointment,
            isArabic: _isArabic,
            onDetails: () => onShowAppointmentDetails(nextAppointment),
            onReschedule: () => onEditAppointment(nextAppointment),
            onCancel: () => onCancelAppointment(nextAppointment),
            onDirections: () => onOpenDirections(nextAppointment),
            onAcceptProposal: onRespondToProposal == null
                ? null
                : () => onRespondToProposal!(nextAppointment, true),
            onRejectProposal: onRespondToProposal == null
                ? null
                : () => onRespondToProposal!(nextAppointment, false),
          ),
        const SizedBox(height: 20),
        _HomeSectionTitle(title: _text('Actions rapides', 'إجراءات سريعة')),
        const SizedBox(height: 10),
        GridView.count(
          crossAxisCount: 3,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: 0.96,
          children: [
            _QuickAction(
              icon: Icons.calendar_month_outlined,
              label: _text('Prendre un RDV', 'حجز موعد'),
              onTap: onBookAppointment,
            ),
            _QuickAction(
              icon: Icons.receipt_long_outlined,
              label: _text('Mes ordonnances', 'وصفاتي الطبية'),
              onTap: () => onOpenFollowUps(PatientRecordType.prescriptions),
            ),
            _QuickAction(
              icon: Icons.monitor_heart_outlined,
              label: _text('Mes constantes', 'مؤشراتي الحيوية'),
              onTap: () => onOpenFollowUps(PatientRecordType.results),
            ),
            _QuickAction(
              icon: Icons.folder_shared_outlined,
              label: _text('Mon dossier', 'سجلي الطبي'),
              onTap: () => onOpenFollowUps(PatientRecordType.all),
            ),
            _QuickAction(
              icon: Icons.support_agent_outlined,
              label: _text('Contacter l’hôpital', 'الاتصال بالمستشفى'),
              onTap: () => onContactHospital(nextAppointment),
            ),
            _QuickAction(
              icon: Icons.emergency_outlined,
              label: _text('Urgences', 'الطوارئ'),
              onTap: onEmergency,
              color: const Color(0xFFB54747),
            ),
          ],
        ),
        const SizedBox(height: 20),
        _HomeSectionTitle(
          title: _text('Mon suivi médical', 'متابعتي الصحية'),
          action: TextButton(
            onPressed: () => onOpenFollowUps(PatientRecordType.all),
            child: Text(_text('Tout voir', 'عرض الكل')),
          ),
        ),
        const SizedBox(height: 8),
        // Le module dossier médical fournit une carte avec les vraies
        // données ; les cartes statiques ne restent qu'en secours.
        if (medicalRecordCard != null)
          medicalRecordCard!
        else ...[
          _OverviewCard(
            icon: Icons.medication_outlined,
            title: _text('Traitement en cours', 'العلاج الحالي'),
            value: _text(
              'Aucun traitement communiqué.',
              'لا توجد معلومات عن العلاج حالياً.',
            ),
          ),
          _OverviewCard(
            icon: Icons.science_outlined,
            title: _text('Dernier résultat', 'آخر نتيجة تحليل'),
            value: _text('Aucun résultat disponible.', 'لا توجد نتائج متاحة.'),
          ),
          _OverviewCard(
            icon: Icons.history,
            title: _text('Dernière consultation', 'آخر استشارة'),
            value: pastAppointments.isEmpty
                ? _text('Aucune consultation passée.', 'لا توجد استشارة سابقة.')
                : '${pastAppointments.first.doctorName} · ${_formatDate(pastAppointments.first.startAt, _isArabic)}',
          ),
        ],
        const SizedBox(height: 16),
        _HomeSectionTitle(
          title: _text('Rappels et alertes', 'التذكيرات والتنبيهات'),
        ),
        const SizedBox(height: 8),
        if (tomorrowAppointment != null)
          _ReminderCard(
            icon: Icons.alarm_outlined,
            text: _text(
              'Rappel : rendez-vous demain avec ${tomorrowAppointment.doctorName}.',
              'تذكير: لديك موعد غداً مع ${tomorrowAppointment.doctorName}.',
            ),
          )
        else
          _ReminderCard(
            icon: Icons.notifications_none,
            text: _text(
              'Aucun rappel pour le moment.',
              'لا توجد تذكيرات حالياً.',
            ),
          ),
      ],
    );
  }

  Future<void> _showNotifications(
    BuildContext context, {
    required int pendingCount,
    required Appointment? tomorrowAppointment,
    List<AppointmentNotification> notifications = const [],
    VoidCallback? onMarkRead,
  }) => showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (_) => Directionality(
      textDirection: _isArabic ? TextDirection.rtl : TextDirection.ltr,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * .75,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _text('Notifications', 'الإشعارات'),
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 20,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (pendingCount > 0)
                    ListTile(
                      leading: const Icon(Icons.pending_actions_outlined),
                      title: Text(
                        _text(
                          'Vous avez $pendingCount demande(s) de RDV en attente.',
                          'لديك $pendingCount طلب موعد قيد الانتظار.',
                        ),
                      ),
                    ),
                  if (tomorrowAppointment != null)
                    ListTile(
                      leading: const Icon(Icons.alarm_outlined),
                      title: Text(
                        _text(
                          'Vous avez un rendez-vous demain.',
                          'لديك موعد غداً.',
                        ),
                      ),
                    ),
                  for (final notification in notifications)
                    ListTile(
                      leading: Icon(
                        notification.isRead
                            ? Icons.notifications_none
                            : Icons.notifications_active_outlined,
                      ),
                      title: Text(notification.titleFor(_isArabic)),
                      subtitle: Text(notification.messageFor(_isArabic)),
                    ),
                  if (notifications.any((item) => !item.isRead) &&
                      onMarkRead != null)
                    Align(
                      alignment: AlignmentDirectional.centerEnd,
                      child: TextButton(
                        onPressed: onMarkRead,
                        child: Text(
                          _text('Tout marquer comme lu', 'تحديد الكل كمقروء'),
                        ),
                      ),
                    ),
                  if (pendingCount == 0 &&
                      tomorrowAppointment == null &&
                      notifications.isEmpty)
                    Text(_text('Aucune notification.', 'لا توجد إشعارات.')),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class _NextAppointmentCard extends StatelessWidget {
  const _NextAppointmentCard({
    required this.appointment,
    required this.isArabic,
    required this.onDetails,
    required this.onReschedule,
    required this.onCancel,
    required this.onDirections,
    this.onAcceptProposal,
    this.onRejectProposal,
  });

  final Appointment appointment;
  final bool isArabic;
  final VoidCallback onDetails;
  final VoidCallback onReschedule;
  final VoidCallback onCancel;
  final VoidCallback onDirections;
  final VoidCallback? onAcceptProposal;
  final VoidCallback? onRejectProposal;

  String _text(String french, String arabic) => isArabic ? arabic : french;

  @override
  Widget build(BuildContext context) {
    final startAt = _appointmentTime(appointment);
    final isProposed = appointment.status == AppointmentStatus.proposed;
    return Card(
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(11),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE7F3F4),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.calendar_month_outlined,
                    color: AppColors.blue,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _formatDate(startAt, isArabic),
                        style: const TextStyle(
                          color: AppColors.navy,
                          fontWeight: FontWeight.w700,
                          fontSize: 17,
                        ),
                      ),
                      Text(
                        '${_text('à', 'الساعة')} ${_twoDigits(startAt.hour)}:${_twoDigits(startAt.minute)}',
                        style: const TextStyle(color: Color(0xFF687B86)),
                      ),
                    ],
                  ),
                ),
                _AppointmentStatusChip(
                  status: appointment.status,
                  isArabic: isArabic,
                ),
              ],
            ),
            const Divider(height: 24),
            _DetailLine(
              icon: Icons.person_outline,
              label: _text('Médecin', 'الطبيب'),
              value: appointment.doctorName,
            ),
            if (appointment.serviceName.isNotEmpty)
              _DetailLine(
                icon: Icons.local_hospital_outlined,
                label: _text('Service', 'القسم'),
                value: appointment.serviceName,
              ),
            if (appointment.serviceLocation.isNotEmpty)
              _DetailLine(
                icon: Icons.place_outlined,
                label: _text('Lieu', 'المكان'),
                value: appointment.serviceLocation,
              ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 7,
              runSpacing: 6,
              children: [
                OutlinedButton(
                  onPressed: onDetails,
                  child: Text(_text('Détails', 'التفاصيل')),
                ),
                if (isProposed && onAcceptProposal != null)
                  FilledButton(
                    onPressed: onAcceptProposal,
                    child: Text(_text('Accepter', 'قبول')),
                  ),
                if (isProposed && onRejectProposal != null)
                  TextButton(
                    onPressed: onRejectProposal,
                    child: Text(_text('Refuser', 'رفض')),
                  ),
                if (!isProposed)
                  OutlinedButton(
                    onPressed: onReschedule,
                    child: Text(_text('Reporter', 'تأجيل')),
                  ),
                if (!isProposed)
                  TextButton(
                    onPressed: onCancel,
                    child: Text(_text('Annuler', 'إلغاء')),
                  ),
                OutlinedButton.icon(
                  onPressed: onDirections,
                  icon: const Icon(Icons.directions_outlined, size: 18),
                  label: Text(_text('Itinéraire', 'الاتجاهات')),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyAppointmentCard extends StatelessWidget {
  const _EmptyAppointmentCard({
    required this.label,
    required this.actionLabel,
    required this.onPressed,
  });

  final String label;
  final String actionLabel;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          const Icon(
            Icons.event_available_outlined,
            size: 36,
            color: AppColors.blue,
          ),
          const SizedBox(height: 8),
          Text(label),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: onPressed,
            icon: const Icon(Icons.add),
            label: Text(actionLabel),
          ),
        ],
      ),
    ),
  );
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color = AppColors.blue,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color color;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white,
    borderRadius: BorderRadius.circular(16),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 25),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.navy,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _HomeSectionTitle extends StatelessWidget {
  const _HomeSectionTitle({required this.title, this.action});
  final String title;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Text(
          title,
          style: const TextStyle(
            color: AppColors.navy,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      ?action,
    ],
  );
}

class _OverviewCard extends StatelessWidget {
  const _OverviewCard({
    required this.icon,
    required this.title,
    required this.value,
  });
  final IconData icon;
  final String title;
  final String value;

  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(
      leading: Icon(icon, color: AppColors.blue),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(value),
    ),
  );
}

class _ReminderCard extends StatelessWidget {
  const _ReminderCard({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Card(
    color: const Color(0xFFEAF5F2),
    child: ListTile(
      leading: Icon(icon, color: AppColors.mint),
      title: Text(text),
    ),
  );
}

class _DetailLine extends StatelessWidget {
  const _DetailLine({
    required this.icon,
    required this.label,
    required this.value,
  });
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Row(
      children: [
        Icon(icon, size: 18, color: AppColors.blue),
        const SizedBox(width: 8),
        Text('$label : ', style: const TextStyle(color: Color(0xFF687B86))),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              color: AppColors.navy,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    ),
  );
}

class _AppointmentStatusChip extends StatelessWidget {
  const _AppointmentStatusChip({required this.status, required this.isArabic});
  final AppointmentStatus status;
  final bool isArabic;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      AppointmentStatus.pending => const Color(0xFFC17A00),
      AppointmentStatus.accepted => AppColors.blue,
      AppointmentStatus.inProgress => AppColors.mint,
      AppointmentStatus.completed => const Color(0xFF2E7D32),
      AppointmentStatus.proposed => AppColors.blue,
      AppointmentStatus.rejected => const Color(0xFFB3261E),
      AppointmentStatus.cancelled => const Color(0xFF8797A0),
    };
    final label = isArabic
        ? switch (status) {
            AppointmentStatus.pending => 'قيد الانتظار',
            AppointmentStatus.accepted => 'مؤكد',
            AppointmentStatus.inProgress => 'جارٍ',
            AppointmentStatus.completed => 'مكتمل',
            AppointmentStatus.proposed => 'اقتُرح موعد جديد',
            AppointmentStatus.rejected => 'مرفوض',
            AppointmentStatus.cancelled => 'ملغى',
          }
        : status.label;
    return Chip(
      label: Text(label),
      backgroundColor: color.withValues(alpha: 0.12),
      labelStyle: TextStyle(color: color, fontWeight: FontWeight.w600),
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
    );
  }
}

DateTime _appointmentTime(Appointment appointment) =>
    appointment.status == AppointmentStatus.proposed
    ? appointment.proposedStartAt ?? appointment.startAt
    : appointment.startAt;

String _formatDate(DateTime value, bool arabic) {
  final days = arabic
      ? const [
          'الاثنين',
          'الثلاثاء',
          'الأربعاء',
          'الخميس',
          'الجمعة',
          'السبت',
          'الأحد',
        ]
      : const [
          'lundi',
          'mardi',
          'mercredi',
          'jeudi',
          'vendredi',
          'samedi',
          'dimanche',
        ];
  final months = arabic
      ? const [
          'يناير',
          'فبراير',
          'مارس',
          'أبريل',
          'مايو',
          'يونيو',
          'يوليو',
          'أغسطس',
          'سبتمبر',
          'أكتوبر',
          'نوفمبر',
          'ديسمبر',
        ]
      : const [
          'janvier',
          'février',
          'mars',
          'avril',
          'mai',
          'juin',
          'juillet',
          'août',
          'septembre',
          'octobre',
          'novembre',
          'décembre',
        ];
  return '${days[value.weekday - 1]} ${value.day} ${months[value.month - 1]} ${value.year}';
}

String _twoDigits(int value) => value.toString().padLeft(2, '0');
