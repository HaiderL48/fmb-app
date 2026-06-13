import 'dart:developer' show log;

/// Payment / KNET tracing — **filter in DevTools / Logcat by log name: `UPayments`**
/// Also useful: **`ApiManager.Payments`** (HTTP initiate/verify summaries).
///
/// Example (Android Studio / VS Code): show only lines where Logger name is UPayments.

bool _upaymentsBannerShown = false;

/// Call once (e.g. first payment tap) to print a one-line reminder how to filter logs.
void upaymentsDebugBannerOnce() {
  if (_upaymentsBannerShown) return;
  _upaymentsBannerShown = true;
  log(
    '>>> Payment debug: filter log name "UPayments" (HTTP + WebView + Provider) <<<',
    name: 'UPayments',
  );
}

String _hhMmSsSs() {
  final n = DateTime.now();
  String p2(int x) => x.toString().padLeft(2, '0');
  String p3(int x) => x.toString().padLeft(3, '0');
  return '${p2(n.hour)}:${p2(n.minute)}:${p2(n.second)}.${p3(n.millisecond)}';
}

/// Structured step log — appears under name **UPayments** for easy filtering.
void upaymentsLog(String step, String message) {
  log('[${_hhMmSsSs()}][$step] $message', name: 'UPayments');
}

/// Message line for [log] — `[HH:mm:ss.SSS] TITLE: …` (pay-now → WebView → verify timeline).
///
/// Use: `log(upayFlowLine('PAY_NOW_CLICKED', '…'), name: 'UPayments');`
///
/// | Title | Meaning |
/// |-------|---------|
/// | `PAY_NOW_CLICKED` | User tapped Pay (Zabihat card or Payment tab). |
/// | `PAY_GUARD_BLOCKED_*` | Ignored tap (flow busy or debounce). |
/// | `PAY_DIALOG_*` | Active-checkout dialog: cancelled / result / unmounted. |
/// | `PAY_AMOUNT_INVALID` | Payment tab: amount below minimum (etc.). |
/// | `PAY_FLOW_ENTER` | Starting main checkout loop. |
/// | `PAY_SESSION_REUSE` | Using saved order URL (no new initiate). |
/// | `PAY_INITIATE_CALLING_API` / `PAY_INITIATE_SUCCESS` | Backend initiate. |
/// | `PAY_HTTP_INITIATE_OK` | Provider received initiate JSON. |
/// | `PAY_WEBVIEW_OPEN` | Pushing in-app KNET WebView. |
/// | `PAY_WEBVIEW_SCREEN_OPEN` | WebView widget loaded. |
/// | `PAY_WEBVIEW_RETURN_URL` | Hit success/error callback URL. |
/// | `PAY_WEBVIEW_DEEPLINK` | App scheme `tmkfmb://` return. |
/// | `PAY_APP_REGAINED_FOCUS` | WebView popped with result (back to app). |
/// | `PAY_WEBVIEW_USER_CLOSED` | User closed WebView without gateway result. |
/// | `PAY_RETURN_FROM_WEBVIEW` | Tab received result from Navigator.pop. |
/// | `PAY_VERIFY_POLL_*` | Server verify polling. |
/// | `PAY_HTTP_VERIFY_OK` | Provider received verify JSON. |
/// | `PAY_FORCE_NEW_RETRY` | Retrying with `forceNew` after timeout. |
/// | `PAY_FLOW_FINISHED` / `PAY_FLOW_ERROR` | End state. |
String upayFlowLine(String title, [String detail = '']) {
  final suffix = detail.trim().isEmpty ? '' : ' | $detail';
  return '[${_hhMmSsSs()}] TITLE: $title$suffix';
}

/// Host only — avoids logging full KNET `paymentUrl` / trandata.
String paymentUrlHost(String url) {
  try {
    return Uri.parse(url).host;
  } catch (_) {
    return '(invalid-url)';
  }
}

/// Short URL for logs (scheme + host + path, no query) — still omit secrets in query.
String paymentUrlSummary(String url) {
  try {
    final u = Uri.parse(url);
    return '${u.scheme}://${u.host}${u.path.isEmpty ? '' : u.path}';
  } catch (_) {
    return '(invalid-url)';
  }
}
