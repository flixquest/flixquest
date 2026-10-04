class InAppMessagePayload {
  final String? id;
  final DateTime? startsAt;
  final DateTime? endsAt;
  final String title;
  final String body;
  final String? imageUrl;
  final String? actionUrl;
  final String? buttonText;
  final String displayType; // 'modal', 'bottom_sheet', 'banner'

  InAppMessagePayload({
    this.id,
    this.startsAt,
    this.endsAt,
    required this.title,
    required this.body,
    this.imageUrl,
    this.actionUrl,
    this.buttonText,
    this.displayType = 'modal',
  });

  factory InAppMessagePayload.fromMap(Map<String, dynamic> data) {
    final identity = data['announcement_id'] ?? data['announcementId'] ?? data['id'];
    return InAppMessagePayload(
      id: identity == null || '$identity'.trim().isEmpty ? null : '$identity'.trim(),
      startsAt: DateTime.tryParse('${data['starts_at'] ?? data['startsAt']}'),
      endsAt: DateTime.tryParse('${data['ends_at'] ?? data['endsAt']}'),
      title: (data['title'] ?? data['notification_title'] ?? '').toString(),
      body: (data['body'] ?? data['notification_body'] ?? '').toString(),
      imageUrl: (data['image_url'] ?? data['imageUrl'])?.toString(),
      actionUrl: (data['action_url'] ?? data['actionUrl'])?.toString(),
      buttonText: (data['button_text'] ?? data['buttonText'])?.toString(),
      displayType: (data['display_type'] ?? data['displayType'] ?? 'modal').toString().toLowerCase(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'announcement_id': id,
      if (startsAt != null) 'starts_at': startsAt!.toUtc().toIso8601String(),
      if (endsAt != null) 'ends_at': endsAt!.toUtc().toIso8601String(),
      'title': title,
      'body': body,
      'image_url': imageUrl,
      'action_url': actionUrl,
      'button_text': buttonText,
      'display_type': displayType,
    };
  }
}
