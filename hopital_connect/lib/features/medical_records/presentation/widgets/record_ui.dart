// =============================================================================
// DOSSIER MÉDICAL — composants visuels partagés
// =============================================================================

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/medical_record.dart';

abstract final class RecordColors {
  static const ink = Color(0xFF0E2433);
  static const muted = Color(0xFF687B86);
  static const line = Color(0xFFE3EBEE);
  static const card = Colors.white;
  static const normal = Color(0xFF2E9E7E);
  static const warning = Color(0xFFE59A1A);
  static const critical = Color(0xFFD64545);
  static const consultation = AppColors.blue;
  static const prescription = Color(0xFF7B5CD6);
  static const appointment = Color(0xFF2E9E7E);

  static const headerGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF0E2A3F), Color(0xFF176B87), Color(0xFF2C8C8C)],
  );

  static Color status(VitalStatus? status) => switch (status) {
    VitalStatus.critical => critical,
    VitalStatus.warning => warning,
    VitalStatus.normal => normal,
    null => muted,
  };

  static Color severity(AllergySeverity? severity) => switch (severity) {
    AllergySeverity.severe => critical,
    AllergySeverity.moderate => warning,
    AllergySeverity.mild => normal,
    null => muted,
  };

  static Color bloodType(BloodType type) =>
      type == BloodType.unknown ? muted : const Color(0xFFC0392B);
}

// -----------------------------------------------------------------------------
// Formatage des dates (sans dépendance externe)
// -----------------------------------------------------------------------------

const _months = [
  'janv.',
  'févr.',
  'mars',
  'avr.',
  'mai',
  'juin',
  'juil.',
  'août',
  'sept.',
  'oct.',
  'nov.',
  'déc.',
];

String formatDay(DateTime date) =>
    '${date.day} ${_months[date.month - 1]} ${date.year}';

String formatShortDay(DateTime date) =>
    '${date.day} ${_months[date.month - 1]}';

String formatTime(DateTime date) =>
    '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';

String formatDayTime(DateTime date) =>
    '${formatDay(date)} · ${formatTime(date)}';

String relativeDay(DateTime date, {DateTime? now}) {
  final today = DateUtils.dateOnly(now ?? DateTime.now());
  final days = today.difference(DateUtils.dateOnly(date)).inDays;
  if (days == 0) return 'Aujourd’hui';
  if (days == 1) return 'Hier';
  if (days == -1) return 'Demain';
  if (days > 1 && days < 30) return 'Il y a $days j';
  if (days < -1 && days > -30) return 'Dans ${-days} j';
  if (days >= 30 && days < 365) return 'Il y a ${days ~/ 30} mois';
  if (days <= -30 && days > -365) return 'Dans ${-days ~/ 30} mois';
  return formatDay(date);
}

// -----------------------------------------------------------------------------
// Animations
// -----------------------------------------------------------------------------

/// Apparition en fondu + glissement, décalée selon [index] (effet cascade).
class FadeSlideIn extends StatelessWidget {
  const FadeSlideIn({
    super.key,
    required this.child,
    this.index = 0,
    this.offset = 24,
  });

  final Widget child;
  final int index;
  final double offset;

  @override
  Widget build(BuildContext context) {
    final delay = (index.clamp(0, 10)) * 60;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 420 + delay),
      curve: Interval(delay / (420 + delay), 1, curve: Curves.easeOutCubic),
      builder: (context, value, child) => Opacity(
        opacity: value,
        child: Transform.translate(
          offset: Offset(0, offset * (1 - value)),
          child: child,
        ),
      ),
      child: child,
    );
  }
}

/// Bloc gris animé affiché pendant le chargement.
class SkeletonBox extends StatefulWidget {
  const SkeletonBox({
    super.key,
    this.width = double.infinity,
    required this.height,
    this.radius = 14,
  });

  final double width;
  final double height;
  final double radius;

  @override
  State<SkeletonBox> createState() => _SkeletonBoxState();
}

class _SkeletonBoxState extends State<SkeletonBox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1300),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _controller,
    builder: (context, _) {
      final t = _controller.value * 3 - 1;
      return Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(widget.radius),
          gradient: LinearGradient(
            begin: Alignment(t - 1, 0),
            end: Alignment(t + 1, 0),
            colors: const [
              Color(0xFFE9EFF2),
              Color(0xFFF6F9FA),
              Color(0xFFE9EFF2),
            ],
          ),
        ),
      );
    },
  );
}

// -----------------------------------------------------------------------------
// Briques visuelles
// -----------------------------------------------------------------------------

