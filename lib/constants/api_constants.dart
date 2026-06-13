/// All API endpoint URLs for the FMB Kuwait backend.
/// Base URL: https://api.tmkfmb.com/api/v1
class ApiConstants {
  ApiConstants._();

  static const String baseUrl = 'https://api.tmkfmb.com/api/v1';
  static const String paymentsBaseUrl = baseUrl;

  /// Thali subscriber APIs only — temporary ngrok while Hostinger is not updated.
  /// Point this at [baseUrl] after deployment.
  // static const String thaliBaseUrl =
  //     'https://untitled-despair-jacket.ngrok-free.dev/api/v1';

  // ─── Auth ──────────────────────────────────────────────────────────────────
  // Keep auth on the same backend as protected APIs so issued JWTs validate.
  static const String login = '$baseUrl/auth/login';
  static const String refresh = '$baseUrl/auth/refresh';
  static const String logout = '$baseUrl/auth/logout';
  static const String authPushMeta = '$baseUrl/auth/push-meta';

  // ─── Users ────────────────────────────────────────────────────────────────
  static const String users = '$baseUrl/users';
  static String userById(String id) => '$baseUrl/users/$id';
  static const String usersImport = '$baseUrl/users/import';

  // ─── Mumin Due (external GetMuminDue, proxied by our backend) ───────────────
  /// GET /mumin-due/me — latest Takhmin & Due for the logged-in account's sabil.
  static const String muminDueMe = '$baseUrl/mumin-due/me';

  // ─── Takhmin ──────────────────────────────────────────────────────────────
  static const String takhminAppUsers = '$baseUrl/takhmin/app-users';
  static String takhminHistory(String userId) =>
      '$baseUrl/takhmin/app-users/$userId/history';
  static String takhminAmount(String userId) =>
      '$baseUrl/takhmin/app-users/$userId';
  static String takhminCompletion(String userId) =>
      '$baseUrl/takhmin/app-users/$userId/completion';

  // ─── Payments ─────────────────────────────────────────────────────────────
  static const String paymentReceipts = '$paymentsBaseUrl/payments/receipts';
  static const String paymentSummary = '$paymentsBaseUrl/payments/summary';
  static const String paymentEligible =
      '$paymentsBaseUrl/payments/eligible-users';
  static const String settingsMinInstallment =
      '$baseUrl/settings/min-installment';
  static const String paymentUPaymentsInitiate =
      '$paymentsBaseUrl/payments/upayments/initiate';
  static String paymentUPaymentsVerify(String orderId) =>
      '$paymentsBaseUrl/payments/upayments/verify/$orderId';
  static String paymentUPaymentsOrder(String orderId) =>
      '$paymentsBaseUrl/payments/upayments/orders/$orderId';
  static const String paymentUPaymentsCallbackSuccess =
      '$paymentsBaseUrl/payments/upayments/callback/success';
  static const String paymentUPaymentsCallbackError =
      '$paymentsBaseUrl/payments/upayments/callback/error';

  // ─── Packages ─────────────────────────────────────────────────────────────
  static const String packages = '$baseUrl/packages';
  static String packageById(String id) => '$baseUrl/packages/$id';

  // ─── Zabihat ──────────────────────────────────────────────────────────────
  static const String zabihat = '$baseUrl/zabihat';
  static String zabihatById(String id) => '$baseUrl/zabihat/$id';

  // ─── Menus ────────────────────────────────────────────────────────────────
  static const String menus = '$baseUrl/menus';
  static String menuById(String id) => '$baseUrl/menus/$id';

  /// Subscriber daily menu item exclusions (max 2 per day; day-before cutoff on API).
  /// Must use the same host as [menus]: exclusions validate against `DailyMenu` on that server.
  static const String menuExclusionsMe = '$baseUrl/menu-exclusions/me';

  // ─── Notifications ────────────────────────────────────────────────────────
  static const String notifications = '$baseUrl/notifications';
  static String notificationFile(String storedName) =>
      '$baseUrl/notifications/files/${Uri.encodeComponent(storedName)}';

  // ─── Feedback ──────────────────────────────────────────────────────────────
  static const String feedback = '$baseUrl/feedback';
  static const String feedbackSummary = '$baseUrl/feedback/summary';

  // ─── Thali (subscriber pauses) ───────────────────────────────────────────
  static const String thaliMePauses = '$baseUrl/thali/me/pauses';
  static String thaliMePauseById(String id) => '$baseUrl/thali/me/pauses/$id';

  // ─── Support / Contact ───────────────────────────────────────────────────
  /// GET /support  (backend-provided support contacts)
  static const String contact = '$baseUrl/support';
}
