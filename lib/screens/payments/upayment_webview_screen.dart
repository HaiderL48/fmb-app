import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../../models/upayment_result_model.dart';
import '../../widgets/app_header.dart';
import '../../widgets/app_logo_loader.dart';

class UPaymentWebViewScreen extends StatefulWidget {
  final String paymentUrl;
  final String orderId;

  const UPaymentWebViewScreen({
    super.key,
    required this.paymentUrl,
    required this.orderId,
  });

  @override
  State<UPaymentWebViewScreen> createState() => _UPaymentWebViewScreenState();
}

class _UPaymentWebViewScreenState extends State<UPaymentWebViewScreen> {
  static const String _successCallbackPath =
      '/api/v1/payments/upayments/callback/success';
  static const String _errorCallbackPath =
      '/api/v1/payments/upayments/callback/error';

  late final WebViewController _controller;
  bool _isLoading = true;
  bool _resultHandled = false;

  Future<void> _clearPaymentWebData() async {
    try {
      await _controller.clearCache();
      await _controller.clearLocalStorage();
      await WebViewCookieManager().clearCookies();
    } catch (_) {}
  }

  void _completeAndClose(UPaymentResultModel result) {
    if (_resultHandled) return;
    _resultHandled = true;
    _clearPaymentWebData();
    if (!mounted) return;
    Navigator.of(context).pop(result);
  }

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (url) {
            setState(() => _isLoading = true);
            _checkForRedirect(url);
          },
          onPageFinished: (url) {
            setState(() => _isLoading = false);
          },
          onNavigationRequest: (request) {
            _checkForRedirect(request.url);
            return NavigationDecision.navigate;
          },
          onWebResourceError: (_) {
            if (!_resultHandled) {
              _completeAndClose(
                UPaymentResultModel(
                  status: UPaymentStatus.failed,
                  orderId: widget.orderId,
                  message: 'Unable to load payment page.',
                ),
              );
            }
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.paymentUrl));
  }

  void _checkForRedirect(String url) {
    if (_resultHandled) return;
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    final path = uri.path;

    if (path == _successCallbackPath) {
      _completeAndClose(
        UPaymentResultModel(
          status: UPaymentStatus.pending,
          orderId: widget.orderId,
        ),
      );
    } else if (path == _errorCallbackPath) {
      _completeAndClose(
        UPaymentResultModel(
          status: UPaymentStatus.declined,
          orderId: widget.orderId,
        ),
      );
    }
  }

  void _cancelPayment() {
    _completeAndClose(
      UPaymentResultModel(
        status: UPaymentStatus.cancelled,
        orderId: widget.orderId,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          AppHeader(
            title: 'Pay with KNET',
            leadingIcon: Icons.close_rounded,
            onLeadingPressed: _cancelPayment,
            showSupport: false,
            showNotifications: false,
            showLogout: false,
          ),
          Expanded(
            child: Stack(
              children: [
                WebViewWidget(controller: _controller),
                if (_isLoading) const Center(child: AppLogoLoader()),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
