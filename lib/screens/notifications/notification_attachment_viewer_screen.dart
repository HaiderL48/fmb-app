import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:http/http.dart' as http;
import 'package:open_filex/open_filex.dart';

import '../../constants/colors.dart';
import '../../widgets/app_header.dart';
import '../../widgets/app_logo_loader.dart';

class NotificationAttachmentViewerScreen extends StatefulWidget {
  const NotificationAttachmentViewerScreen({
    super.key,
    required this.title,
    required this.fileUrl,
    required this.bearerToken,
    this.fallbackUrls = const [],
    this.isImage = false,
  });

  final String title;
  final String fileUrl;
  final String bearerToken;

  /// Alternate URLs to try (e.g. relative path resolved via API base) if [fileUrl] fails.
  final List<String> fallbackUrls;
  final bool isImage;

  @override
  State<NotificationAttachmentViewerScreen> createState() =>
      _NotificationAttachmentViewerScreenState();
}

class _NotificationAttachmentViewerScreenState
    extends State<NotificationAttachmentViewerScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  Uint8List? _imageBytes;
  Directory? _tempDir;
  File? _localPreviewFile;

  Future<http.Response> _fetchOnce(Uri uri) async {
    final bare = <String, String>{'Accept': '*/*'};
    final authed = <String, String>{
      ...bare,
      if (widget.bearerToken.trim().isNotEmpty)
        'Authorization': 'Bearer ${widget.bearerToken.trim()}',
    };

    final isPublic = uri.path.contains('/notifications/files/');
    if (isPublic) {
      var r = await http.get(uri, headers: bare);
      if (r.statusCode >= 200 && r.statusCode < 300) return r;
      if (widget.bearerToken.trim().isNotEmpty) {
        r = await http.get(uri, headers: authed);
        if (r.statusCode >= 200 && r.statusCode < 300) return r;
      }
      return r;
    }
    if (widget.bearerToken.trim().isNotEmpty) {
      final r = await http.get(uri, headers: authed);
      if (r.statusCode >= 200 && r.statusCode < 300) return r;
    }
    return http.get(uri, headers: bare);
  }

  /// Tries [fileUrl] first, then [fallbackUrls]; returns the first 2xx (or last failing).
  Future<({http.Response? response, Uri uri, int lastStatusCode})>
  _fetchBytes() async {
    final candidates = <String>{
      widget.fileUrl,
      ...widget.fallbackUrls,
    }.where((s) => s.trim().isNotEmpty).toList();

    Uri firstUri = Uri.parse(candidates.first);
    int last = -1;
    for (final c in candidates) {
      final uri = Uri.tryParse(c);
      if (uri == null || !uri.hasScheme) continue;
      firstUri = uri;
      try {
        final res = await _fetchOnce(uri);
        if (res.statusCode >= 200 && res.statusCode < 300) {
          return (response: res, uri: uri, lastStatusCode: res.statusCode);
        }
        last = res.statusCode;
      } catch (_) {
        last = -1;
      }
    }
    return (response: null, uri: firstUri, lastStatusCode: last);
  }

  String _tempExtension(Uri uri) {
    final last = uri.pathSegments.isNotEmpty
        ? uri.pathSegments.last.toLowerCase()
        : '';
    if (last.endsWith('.pdf')) return 'pdf';
    if (last.endsWith('.png')) return 'png';
    if (last.endsWith('.jpg') || last.endsWith('.jpeg')) return 'jpg';
    if (last.endsWith('.webp')) return 'webp';
    if (last.endsWith('.gif')) return 'gif';
    return 'bin';
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final attempt = await _fetchBytes();
      final res = attempt.response;
      if (res == null) {
        setState(() {
          _errorMessage = attempt.lastStatusCode == 404
              ? 'File no longer available on the server (HTTP 404).\n\n'
                    'The notification record exists, but the uploaded file may '
                    'have been removed from server storage. Ask an administrator '
                    'to re-upload the attachment.'
              : 'Could not load file (HTTP ${attempt.lastStatusCode}).';
          _isLoading = false;
        });
        return;
      }

      final bytes = res.bodyBytes;
      if (widget.isImage) {
        setState(() {
          _imageBytes = bytes;
          _isLoading = false;
        });
        return;
      }

      _tempDir = await Directory.systemTemp.createTemp('fmb_notif_view_');
      final ext = _tempExtension(attempt.uri);
      final file = File('${_tempDir!.path}/view.$ext');
      await file.writeAsBytes(bytes, flush: true);
      _localPreviewFile = file;

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Could not load attachment: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _openExternally() async {
    try {
      if (_imageBytes != null) {
        final dir = await Directory.systemTemp.createTemp('fmb_notif_share_');
        final f = File('${dir.path}/image.jpg');
        await f.writeAsBytes(_imageBytes!, flush: true);
        await OpenFilex.open(f.path);
        return;
      }
      final path = _localPreviewFile?.path;
      if (path != null) await OpenFilex.open(path);
    } catch (_) {
      /* ignore */
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    try {
      _tempDir?.deleteSync(recursive: true);
    } catch (_) {
      /* ignore */
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          AppHeader(
            title: widget.title,
            leadingIcon: Icons.arrow_back_rounded,
            showSupport: false,
            showNotifications: false,
            showLogout: false,
            extraActions: [
              if (_errorMessage == null &&
                  (_imageBytes != null || _localPreviewFile != null))
                IconButton(
                  tooltip: 'Open in another app',
                  onPressed: _openExternally,
                  icon: const Icon(
                    Icons.open_in_new_rounded,
                    color: AppColors.fmbAccent,
                  ),
                ),
            ],
          ),
          Expanded(
            child: _errorMessage != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(_errorMessage!, textAlign: TextAlign.center),
                    ),
                  )
                : _isLoading
                ? const Center(child: AppLogoLoader())
                : widget.isImage && _imageBytes != null
                ? InteractiveViewer(
                    minScale: 0.5,
                    maxScale: 5,
                    child: Center(
                      child: Image.memory(_imageBytes!, fit: BoxFit.contain),
                    ),
                  )
                : _localPreviewFile != null
                ? Stack(
                    children: [
                      PDFView(
                        filePath: _localPreviewFile!.path,
                        enableSwipe: true,
                        swipeHorizontal: false,
                        autoSpacing: true,
                        pageFling: true,
                        onError: (error) {
                          if (!mounted) return;
                          setState(() {
                            _errorMessage = 'Could not preview PDF: $error';
                          });
                        },
                        onPageError: (page, error) {
                          if (!mounted) return;
                          setState(() {
                            _errorMessage =
                                'Could not preview page ${page ?? ''}: $error';
                          });
                        },
                      ),
                      if (_isLoading) const Center(child: AppLogoLoader()),
                    ],
                  )
                : const Center(child: Text('Nothing to display.')),
          ),
        ],
      ),
    );
  }
}
