import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:open_filex/open_filex.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../apis/api_manager.dart';
import '../../constants/api_constants.dart';
import '../../constants/colors.dart';
import '../../constants/styles.dart';
import '../../models/notification_model.dart';
import '../../providers/auth/user_data_provider.dart';
import '../../providers/notifications_provider.dart';
import '../../widgets/app_header.dart';
import '../../widgets/app_logo_loader.dart';
import 'notification_attachment_viewer_screen.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  bool _hasLoadedOnce = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _load();
    });
  }

  Future<void> _load() async {
    final token = Provider.of<UserDataProvider>(context, listen: false).token;
    final provider = Provider.of<NotificationsProvider>(context, listen: false);
    try {
      await provider.load(token: token);
      await provider.markLatestAsSeen();
    } finally {
      if (mounted && !_hasLoadedOnce) {
        setState(() => _hasLoadedOnce = true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final token = context.watch<UserDataProvider>().token;
    return Consumer<NotificationsProvider>(
      builder: (context, provider, _) {
        return Scaffold(
          backgroundColor: AppColors.background,
          body: Column(
            children: [
              AppHeader(
                title: 'Notifications',
                leadingIcon: Icons.arrow_back_rounded,
                showSupport: false,
                showNotifications: false,
                showLogout: false,
                extraActions: [
                  IconButton(
                    onPressed: provider.isLoading ? null : _load,
                    icon: const Icon(
                      Icons.refresh_rounded,
                      color: AppColors.fmbAccent,
                    ),
                  ),
                ],
              ),
              Expanded(
                child: provider.isLoading
                    ? (_hasLoadedOnce
                          ? RefreshIndicator(
                              onRefresh: _load,
                              child: ListView(
                                padding: const EdgeInsets.all(16),
                                children: [
                                  if (provider.errorMessage != null) ...[
                                    _ErrorCard(message: provider.errorMessage!),
                                    const SizedBox(height: 12),
                                  ],
                                  if (provider.items.isEmpty)
                                    const _EmptyCard()
                                  else
                                    ...provider.items.map(
                                      (n) => _NotificationCard(
                                        notification: n,
                                        authToken: token,
                                      ),
                                    ),
                                ],
                              ),
                            )
                          : const Center(child: AppLogoLoader()))
                    : RefreshIndicator(
                        onRefresh: _load,
                        child: ListView(
                          padding: const EdgeInsets.all(16),
                          children: [
                            if (provider.errorMessage != null) ...[
                              _ErrorCard(message: provider.errorMessage!),
                              const SizedBox(height: 12),
                            ],
                            if (provider.items.isEmpty)
                              const _EmptyCard()
                            else
                              ...provider.items.map(
                                (n) => _NotificationCard(
                                  notification: n,
                                  authToken: token,
                                ),
                              ),
                          ],
                        ),
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _NotificationCard extends StatelessWidget {
  const _NotificationCard({
    required this.notification,
    required this.authToken,
  });

  final NotificationModel notification;
  final String authToken;

  List<String> _resolveAttachmentUrls(NotificationAttachmentModel attachment) {
    final candidates = <String>[];
    final effective = attachment.effectiveStoredName;
    if (effective.isNotEmpty) {
      candidates.add(ApiManager.notificationFileUrl(effective));
    }

    final raw = attachment.url?.trim() ?? '';
    if (raw.isNotEmpty) {
      final parsed = Uri.tryParse(raw);
      if (parsed != null) {
        if (parsed.hasScheme) {
          candidates.add(raw);
        } else {
          final apiBase = Uri.parse(ApiConstants.baseUrl);
          final apiOrigin = '${apiBase.scheme}://${apiBase.authority}';
          final apiBasePath = apiBase.path.replaceFirst(RegExp(r'/$'), '');
          final rawPath = raw.startsWith('/') ? raw : '/$raw';

          candidates.add('$apiOrigin$rawPath');

          final includesBasePath =
              apiBasePath.isNotEmpty &&
              (rawPath == apiBasePath || rawPath.startsWith('$apiBasePath/'));
          if (apiBasePath.isNotEmpty && !includesBasePath) {
            candidates.add('$apiOrigin$apiBasePath$rawPath');
          }
        }
      }
    }

    return candidates.toSet().toList();
  }

  String _safeFileName(NotificationAttachmentModel attachment, Uri fileUri) {
    final preferred = attachment.displayName.trim();
    final fromUri = fileUri.pathSegments.isEmpty
        ? ''
        : fileUri.pathSegments.last.trim();
    final raw = preferred.isNotEmpty ? preferred : fromUri;
    final cleaned = raw.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    if (cleaned.isNotEmpty) return cleaned;
    return 'attachment_${DateTime.now().millisecondsSinceEpoch}';
  }

  bool _isImageAttachment(NotificationAttachmentModel attachment) {
    final source = attachment.originalName?.trim().isNotEmpty == true
        ? attachment.originalName!.trim()
        : attachment.effectiveStoredName;
    if (source.isEmpty) return false;
    final lower = source.toLowerCase();
    return lower.endsWith('.png') ||
        lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.gif') ||
        lower.endsWith('.webp') ||
        lower.endsWith('.bmp');
  }

  Future<void> _openInAppFallback(
    BuildContext context, {
    required NotificationAttachmentModel attachment,
    required String url,
    required Uri uri,
  }) async {
    if (authToken.trim().isNotEmpty) {
      if (!context.mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => NotificationAttachmentViewerScreen(
            title: attachment.displayName,
            fileUrl: url,
            bearerToken: authToken,
            isImage: _isImageAttachment(attachment),
          ),
        ),
      );
      return;
    }

    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to open this attachment.')),
      );
    }
  }

  /// Tries each candidate URL until one returns 2xx. Returns response + URI used.
  Future<({http.Response? response, Uri uri, int lastStatusCode})>
  _downloadAttempt(List<String> urls) async {
    Uri firstUri = Uri.parse(urls.first);
    int lastStatusCode = -1;
    for (final candidate in urls) {
      final parsed = Uri.tryParse(candidate);
      if (parsed == null) continue;
      firstUri = parsed;
      if (kDebugMode) {
        // debugPrint('[Notifications] Attachment attempt URL: $candidate');
      }
      final isPublic = parsed.path.contains('/notifications/files/');
      var attempt = await http.get(
        parsed,
        headers: <String, String>{
          'Accept': '*/*',
          if (!isPublic && authToken.trim().isNotEmpty)
            'Authorization': 'Bearer ${authToken.trim()}',
        },
      );
      if (attempt.statusCode >= 400 &&
          isPublic &&
          authToken.trim().isNotEmpty) {
        attempt = await http.get(
          parsed,
          headers: <String, String>{
            'Accept': '*/*',
            'Authorization': 'Bearer ${authToken.trim()}',
          },
        );
      }
      if (kDebugMode) {
        /* debugPrint(
          '[Notifications] Attachment response: ${attempt.statusCode} for $candidate',
        );*/
      }
      if (attempt.statusCode >= 200 && attempt.statusCode < 300) {
        return (
          response: attempt,
          uri: parsed,
          lastStatusCode: attempt.statusCode,
        );
      }
      lastStatusCode = attempt.statusCode;
    }
    return (response: null, uri: firstUri, lastStatusCode: lastStatusCode);
  }

  void _showAttachmentMissingDialog(
    BuildContext context, {
    required NotificationAttachmentModel attachment,
    required int statusCode,
    required String url,
  }) {
    final isMissing = statusCode == 404;
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          isMissing ? 'File no longer available' : 'Could not load file',
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isMissing
                  ? '“${attachment.displayName}” isn\'t on the server right now '
                        '(HTTP 404). The notification record exists, but the uploaded '
                        'file may have been removed or was never copied to the server '
                        'storage.'
                  : 'The server returned HTTP $statusCode while loading '
                        '“${attachment.displayName}”.',
            ),
            const SizedBox(height: 8),
            Text(
              url,
              style: const TextStyle(fontSize: 11, color: AppColors.gray500),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  /// Open the attachment in an in-app preview screen.
  Future<void> _viewAttachment(
    BuildContext context,
    NotificationAttachmentModel attachment,
  ) async {
    final urls = _resolveAttachmentUrls(attachment);
    if (urls.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Attachment URL is not available.')),
      );
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => NotificationAttachmentViewerScreen(
          title: attachment.displayName,
          fileUrl: urls.first,
          fallbackUrls: urls,
          bearerToken: authToken,
          isImage: _isImageAttachment(attachment),
        ),
      ),
    );
  }

  /// Download to a temp file and hand off to the OS file opener (or share dialog fallback).
  Future<void> _downloadAttachment(
    BuildContext context,
    NotificationAttachmentModel attachment,
  ) async {
    final urls = _resolveAttachmentUrls(attachment);
    if (urls.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Attachment URL is not available.')),
      );
      return;
    }

    final attempt = await _downloadAttempt(urls);
    final response = attempt.response;
    if (response == null) {
      if (!context.mounted) return;
      _showAttachmentMissingDialog(
        context,
        attachment: attachment,
        statusCode: attempt.lastStatusCode,
        url: attempt.uri.toString(),
      );
      return;
    }

    try {
      final tempDir = await Directory.systemTemp.createTemp('fmb_attachment_');
      final fileName = _safeFileName(attachment, attempt.uri);
      final file = File('${tempDir.path}/$fileName');
      await file.writeAsBytes(response.bodyBytes, flush: true);
      final result = await OpenFilex.open(file.path);
      if (result.type != ResultType.done && context.mounted) {
        final message = result.message.trim();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              message.isNotEmpty ? message : 'No app found to open this file.',
            ),
          ),
        );
      }
    } on MissingPluginException {
      if (!context.mounted) return;
      await _openInAppFallback(
        context,
        attachment: attachment,
        url: attempt.uri.toString(),
        uri: attempt.uri,
      );
    } catch (e) {
      if (!context.mounted) return;
      final errorText = e.toString().toLowerCase();
      final pluginIssue =
          errorText.contains('missingpluginexception') ||
          errorText.contains('missing plugin');
      if (pluginIssue) {
        await _openInAppFallback(
          context,
          attachment: attachment,
          url: attempt.uri.toString(),
          uri: attempt.uri,
        );
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Unable to download: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final created = notification.createdAt;
    final date = created == null
        ? 'Unknown date'
        : '${created.day}/${created.month}/${created.year}';
    final files = notification.attachments.length;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            notification.title,
            style: AppTextStyle.h4.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(notification.body, style: AppTextStyle.bodySm),
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(Icons.schedule_rounded, size: 14, color: AppColors.gray500),
              const SizedBox(width: 4),
              Text(date, style: AppTextStyle.bodyXs),
              const SizedBox(width: 10),
              if (files > 0) ...[
                Icon(
                  Icons.attach_file_rounded,
                  size: 14,
                  color: AppColors.gray500,
                ),
                const SizedBox(width: 4),
                Text('$files file(s)', style: AppTextStyle.bodyXs),
              ],
            ],
          ),
          if (files > 0) ...[
            const SizedBox(height: 10),
            Column(
              children: notification.attachments
                  .where(
                    (file) =>
                        file.effectiveStoredName.isNotEmpty ||
                        (file.url?.trim().isNotEmpty ?? false),
                  )
                  .map(
                    (file) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.gray50,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              _isImageAttachment(file)
                                  ? Icons.image_rounded
                                  : Icons.picture_as_pdf_rounded,
                              size: 18,
                              color: AppColors.fmbPrimary,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                file.displayName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTextStyle.bodySm.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            IconButton(
                              tooltip: 'View',
                              onPressed: () => _viewAttachment(context, file),
                              icon: const Icon(
                                Icons.visibility_rounded,
                                size: 18,
                              ),
                              color: AppColors.fmbPrimary,
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(
                                minWidth: 36,
                                minHeight: 36,
                              ),
                            ),
                            IconButton(
                              tooltip: 'Download',
                              onPressed: () =>
                                  _downloadAttachment(context, file),
                              icon: const Icon(
                                Icons.download_rounded,
                                size: 18,
                              ),
                              color: AppColors.fmbPrimary,
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(
                                minWidth: 36,
                                minHeight: 36,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.errorBackground,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.errorBorder),
      ),
      child: Text(
        message,
        style: AppTextStyle.bodySm.copyWith(color: AppColors.errorText),
      ),
    );
  }
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Text(
        'No notifications yet.',
        style: AppTextStyle.bodySm.copyWith(color: AppColors.gray600),
      ),
    );
  }
}
