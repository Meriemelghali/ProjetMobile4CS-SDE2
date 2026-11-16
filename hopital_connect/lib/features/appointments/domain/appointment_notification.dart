class AppointmentNotification {
  const AppointmentNotification({
    required this.id,
    required this.appointmentId,
    this.prescriptionId,
    required this.title,
    required this.message,
    required this.createdAt,
    this.readAt,
  });

  final String id;
  final String appointmentId;
  final String? prescriptionId;
  final String title;
  final String message;
  final DateTime createdAt;
  final DateTime? readAt;

  bool get isRead => readAt != null;

  String titleFor(bool isArabic) {
    if (!isArabic) return title;
    return switch (title) {
      'Demande de rendez-vous envoyée' => 'تم إرسال طلب الموعد',
      'Rendez-vous confirmé' => 'تم تأكيد الموعد',
      'Demande de rendez-vous refusée' => 'تم رفض طلب الموعد',
      'Nouveau créneau proposé' => 'تم اقتراح موعد جديد',
      'Mise à jour de votre rendez-vous' => 'تم تحديث موعدك',
      'Proposition refusée' => 'تم رفض الاقتراح',
      'Nouvelle ordonnance' => 'وصفة طبية جديدة',
      'Ordonnance validée' => 'تمت المصادقة على الوصفة',
      'Ordonnance refusée' => 'تم رفض الوصفة',
      'Ordonnance délivrée' => 'تم صرف الوصفة',
      _ => title,
    };
  }

  String messageFor(bool isArabic) {
    if (!isArabic) return message;
    if (message.startsWith('Votre demande a été refusée. Motif : ')) {
      return 'تم رفض طلبك. السبب: ${message.substring('Votre demande a été refusée. Motif : '.length)}';
    }
    return switch (message) {
      'Votre demande est enregistrée et en attente de confirmation.' =>
        'تم تسجيل طلبك وهو بانتظار التأكيد.',
      'Votre demande de rendez-vous a été confirmée.' => 'تم تأكيد طلب موعدك.',
      'Votre rendez-vous a été annulé.' => 'تم إلغاء موعدك.',
      'La date ou le médecin de votre rendez-vous a été modifié.' =>
        'تم تعديل تاريخ موعدك أو طبيبك.',
      'Vous avez accepté le nouveau créneau. Votre rendez-vous est confirmé.' =>
        'وافقت على الموعد الجديد وتم تأكيد موعدك.',
      'Vous avez refusé le créneau proposé. La demande est annulée.' =>
        'رفضت الموعد المقترح وتم إلغاء الطلب.',
      'Votre médecin a envoyé une ordonnance à la pharmacie.' =>
        'أرسل طبيبك وصفة طبية إلى الصيدلية.',
      'La pharmacie a validé votre ordonnance.' =>
        'صادقت الصيدلية على وصفتك الطبية.',
      'La pharmacie a refusé votre ordonnance.' =>
        'رفضت الصيدلية وصفتك الطبية.',
      'Votre ordonnance a été délivrée par la pharmacie.' =>
        'تم صرف وصفتك الطبية من الصيدلية.',
      _ => 'تم تحديث حالة موعدك.',
    };
  }

  factory AppointmentNotification.fromJson(Map<String, dynamic> json) =>
      AppointmentNotification(
        id: json['_id'] as String,
        appointmentId: json['appointmentId'] as String,
        prescriptionId: json['prescriptionId'] as String?,
        title: json['title'] as String,
        message: json['message'] as String,
        createdAt: DateTime.parse(json['createdAt'] as String).toLocal(),
        readAt: json['readAt'] is String
            ? DateTime.parse(json['readAt'] as String).toLocal()
            : null,
      );
}
