class Handover {
  const Handover({
    required this.id,
    required this.serviceId,
    required this.authorId,
    required this.title,
    required this.message,
    required this.createdAt,
    required this.author,
    this.important = false,
  });

  final String id;
  final String serviceId;
  final String authorId;
  final String title;
  final String message;
  final DateTime createdAt;
  final String author;
  final bool important;

  String get time {
    final local = createdAt.toLocal();
    final now = DateTime.now();
    final day =
        local.year == now.year &&
            local.month == now.month &&
            local.day == now.day
        ? 'Aujourd’hui'
        : '${local.day.toString().padLeft(2, '0')}/${local.month.toString().padLeft(2, '0')}/${local.year}';
    return '$day · ${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }

  factory Handover.fromJson(Map<String, dynamic> json) {
    final authorValue = json['authorId'] ?? json['author'];
    return Handover(
      id: _id(json['_id'] ?? json['id']),
      serviceId: _id(json['serviceId']),
      authorId: _id(authorValue),
      title: json['title'] as String? ?? '',
      message: (json['content'] ?? json['message']) as String? ?? '',
      createdAt: DateTime.parse(json['createdAt'] as String),
      author: authorValue is Map<String, dynamic>
          ? (authorValue['username'] ?? authorValue['name']) as String? ?? ''
          : json['authorName'] as String? ?? '',
      important: json['important'] as bool? ?? false,
    );
  }

  Map<String, Object?> toJson() => {
    'serviceId': serviceId,
    'title': title,
    'content': message,
    'important': important,
  };
}

String _id(Object? value) {
  if (value is Map<String, dynamic>) return _id(value['_id'] ?? value['id']);
  return value?.toString() ?? '';
}
