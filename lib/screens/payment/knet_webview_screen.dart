import 'dart:developer' show log;

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

import '../../models/upayment_result_model.dart';
import '../../utils/upayments_app_log.dart';
import '../../widgets/app_header.dart';
import '../../widgets/app_logo_loader.dart';

/// Chrome-like mobile UA — KNET / kpay often detect the default WebView UA and
/// bounce the user to **external Chrome** (looks like “Pay opens browser”).
const String _kKnetCompatibleUserAgent =
    'Mozilla/5.0 (Linux; Android 13; Mobile) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36';

/// In-app KNET / UPayments checkout using [webview_flutter]. Intercepts return
/// URLs and pops so no stale external browser tab can resubmit the same session.
class KnetWebViewScreen extends StatefulWidget {
  const KnetWebViewScreen({
    super.key,
    required this.paymentUrl,
    required this.orderId,
    this.flowId,
  });

  final String paymentUrl;
  final String orderId;
  final String? flowId;

  @override
  State<KnetWebViewScreen> createState() => _KnetWebViewScreenState();
}

/// Extract `S.browser_fallback_url` from an `intent://…#Intent;…;end` URL (Android).
String? _httpsFromIntentUrl(String raw) {
  final m = RegExp(
    r'S\.browser_fallback_url=([^;]+)',
    caseSensitive: false,
  ).firstMatch(raw);
  if (m == null) return null;
  try {
    var s = Uri.decodeComponent(m.group(1)!);
    if (s.startsWith('http://') || s.startsWith('https://')) return s;
    return Uri.decodeComponent(s);
  } catch (_) {
    return null;
  }
}

String _knetErrorTextForLog(Uri uri) {
  final raw =
      uri.queryParameters['ErrorText'] ??
      uri.queryParameters['errorText'] ??
      uri.queryParameters['error_text'];
  if (raw == null || raw.trim().isEmpty) return '';
  try {
    return Uri.decodeQueryComponent(raw.replaceAll('+', ' '));
  } catch (_) {
    return raw;
  }
}

/// Numeric merchant `order.id` from the return URL. UPayments sends **`requested_order_id`**
/// for our id; **`order_id`** in the query is the gateway/UPayments order (different). Do not
/// treat `order_id` as the merchant oid.
String _merchantOrderIdFromReturnUri(Uri uri, String webViewOrderId) {
  String? p(String k) {
    final v = uri.queryParameters[k]?.trim();
    if (v == null || v.isEmpty) return null;
    return v;
  }

  return p('requested_order_id') ??
      p('requestedOrderId') ??
      p('orderId') ??
      p('orderid') ??
      webViewOrderId;
}

class _KnetWebViewScreenState extends State<KnetWebViewScreen> {
  late final WebViewController _controller;
  bool _loading = true;
  bool _resultHandled = false;

  static const String _successPath = '/upayments/callback/success';
  static const String _errorPath = '/upayments/callback/error';
  static const String _deepScheme = 'tmkfmb';

  static String _trimLog(String s, [int max = 500]) =>
      s.length <= max ? s : '${s.substring(0, max)}…';

