import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

class Shift {
  const Shift({
    required this.id,
    required this.userId,
    required this.serviceId,
    required this.start,
    required this.end,
    required this.role,
    this.userName = '',
    this.serviceName = '',
  });

  final String id;
  final String userId;
  final String serviceId;
  final DateTime start;
  final DateTime end;
  final String role;
  final String userName;
  final String serviceName;

  String get day {
    final local = start.toLocal();
    final now = DateTime.now();
    if (local.year == now.year &&
        local.month == now.month &&
        local.day == now.day) {
      return 'Aujourd’hui';
    }
    final tomorrow = now.add(const Duration(days: 1));
    if (local.year == tomorrow.year &&
        local.month == tomorrow.month &&
        local.day == tomorrow.day) {
      return 'Demain';
    }
    const weekdays = [
      'Lundi',
      'Mardi',
      'Mercredi',
      'Jeudi',
      'Vendredi',
      'Samedi',
      'Dimanche',
    ];
    return '${weekdays[local.weekday - 1]} ${local.day.toString().padLeft(2, '0')}/${local.month.toString().padLeft(2, '0')}';
  }

  String get time =>
      '${_formatTime(start.toLocal())} – ${_formatTime(end.toLocal())}';

  Color get color =>
      role.toLowerCase().contains('doctor') ||
          role.toLowerCase().contains('médecin')
      ? AppColors.blue
      : AppColors.mint;

  factory Shift.fromJson(Map<String, dynamic> json) {
    final userValue = json['userId'] ?? json['user'];
    final serviceValue = json['serviceId'] ?? json['service'];
    return Shift(
      id: _id(json['_id'] ?? json['id']),
      userId: _id(userValue),
      serviceId: _id(serviceValue),
      start: DateTime.parse(json['start'] as String),
      end: DateTime.parse(json['end'] as String),
      role: json['role'] as String? ?? '',
      userName: _populatedName(userValue, json['userName']),
      serviceName: _populatedName(serviceValue, json['serviceName']),
    );
  }

  Map<String, Object?> toJson() => {
    'userId': userId,
    'serviceId': serviceId,
    'start': start.toUtc().toIso8601String(),
    'end': end.toUtc().toIso8601String(),
    'role': role,
  };
}

String _formatTime(DateTime dateTime) =>
    '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';

String _id(Object? value) {
  if (value is Map<String, dynamic>) return _id(value['_id'] ?? value['id']);
  return value?.toString() ?? '';
}

String _populatedName(Object? value, Object? fallback) {
  if (value is Map<String, dynamic>) {
    return (value['username'] ?? value['name'] ?? value['displayName'])
            as String? ??
        '';
  }
  return fallback as String? ?? '';
}
