class NotificationAttachmentModel {
  final String storedName;
  final String? originalName;
  final String? url;

  const NotificationAttachmentModel({
    required this.storedName,
    this.originalName,
    this.url,
  });

  /// API may only return [url]; recover the stored filename for downloads / fallbacks.
  static String? parseStoredNameFromFileUrl(String? rawUrl) {
    if (rawUrl == null || rawUrl.trim().isEmpty) return null;
    final t = rawUrl.trim();
    final uri = Uri.tryParse(t.contains('://') ? t : 'https://x.com$t');
    if (uri == null) return null;
    final segs = uri.pathSegments;
    final i = segs.indexOf('files');
    if (i < 0 || i + 1 >= segs.length) return null;
    return Uri.decodeComponent(segs.sublist(i + 1).join('/'));
  }

  String get effectiveStoredName {
    final s = storedName.trim();
    if (s.isNotEmpty) return s;
    return parseStoredNameFromFileUrl(url)?.trim() ?? '';
  }

  String get displayName {
    if (originalName != null && originalName!.trim().isNotEmpty) {
      return originalName!.trim();
    }
    if (storedName.trim().isNotEmpty) {
      return storedName.trim();
    }
    final fromUrl = parseStoredNameFromFileUrl(url);
    if (fromUrl != null && fromUrl.trim().isNotEmpty) {
      return fromUrl.trim();
    }
    return 'Attachment';
  }

  factory NotificationAttachmentModel.fromJson(Map<String, dynamic> json) {
    return NotificationAttachmentModel(
      storedName:
          (json['storedName'] as String?) ??
          (json['fileName'] as String?) ??
          (json['stored_name'] as String?) ??
          (json['file_name'] as String?) ??
          '',
      originalName:
          (json['originalName'] as String?) ??
          (json['name'] as String?) ??
          (json['original_name'] as String?),
      url:
          (json['url'] as String?) ??
          (json['fileUrl'] as String?) ??
          (json['file_url'] as String?),
    );
  }
}

class NotificationModel {
  final String id;
  final String title;
  final String body;
  final DateTime? createdAt;
  final List<NotificationAttachmentModel> attachments;

  const NotificationModel({
    required this.id,
    required this.title,
    required this.body,
    this.createdAt,
    this.attachments = const [],
  });

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    final createdRaw =
        json['createdAt'] as String? ??
        json['publishedAt'] as String? ??
        json['date'] as String?;
    final attachmentList = json['attachments'] as List<dynamic>? ?? const [];

    return NotificationModel(
      id: (json['id'] ?? createdRaw ?? json['title'] ?? 'notification').toString(),
      title: (json['title'] as String?) ?? 'Notification',
      body: (json['body'] as String?) ?? (json['message'] as String?) ?? '',
      createdAt: createdRaw == null ? null : DateTime.tryParse(createdRaw),
      attachments: attachmentList
          .whereType<Map>()
          .map((e) => NotificationAttachmentModel.fromJson(
                Map<String, dynamic>.from(e),
              ))
          .toList(),
    );
  }
}