  @override
  void initState() {
    super.initState();
    log(
      upayFlowLine(
        'PAY_WEBVIEW_SCREEN_OPEN',
        'flowId=${widget.flowId ?? "-"} orderId=${widget.orderId} host=${paymentUrlHost(widget.paymentUrl)} url=${paymentUrlSummary(widget.paymentUrl)}',
      ),
      name: 'UPayments',
    );
    upaymentsLog(
      'KnetWebView',
      'LOAD orderId=${widget.orderId} host=${paymentUrlHost(widget.paymentUrl)} '
          'url=${paymentUrlSummary(widget.paymentUrl)}',
    );
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..clearCache()
      ..clearLocalStorage()
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (String url) {
            if (mounted) setState(() => _loading = true);
            _checkUrl(url);
          },
          onPageFinished: (_) {
            if (mounted) setState(() => _loading = false);
          },
          onNavigationRequest: (NavigationRequest req) {
            final url = req.url;
            if (url.startsWith('intent:')) {
              final fallback = _httpsFromIntentUrl(url);
              if (fallback != null) {
                upaymentsLog(
                  'KnetWebView.intent',
                  'loading browser_fallback_url host=${paymentUrlHost(fallback)}',
                );
                _controller.loadRequest(Uri.parse(fallback));
              } else {
                upaymentsLog(
                  'KnetWebView.intent',
                  'blocked (no S.browser_fallback_url) len=${url.length}',
                );
              }
              return NavigationDecision.prevent;
            }
            final intercept = _checkUrl(url);
            return intercept
                ? NavigationDecision.prevent
                : NavigationDecision.navigate;
          },
          onWebResourceError: (WebResourceError error) {
            upaymentsLog(
              'KnetWebView.error',
              'orderId=${widget.orderId} code=${error.errorCode} ${error.description}',
            );
          },
        ),
      );

    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _primeAndLoadPaymentUrl(),
    );
  }

  Future<void> _primeAndLoadPaymentUrl() async {
    if (!mounted) return;
    try {
      await _controller.setUserAgent(_kKnetCompatibleUserAgent);
    } catch (e) {
      upaymentsLog('KnetWebView', 'setUserAgent: $e');
    }
    try {
      final platform = _controller.platform;
      if (platform is AndroidWebViewController) {
        try {
          await platform.setPaymentRequestEnabled(false);
        } catch (e) {
          upaymentsLog('KnetWebView', 'setPaymentRequestEnabled(false): $e');
        }
      }
    } catch (e) {
      upaymentsLog('KnetWebView', 'Android hardening: $e');
    }
    if (!mounted) return;
    await _controller.loadRequest(Uri.parse(widget.paymentUrl));
  }

  /// Returns `true` if [url] was handled (navigation must not proceed).
  bool _checkUrl(String url) {
    if (_resultHandled) return true;

    final uri = Uri.tryParse(url);
    if (uri == null) return false;

    final path = uri.path.toLowerCase();
    final scheme = uri.scheme.toLowerCase();
    final full = uri.toString().toLowerCase();

    if (path.contains(_successPath) || full.contains('get-knet-success')) {
      log(
        upayFlowLine(
          'PAY_WEBVIEW_RETURN_URL',
          'flowId=${widget.flowId ?? "-"} type=API_SUCCESS_CALLBACK orderId=${widget.orderId} path=${uri.path} '
              'fullUrl=${_trimLog(url)}',
        ),
        name: 'UPayments',
      );
      upaymentsLog(
        'KnetWebView.intercept',
        'success_url orderId=${widget.orderId} path=${uri.path} fullUrl=${_trimLog(url)}',
      );
      _resolve(UPaymentStatus.captured, uri);
      return true;
    }
    if (path.contains(_errorPath) || full.contains('get-knet-err')) {
      final errTxt = _knetErrorTextForLog(uri);
      final errPart = errTxt.isEmpty
          ? 'ErrorText=(none)'
          : 'ErrorText=${_trimLog(errTxt, 400)}';
      log(
        upayFlowLine(
          'PAY_WEBVIEW_RETURN_URL',
          'flowId=${widget.flowId ?? "-"} type=API_ERROR_CALLBACK orderId=${widget.orderId} path=${uri.path} '
              '$errPart fullUrl=${_trimLog(url)}',
        ),
        name: 'UPayments',
      );
      upaymentsLog(
        'KnetWebView.intercept',
        'error_url orderId=${widget.orderId} path=${uri.path} $errPart '
            'fullUrl=${_trimLog(url)} — loading in WebView (no auto-pop); close with X when done',
      );
      // Let KNET/UPayments error HTML render. Auto-popping here closed the sheet
      // immediately so users never saw the gateway message.
      return false;
    }

    if (scheme == _deepScheme) {
      final outcome = (uri.queryParameters['outcome'] ?? '').toLowerCase();
      final qKeys = uri.queryParameters.keys.toList()..sort();
      log(
        upayFlowLine(
          'PAY_WEBVIEW_DEEPLINK',
          'flowId=${widget.flowId ?? "-"} orderId=${widget.orderId} outcome=${outcome.isEmpty ? 'empty' : outcome} queryKeys=$qKeys',
        ),
        name: 'UPayments',
      );
      upaymentsLog(
        'KnetWebView.intercept',
        'DEEPLINK orderId=${widget.orderId} outcome=${outcome.isEmpty ? "(empty)" : outcome} '
            'queryKeys=$qKeys',
      );
      if (outcome.isEmpty) {
        log(
          upayFlowLine(
            'PAY_WEBVIEW_DEEPLINK_NOTE',
            'outcome empty → status=cancelled until verify; app may still poll server',
          ),
          name: 'UPayments',
        );
        upaymentsLog(
          'KnetWebView.intercept',
          'NOTE outcome empty → popping cancelled; Provider verify_poll may still clarify status',
        );
      }
      _resolve(
        outcome == 'success'
            ? UPaymentStatus.captured
            : UPaymentStatus.cancelled,
        uri,
      );
      return true;
    }

    return false;
  }

  void _resolve(UPaymentStatus status, Uri uri) {
    if (_resultHandled) return;
    _resultHandled = true;

    final orderId = _merchantOrderIdFromReturnUri(uri, widget.orderId);
    final upayOrderId = uri.queryParameters['order_id']?.trim();
    final reqOid = uri.queryParameters['requested_order_id']?.trim();

    log(
      upayFlowLine(
        'PAY_APP_REGAINED_FOCUS',
        'flowId=${widget.flowId ?? "-"} source=webView_pop status=${status.label} orderId=$orderId',
      ),
      name: 'UPayments',
    );
    upaymentsLog(
      'KnetWebView.pop',
      'POP to app status=${status.label} merchantOrderId=$orderId '
          '(requested_order_id=${reqOid ?? '—'} upayments_order_id=${upayOrderId ?? '—'})',
    );
    if (mounted) {
      Navigator.of(
        context,
      ).pop(UPaymentResultModel(status: status, orderId: orderId));
    }
  }

  void _handleCancel() {
    if (_resultHandled) return;
    _resultHandled = true;
    log(
      upayFlowLine(
        'PAY_WEBVIEW_USER_CLOSED',
        'flowId=${widget.flowId ?? "-"} orderId=${widget.orderId} (back/close before completion)',
      ),
      name: 'UPayments',
    );
    upaymentsLog('KnetWebView.pop', 'user_cancel orderId=${widget.orderId}');
    if (mounted) {
      Navigator.of(context).pop(
        UPaymentResultModel(
          status: UPaymentStatus.cancelled,
          orderId: widget.orderId,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, Object? _) {
        if (!didPop) _handleCancel();
      },
      child: Scaffold(
        body: Column(
          children: [
            AppHeader(
              title: 'KNET Payment',
              leadingIcon: Icons.close_rounded,
              onLeadingPressed: _handleCancel,
              showSupport: false,
              showNotifications: false,
              showLogout: false,
            ),
            Expanded(
              child: Stack(
                children: [
                  WebViewWidget(controller: _controller),
                  if (_loading) const Center(child: AppLogoLoader()),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