class RecordCard extends StatelessWidget {
  const RecordCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.onTap,
    this.color = RecordColors.card,
    this.borderColor,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color color;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(22);
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: const [
          BoxShadow(
            color: Color(0x0F0E2433),
            blurRadius: 24,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: color,
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: BorderSide(color: borderColor ?? RecordColors.line),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

class SectionTitle extends StatelessWidget {
  const SectionTitle({
    super.key,
    required this.icon,
    required this.title,
    this.trailing,
    this.color = AppColors.blue,
  });

  final IconData icon;
  final String title;
  final Widget? trailing;
  final Color color;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, size: 18, color: color),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: Text(
          title,
          style: const TextStyle(
            color: RecordColors.ink,
            fontSize: 16,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.2,
          ),
        ),
      ),
      ?trailing,
    ],
  );
}

class StatusPill extends StatelessWidget {
  const StatusPill({
    super.key,
    required this.label,
    required this.color,
    this.icon,
    this.filled = false,
  });

  final String label;
  final Color color;
  final IconData? icon;
  final bool filled;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: filled ? color : color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(999),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 13, color: filled ? Colors.white : color),
          const SizedBox(width: 4),
        ],
        Text(
          label,
          style: TextStyle(
            color: filled ? Colors.white : color,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    ),
  );
}

class PatientAvatar extends StatelessWidget {
  const PatientAvatar({
    super.key,
    required this.initials,
    this.size = 52,
    this.heroTag,
    this.onDark = false,
  });

  final String initials;
  final double size;
  final Object? heroTag;
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    final avatar = Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: onDark
            ? null
            : const LinearGradient(
                colors: [Color(0xFF176B87), Color(0xFF36A98B)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
        color: onDark ? Colors.white.withValues(alpha: 0.18) : null,
        border: onDark
            ? Border.all(color: Colors.white.withValues(alpha: 0.5), width: 2)
            : null,
      ),
      child: Text(
        initials,
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w800,
          fontSize: size * 0.34,
          letterSpacing: 0.5,
        ),
      ),
    );
    if (heroTag == null) return avatar;
    return Hero(
      tag: heroTag!,
      child: Material(type: MaterialType.transparency, child: avatar),
    );
  }
}

class BloodTypeBadge extends StatelessWidget {
  const BloodTypeBadge({super.key, required this.type, this.large = false});

  final BloodType type;
  final bool large;

  @override
  Widget build(BuildContext context) {
    final color = RecordColors.bloodType(type);
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: large ? 12 : 8,
        vertical: large ? 6 : 4,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.water_drop, size: large ? 16 : 13, color: color),
          const SizedBox(width: 3),
          Text(
            type.label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w800,
              fontSize: large ? 15 : 12,
            ),
          ),
        ],
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.message = '',
    this.action,
  });

  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 24),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: AppColors.blue.withValues(alpha: 0.08),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 34, color: AppColors.blue),
        ),
        const SizedBox(height: 14),
        Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: RecordColors.ink,
            fontWeight: FontWeight.w700,
            fontSize: 16,
          ),
        ),
        if (message.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: RecordColors.muted, height: 1.4),
          ),
        ],
        if (action != null) ...[const SizedBox(height: 16), action!],
      ],
    ),
  );
}

class ErrorRetry extends StatelessWidget {
  const ErrorRetry({super.key, required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => EmptyState(
    icon: Icons.cloud_off_outlined,
    title: 'Chargement impossible',
    message: message,
    action: FilledButton.icon(
      onPressed: onRetry,
      icon: const Icon(Icons.refresh),
      label: const Text('Réessayer'),
    ),
  );
}

/// Ligne « libellé — valeur » compacte.
class InfoLine extends StatelessWidget {
  const InfoLine({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: RecordColors.muted),
        const SizedBox(width: 10),
        SizedBox(
          width: 110,
          child: Text(
            label,
            style: const TextStyle(color: RecordColors.muted, fontSize: 13),
          ),
        ),
        Expanded(
          child: Text(
            value.isEmpty ? '—' : value,
            style: const TextStyle(
              color: RecordColors.ink,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ),
      ],
    ),
  );
}

IconData vitalIcon(VitalKind kind) => switch (kind) {
  VitalKind.bloodPressure => Icons.speed_rounded,
  VitalKind.heartRate => Icons.favorite_rounded,
  VitalKind.temperature => Icons.thermostat_rounded,
  VitalKind.spo2 => Icons.air_rounded,
  VitalKind.glucose => Icons.bloodtype_outlined,
  VitalKind.weight => Icons.monitor_weight_outlined,
};

String vitalStatusLabel(VitalStatus? status) => switch (status) {
  VitalStatus.normal => 'Normal',
  VitalStatus.warning => 'À surveiller',
  VitalStatus.critical => 'Hors norme',
  null => '—',
};
