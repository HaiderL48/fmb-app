import 'dart:async';
import 'dart:convert' show JsonEncoder;
import 'dart:developer' show log;
import 'dart:io';
import 'package:flutter/material.dart';
import '../apis/api_manager.dart';
import '../models/payment_model.dart';
import '../utils/upayments_app_log.dart';
import '../models/upayment_result_model.dart';
import '../models/user_model.dart';

class PaymentsProvider with ChangeNotifier {
  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  List<PaymentModel> _receipts = [];
  List<PaymentModel> get receipts => _receipts;

  double _completedTotalKd = 0;
  double get completedTotalKd => _completedTotalKd;

  int _completedCount = 0;
  int get completedCount => _completedCount;

  /// Derived only on the client: `true` when [user.id] appears in the list from
  /// `GET /payments/eligible-users?misriYear=…`. The backend computes that list in
  /// `listEligibleUsersForPayment` (active APP_USER, `user_takhmin` for that Misri
  /// year, `takhmin_completed_at` set, etc.) — there is no `is_eligible_for_payment`
  /// column on `users`.
  bool _isEligibleForPayment = false;
  bool get isEligibleForPayment => _isEligibleForPayment;

  /// Misri (Hijri) year passed to payment APIs — must match backend expectations, not Gregorian.
  int _misriYear = DateTime.now().year;
  int get misriYear => _misriYear;
  bool _isInitiatingUPayment = false;
  bool get isInitiatingUPayment => _isInitiatingUPayment;
  bool _isPaymentFlowInProgress = false;
  bool get isPaymentFlowInProgress => _isPaymentFlowInProgress;

  void setPaymentFlowInProgress(bool value) {
    if (_isPaymentFlowInProgress == value) return;
    _isPaymentFlowInProgress = value;
    notifyListeners();
  }

  /// Loads receipts, summary, and eligible-users for [misriYear] (Misri / Hijri year).
  /// Prefer passing [HomeProvider.progressMisriYear] after home/takhmin data is loaded.
  Future<void> loadPayments({
    required String token,
    required UserModel? user,
    int? misriYear,
  }) async {
    if (_isLoading) return;
    _setLoading(true);
    _errorMessage = null;
    _misriYear = misriYear ?? DateTime.now().year;

    try {
      final userId = user?.id ?? '';
      List<PaymentModel> allReceipts;
      try {
        final external = await ApiManager.getMuminFmbReceipts(token: token);
        allReceipts = external
            .map((r) => r.toPaymentModel(userId: userId))
            .toList();
      } catch (_) {
        allReceipts = await ApiManager.getPaymentReceipts(
          token: token,
          misriYear: _misriYear,
        );
      }

      final results = await Future.wait<dynamic>([
        ApiManager.getPaymentSummary(token: token, misriYear: _misriYear),
        ApiManager.getPaymentEligibleUsers(token: token, misriYear: _misriYear),
      ]);

      final summary = results[0] as Map<String, dynamic>;
      final eligibleUsers = results[1] as List<UserModel>;

      _receipts = allReceipts.where((p) => p.userId == userId).toList()
        ..sort((a, b) => b.receivedAt.compareTo(a.receivedAt));

      _completedTotalKd = _numFromSummary(summary, [
        'myTotalPaidKd',
        'totalPaidKd',
        'paidKd',
        'totalAmountKd',
      ]);

      if (_completedTotalKd == 0) {
        _completedTotalKd = _receipts
            .where((p) => p.status == PaymentStatus.completed)
            .fold(0.0, (sum, p) => sum + p.amountKd);
      }

      _completedCount = _intFromSummary(summary, [
        'myCompletedCount',
        'completedCount',
        'receiptsCount',
      ]);

      if (_completedCount == 0) {
        _completedCount = _receipts
            .where((p) => p.status == PaymentStatus.completed)
            .length;
      }

      // Membership in eligible-users list (server-side rules), not a User model field.
      _isEligibleForPayment = eligibleUsers.any((u) => u.id == userId);
      /* debugPrint(
        '[PaymentsProvider] Load done — misriYear: $_misriYear, receipts: ${_receipts.length}, '
        'totalPaid: $_completedTotalKd, completedCount: $_completedCount, '
        'eligible (in eligible-users list): $_isEligibleForPayment',
      );*/
    } on ApiException catch (e) {
      // debugPrint('[PaymentsProvider] loadPayments ApiException: ${e.message}');
      _errorMessage = e.message;
      _clearData();
    } on SocketException {
      // debugPrint('[PaymentsProvider] loadPayments SocketException');
      _errorMessage = 'No internet connection.';
      _clearData();
    } on TimeoutException {
      //    debugPrint('[PaymentsProvider] loadPayments TimeoutException');
      _errorMessage = 'Request timed out.';
      _clearData();
    } catch (_) {
      // debugPrint('[PaymentsProvider] loadPayments Unknown error');
      _errorMessage = 'Something went wrong. Please try again.';
      _clearData();
    }

    _setLoading(false);
  }

  double _numFromSummary(Map<String, dynamic> summary, List<String> keys) {
    for (final key in keys) {
      final value = summary[key];
      if (value is num) return value.toDouble();
      if (value is String) {
        final parsed = double.tryParse(value);
        if (parsed != null) return parsed;
      }
    }
    return 0;
  }

  int _intFromSummary(Map<String, dynamic> summary, List<String> keys) {
    for (final key in keys) {
      final value = summary[key];
      if (value is int) return value;
      if (value is num) return value.toInt();
      if (value is String) {
        final parsed = int.tryParse(value);
        if (parsed != null) return parsed;
      }
    }
    return 0;
  }

  void _clearData() {
    _receipts = [];
    _completedTotalKd = 0;
    _completedCount = 0;
    _isEligibleForPayment = false;
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  String _composeApiError(ApiException e) {
    final details = e.details?.trim() ?? '';
    if (details.isEmpty) return e.message;
    return '${e.message}\n$details';
  }

  /// Gateway rejected our merchant track / reference as already used — backend needs a fresh `/charge`.
  /// Heuristic is **not** tied to one IPAY code (UPayments/KNET codes and wording change).
  bool _isDuplicateMerchantTrackError(ApiException e) {
    final raw = '${e.message}\n${e.details ?? ''}';
    final u = raw.toUpperCase();

    // Explicit legacy code (still returned in many environments).
    if (RegExp(r'IPAY01000305', caseSensitive: false).hasMatch(raw)) {
      return true;
    }

    final mentionsDup = u.contains('DUPLICATE');
    final mentionsTrackFamily =
        u.contains('TRACK') ||
        u.contains('MERCHANT') ||
        u.contains('REFERENCE');

    if (mentionsDup && mentionsTrackFamily) {
      return true;
    }

    if (RegExp(r'MERCHANT\s+TRACK', caseSensitive: false).hasMatch(raw) &&
        (mentionsDup || u.contains('ALREADY'))) {
      return true;
    }

    // Other `IPAY` + digit codes for the same failure class (avoid matching unrelated IPAY messages).
    if (RegExp(r'IPAY\d{6,}', caseSensitive: false).hasMatch(raw) &&
        (mentionsDup ||
            RegExp(r'MERCHANT\s+TRACK', caseSensitive: false).hasMatch(raw))) {
      return true;
    }

    return false;
  }

  /// Logs full verify payload (same shape as stored callback / DB fields when API returns them).
  void _logVerifyPayloadPretty(
    Map<String, dynamic> data,
    String merchantOrderId,
  ) {
    try {
      final pretty = const JsonEncoder.withIndent('  ').convert(data);
      upaymentsLog(
        'Provider.verify.payload',
        'merchantOrderId=$merchantOrderId\n$pretty',
      );
    } catch (_) {
      upaymentsLog(
        'Provider.verify.payload',
        'merchantOrderId=$merchantOrderId data=$data',
      );
    }
  }

  Future<UPaymentInitiateModel> _completeInitiateRequest({
    required String token,
    required double amountKd,
    required String productName,
    String? clientOrderId,
    required bool forceNew,
  }) async {
    upaymentsLog(
      'Provider.initiate',
      '→ POST /payments/upayments/initiate amountKd=$amountKd forceNew=$forceNew '
          'product="${productName.length > 48 ? '${productName.substring(0, 48)}…' : productName}" '
          'clientOrderId=${clientOrderId ?? '(none)'}',
    );
    final data = await ApiManager.initiateUPayment(
      token: token,
      amountKd: amountKd,
      productName: productName,
      clientOrderId: clientOrderId,
      forceNew: forceNew,
    );
    final parsed = UPaymentInitiateModel.fromApi(data);
    log(
      upayFlowLine(
        'PAY_HTTP_INITIATE_OK',
        'orderId=${parsed.orderId} reusedPending=${parsed.reusedPending} '
            'gatewayMerchantId=${parsed.merchantReferenceId ?? '—'} host=${paymentUrlHost(parsed.paymentUrl)}',
      ),
      name: 'UPayments',
    );
    upaymentsLog(
      'Provider.initiate',
      '← 201 orderId=${parsed.orderId} reusedPending=${parsed.reusedPending} '
          'gatewayMerchantId=${parsed.merchantReferenceId ?? '—'} '
          '(UPayments reference.id / KNET merchant track id; null if reusedPending session) '
          'paymentHost=${paymentUrlHost(parsed.paymentUrl)}',
    );
    if (parsed.merchantReferenceId != null) {
      log(
        upayFlowLine(
          'PAY_GATEWAY_MERCHANT_ID',
          'gatewayMerchantId=${parsed.merchantReferenceId} merchantOrderId=${parsed.orderId}',
        ),
        name: 'UPayments',
      );
    } else {
      log(
        upayFlowLine(
          'PAY_GATEWAY_MERCHANT_ID',
          'gatewayMerchantId=(none — reused pending URL; track already embedded in session)',
        ),
        name: 'UPayments',
      );
    }
    return parsed;
  }

  Future<UPaymentInitiateModel> initiateUPayment({
    required String token,
    required double amountKd,
    String productName = 'FMB subscription payment',
    String? clientOrderId,
    bool forceNew = false,
  }) async {
    upaymentsDebugBannerOnce();
    _isInitiatingUPayment = true;
    _errorMessage = null;
    notifyListeners();

    try {
      try {
        return await _completeInitiateRequest(
          token: token,
          amountKd: amountKd,
          productName: productName,
          clientOrderId: clientOrderId,
          forceNew: forceNew,
        );
      } on ApiException catch (e) {
        if (!forceNew && _isDuplicateMerchantTrackError(e)) {
          upaymentsLog(
            'Provider.initiate',
            '← duplicate merchant track / reference (gateway) — retry with forceNew=true',
          );
          try {
            return await _completeInitiateRequest(
              token: token,
              amountKd: amountKd,
              productName: productName,
              clientOrderId: clientOrderId,
              forceNew: true,
            );
          } on ApiException catch (e2) {
            upaymentsLog(
              'Provider.initiate',
              '← ERROR after forceNew retry status=${e2.statusCode} ${e2.message}',
            );
            _errorMessage = _composeApiError(e2);
            rethrow;
          }
        }
        upaymentsLog(
          'Provider.initiate',
          '← ERROR ApiException status=${e.statusCode} ${e.message}',
        );
        _errorMessage = _composeApiError(e);
        rethrow;
      }
    } on SocketException {
      upaymentsLog('Provider.initiate', '← ERROR SocketException');
      _errorMessage =
          'Could not reach payment API. If using localhost, use your computer LAN IP on real device.';
      rethrow;
    } on TimeoutException {
      upaymentsLog('Provider.initiate', '← ERROR TimeoutException');
      _errorMessage = 'Request timed out.';
      rethrow;
    } finally {
      _isInitiatingUPayment = false;
      notifyListeners();
    }
  }

  Future<UPaymentResultModel> verifyUPayment({
    required String token,
    required String orderId,
  }) async {
    try {
      upaymentsLog('Provider.verify', '→ GET .../upayments/verify/$orderId');
      final data = await ApiManager.verifyUPayment(
        token: token,
        orderId: orderId,
      );
      final statusRaw = data['status']?.toString() ?? '';
      final statusUpper = statusRaw.trim().toUpperCase();
      // Full DB-shaped JSON on terminal states only — avoids huge logs every poll tick while PENDING.
      if (statusUpper.isNotEmpty && statusUpper != 'PENDING') {
        _logVerifyPayloadPretty(data, orderId);
      }
      final trackId = data['trackId']?.toString();
      final paymentId = data['paymentId']?.toString();
      final refId = data['referenceId']?.toString();
      final payUrl = data['paymentUrl']?.toString();
      log(
        upayFlowLine(
          'PAY_HTTP_VERIFY_OK',
          'orderId=$orderId apiStatus=$statusRaw trackId=${trackId ?? '—'} gatewayRefId=${refId ?? '—'}',
        ),
        name: 'UPayments',
      );
      upaymentsLog(
        'Provider.verify',
        '← OK orderId=$orderId apiStatus=$statusRaw '
            'gatewayMerchantTrackId=${trackId ?? '—'} gatewayReferenceId=${refId ?? '—'} '
            'paymentId=${paymentId ?? '—'} '
            'paymentHost=${payUrl != null && payUrl.isNotEmpty ? paymentUrlHost(payUrl) : '—'}',
      );
      return UPaymentResultModel(
        status: UPaymentResultModel.fromApiStatus(data['status'] as String?),
        orderId: orderId,
      );
    } on ApiException catch (e) {
      upaymentsLog(
        'Provider.verify',
        '← ERROR orderId=$orderId status=${e.statusCode} ${e.message}',
      );
      _errorMessage = _composeApiError(e);
      final lowerMessage = _errorMessage?.toLowerCase() ?? '';
      final isTemporaryMissingTx =
          e.statusCode == 404 && lowerMessage.contains('transaction not found');
      if (isTemporaryMissingTx) {
        upaymentsLog(
          'Provider.verify',
          '← soft PENDING orderId=$orderId (transaction not at gateway yet — keep polling)',
        );
        return UPaymentResultModel(
          status: UPaymentStatus.pending,
          orderId: orderId,
          message:
              'Payment is still being processed. Please check again shortly.',
        );
      }
      return UPaymentResultModel(
        status: UPaymentStatus.failed,
        orderId: orderId,
        message: _errorMessage,
      );
    } on SocketException {
      upaymentsLog(
        'Provider.verify',
        '← ERROR orderId=$orderId SocketException',
      );
      _errorMessage = 'No internet connection.';
      return UPaymentResultModel(
        status: UPaymentStatus.failed,
        orderId: orderId,
        message: _errorMessage,
      );
    } on TimeoutException {
      upaymentsLog(
        'Provider.verify',
        '← ERROR orderId=$orderId TimeoutException',
      );
      _errorMessage = 'Request timed out.';
      return UPaymentResultModel(
        status: UPaymentStatus.failed,
        orderId: orderId,
        message: _errorMessage,
      );
    } catch (e, st) {
      log(
        'verifyUPayment unknown',
        name: 'UPayments',
        error: e,
        stackTrace: st,
      );
      _errorMessage = 'Could not verify payment status.';
      return UPaymentResultModel(
        status: UPaymentStatus.failed,
        orderId: orderId,
        message: _errorMessage,
      );
    } finally {
      notifyListeners();
    }
  }
}
