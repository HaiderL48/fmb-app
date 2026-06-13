import 'dart:developer' show log;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../constants/colors.dart';
import '../../../utils/misri_year.dart';
import '../../../constants/styles.dart';
import '../../../models/package_model.dart';
import '../../../models/upayment_result_model.dart';
import '../../../providers/auth/user_data_provider.dart';
import '../../../providers/home_provider.dart';
import '../../../providers/payments_provider.dart';
import '../../../apis/api_manager.dart';
import '../../../utils/upayments_app_log.dart';
import '../../payment/knet_webview_screen.dart';
import '../../../widgets/app_button.dart';
import '../../../widgets/app_header.dart';
import '../../../widgets/app_logo_loader.dart';
import '../../../widgets/tab_shell_pop_scope.dart';
import '../../../services/push_notification_service.dart';

const Duration _kVerifyPollMinInterval = Duration(seconds: 3);
const Duration _kVerifyPollMaxInterval = Duration(seconds: 10);
const Duration _kVerifyPollTimeout = Duration(seconds: 60);

/// Light page background behind cards (payment mock).
const Color _kPaymentListBg = Color(0xFFF8F9FA);

class PaymentTab extends StatefulWidget {
  const PaymentTab({super.key, this.handleShellBack = false});

  /// When true, this tab is visible in the bottom shell; intercept system back.
  final bool handleShellBack;

  @override
  State<PaymentTab> createState() => _PaymentTabState();
}

class _PaymentTabState extends State<PaymentTab> {
  bool _hasLoadedOnce = false;

  static const Duration _payTapDebounce = Duration(seconds: 2);

  String _newPaymentFlowId() =>
      DateTime.now().microsecondsSinceEpoch.toRadixString(36).toUpperCase();

  Future<void> _showPaymentSuccessDialog({
    required String orderId,
    required String message,
  }) async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Payment Successful'),
        content: Text('$message\n\nOrder ID: $orderId'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Duration _nextVerifyDelay(int attempt) {
    final secs = (2 + (attempt * 2)).clamp(
      _kVerifyPollMinInterval.inSeconds,
      _kVerifyPollMaxInterval.inSeconds,
    );
    return Duration(seconds: secs);
  }

  final TextEditingController _customAmountController = TextEditingController();
  final FocusNode _customAmountFocusNode = FocusNode();
  double? _quickAmountKd;
  String? _activeOrderId;
  String? _activePaymentUrl;
  bool _activeCheckoutReusedPending = false;

  /// After user closes KNET WebView without paying, next `/initiate` must send
  /// `forceNew` so the backend does not reuse the abandoned pending order.
  bool _forceNewAfterCheckoutAbandon = false;
  DateTime? _lastPayTapAt;
  double _minPaymentKd = 50.0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _load();
    });
  }

  @override
  void dispose() {
    _customAmountController.dispose();
    _customAmountFocusNode.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final userData = Provider.of<UserDataProvider>(context, listen: false);
    final payments = Provider.of<PaymentsProvider>(context, listen: false);
    final home = Provider.of<HomeProvider>(context, listen: false);
    try {
      // Home first so we have Misri year for payment APIs (eligible-users is keyed by Misri year).
      await home.loadHomeData(userData.user, token: userData.token);
      if (!mounted) return;
      try {
        final v = await ApiManager.getMinInstallmentKd(token: userData.token);
        if (!mounted) return;
        setState(() => _minPaymentKd = v >= 0 ? v : 0);
      } catch (_) {
        // Keep default (50).
      }
      await payments.loadPayments(
        token: userData.token,
        user: userData.user,
        misriYear: home.progressMisriYear,
      );
    } finally {
      if (mounted && !_hasLoadedOnce) {
        setState(() => _hasLoadedOnce = true);
      }
    }
  }

  double? _resolvedAmountKd() {
    if (_quickAmountKd != null) return _quickAmountKd;
    final parsed = double.tryParse(_customAmountController.text.trim());
    return parsed;
  }

  List<double> _quickAmountsFor(
    HomeProvider home,
    double subscriptionRemaining,
  ) {
    final hasTakhmin = home.progressTotalKd > 0;
    if (hasTakhmin &&
        subscriptionRemaining > 0 &&
        subscriptionRemaining < _minPaymentKd) {
      return [subscriptionRemaining];
    }
    return const [50, 100, 150];
  }

  String _takhminProductName(HomeProvider home) {
    final y = home.progressMisriYear;
    if (y != null) return 'Takhmin (Misri ${formatMisriYear(y)})';
    return 'Takhmin payment';
  }

  bool get _hasActiveCheckout {
    return (_activeOrderId ?? '').isNotEmpty &&
        (_activePaymentUrl ?? '').isNotEmpty;
  }

  void _clearActiveCheckout() {
    _activeOrderId = null;
    _activePaymentUrl = null;
    _activeCheckoutReusedPending = false;
  }

  bool _isDebouncedTap() {
    final now = DateTime.now();
    if (_lastPayTapAt != null &&
        now.difference(_lastPayTapAt!) < _payTapDebounce) {
      return true;
    }
    _lastPayTapAt = now;
    return false;
  }

  Future<String> _promptForActiveCheckout() async {
    if (!_hasActiveCheckout) return 'new';
    final action = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Checkout in progress'),
        content: const Text(
          'An existing payment attempt is still pending. Continue that checkout or start over?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop('cancel'),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop('start_over'),
            child: const Text('Start over'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop('continue'),
            child: const Text('Continue'),
          ),
        ],
      ),
    );
    return action ?? 'cancel';
  }

  Future<void> _startKnetPayment() async {
    log(
      upayFlowLine('PAY_NOW_CLICKED', 'screen=PaymentTab Pay button'),
      name: 'UPayments',
    );
    final userData = Provider.of<UserDataProvider>(context, listen: false);
    final paymentsProvider = Provider.of<PaymentsProvider>(
      context,
      listen: false,
    );
    final home = Provider.of<HomeProvider>(context, listen: false);
    if (paymentsProvider.isPaymentFlowInProgress || _isDebouncedTap()) {
      log(
        upayFlowLine(
          paymentsProvider.isPaymentFlowInProgress
              ? 'PAY_GUARD_BLOCKED_FLOW_BUSY'
              : 'PAY_GUARD_BLOCKED_DEBOUNCE',
          'PaymentTab',
        ),
        name: 'UPayments',
      );
      return;
    }

    final activeAction = await _promptForActiveCheckout();
    if (!mounted) {
      log(
        upayFlowLine('PAY_DIALOG_CLOSED', 'reason=unmounted screen=PaymentTab'),
        name: 'UPayments',
      );
      return;
    }
    if (activeAction == 'cancel') {
      log(
        upayFlowLine('PAY_DIALOG_CANCELLED', 'screen=PaymentTab'),
        name: 'UPayments',
      );
      return;
    }
    log(
      upayFlowLine(
        'PAY_DIALOG_RESULT',
        'action=$activeAction screen=PaymentTab',
      ),
      name: 'UPayments',
    );
    final forceNewCheckout = activeAction == 'start_over';
    if (activeAction == 'start_over') {
      setState(_clearActiveCheckout);
    }

    final continueExisting = _hasActiveCheckout && activeAction == 'continue';
    final amountKd = _resolvedAmountKd();
    if (!continueExisting) {
      if (!paymentsProvider.isEligibleForPayment) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Takhmin is not marked as done yet. Please contact admin.',
            ),
          ),
        );
        return;
      }
      final takhminRemaining = home.progressTotalKd > 0
          ? home.remainingKd
          : 0.0;
      final isFinalRemainingBelowMinimum =
          takhminRemaining > 0 &&
          takhminRemaining < _minPaymentKd &&
          (amountKd != null) &&
          (amountKd - takhminRemaining).abs() < 0.01;

      if (home.progressTotalKd > 0) {
        if (takhminRemaining <= 0) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No payable takhmin amount remaining.'),
            ),
          );
          return;
        }
        if (amountKd != null && amountKd > (takhminRemaining + 0.01)) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Amount cannot be more than your remaining takhmin (${takhminRemaining.toStringAsFixed(2)} KD).',
              ),
            ),
          );
          return;
        }
      }

      if (amountKd == null ||
          (amountKd < _minPaymentKd && !isFinalRemainingBelowMinimum)) {
        log(
          upayFlowLine(
            'PAY_AMOUNT_INVALID',
            'amountKd=$amountKd minRequired=$_minPaymentKd',
          ),
          name: 'UPayments',
        );
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              amountKd == null
                  ? 'Select a quick amount or enter at least ${_minPaymentKd.toStringAsFixed(0)} KD.'
                  : 'Amount must be at least ${_minPaymentKd.toStringAsFixed(0)} KD, unless paying your final remaining takhmin amount.',
            ),
          ),
        );
        return;
      }
    }

    paymentsProvider.setPaymentFlowInProgress(true);
    try {
      upaymentsDebugBannerOnce();
      final flowId = _newPaymentFlowId();
      log(
        upayFlowLine(
          'PAY_FLOW_ENTER',
          'flowId=$flowId screen=PaymentTab forceNew=$forceNewCheckout continueExisting=$continueExisting '
              'amountKd=${continueExisting ? "reuse" : amountKd?.toString() ?? "null"}',
        ),
        name: 'UPayments',
      );
      upaymentsLog(
        'PaymentTab',
        '━━ flow START ━━ flowId=$flowId activeAction=$activeAction forceNewCheckout=$forceNewCheckout '
            'continueExisting=$continueExisting amountKd=${continueExisting ? "—" : amountKd?.toString() ?? "null"}',
      );
      final productName = home.progressTotalKd > 0
          ? _takhminProductName(home)
          : 'FMB subscription payment';
      var shouldContinueExisting = continueExisting;
      var shouldForceNew = forceNewCheckout;
      var alreadyForcedNewRetry = false;
      var reusedPendingFromInitiate = false;

      UPaymentResultModel? finalResult;
      while (true) {
        String orderId;
        String paymentUrl;
        if (shouldContinueExisting) {
          orderId = _activeOrderId!;
          paymentUrl = _activePaymentUrl!;
          reusedPendingFromInitiate = _activeCheckoutReusedPending;
          log(
            upayFlowLine(
              'PAY_SESSION_REUSE',
              'no new /charge orderId=$orderId host=${paymentUrlHost(paymentUrl)} '
                  'reusedPending=$reusedPendingFromInitiate',
            ),
            name: 'UPayments',
          );
          upaymentsLog(
            'PaymentTab',
            'reuse ACTIVE SESSION orderId=$orderId paymentHost=${paymentUrlHost(paymentUrl)} '
                'reusedPendingFlag=$reusedPendingFromInitiate',
          );
        } else {
          final my = home.progressMisriYear ?? 0;
          final amt = amountKd!;
          final abandonBoost = _forceNewAfterCheckoutAbandon;
          final useForceNew = shouldForceNew || abandonBoost;
          log(
            upayFlowLine(
              'PAY_INITIATE_CALLING_API',
              'flowId=$flowId misriYear=$my amountKd=$amt forceNew=$useForceNew',
            ),
            name: 'UPayments',
          );
          final init = await paymentsProvider.initiateUPayment(
            token: userData.token,
            amountKd: amt,
            productName: productName,
            clientOrderId: home.progressTotalKd > 0
                ? 'takhmin-$my-${amt.toStringAsFixed(3)}'
                : 'sub-$my-${amt.toStringAsFixed(3)}',
            forceNew: useForceNew,
          );
          if (abandonBoost) {
            _forceNewAfterCheckoutAbandon = false;
          }
          orderId = init.orderId;
          paymentUrl = init.paymentUrl;
          reusedPendingFromInitiate = init.reusedPending;
          _activeOrderId = orderId;
          _activePaymentUrl = paymentUrl;
          _activeCheckoutReusedPending = reusedPendingFromInitiate;
          log(
            upayFlowLine(
              'PAY_INITIATE_SUCCESS',
              'flowId=$flowId orderId=$orderId reusedPending=${init.reusedPending} '
                  'merchantRef=${init.merchantReferenceId ?? 'null'} host=${paymentUrlHost(paymentUrl)}',
            ),
            name: 'UPayments',
          );
          upaymentsLog(
            'PaymentTab',
            'initiate RESPONSE orderId=$orderId forceNew=$useForceNew '
                'reusedPending=${init.reusedPending} '
                'merchantReferenceId=${init.merchantReferenceId ?? 'null'} '
                'paymentHost=${paymentUrlHost(paymentUrl)}',
          );
          if (init.reusedPending && mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Resuming your existing pending checkout.'),
              ),
            );
          }
        }

        if (!mounted) return;
        final webResult = await _startPaymentInBrowser(
          paymentUrl: paymentUrl,
          orderId: orderId,
          flowId: flowId,
        );
        if (!mounted) return;
        log(
          upayFlowLine(
            'PAY_RETURN_FROM_WEBVIEW',
            'flowId=$flowId orderId=${webResult.orderId} status=${webResult.status.label} '
                '${webResult.status == UPaymentStatus.pending ? 'next=VERIFY_POLL' : 'next=SHOW_RESULT'}',
          ),
          name: 'UPayments',
        );
        upaymentsLog(
          'PaymentTab',
          'WebView CLOSED orderId=${webResult.orderId} status=${webResult.status.label} '
              '${webResult.status == UPaymentStatus.pending ? "→ verify poll" : "→ done (no poll)"}',
        );

        if (webResult.status == UPaymentStatus.cancelled) {
          _forceNewAfterCheckoutAbandon = true;
        }

        // Only poll verify when WebView closed without a definitive status (e.g. captured from redirect).
        final shouldVerify = webResult.status == UPaymentStatus.pending;
        if (shouldVerify) {
          log(
            upayFlowLine(
              'PAY_VERIFY_POLL_START',
              'flowId=$flowId orderId=${webResult.orderId} interval=${_kVerifyPollMinInterval.inSeconds}-${_kVerifyPollMaxInterval.inSeconds}s(backoff) '
                  'timeout=${_kVerifyPollTimeout.inSeconds}s',
            ),
            name: 'UPayments',
          );
          final poll = await _pollVerifyUntilTerminal(
            paymentsProvider: paymentsProvider,
            token: userData.token,
            orderId: webResult.orderId,
            flowId: flowId,
          );
          finalResult = poll.result;
          if (poll.timedOut &&
              reusedPendingFromInitiate &&
              !alreadyForcedNewRetry) {
            log(
              upayFlowLine(
                'PAY_FORCE_NEW_RETRY',
                'flowId=$flowId reason=reused_pending_verify_timeout orderId=${webResult.orderId}',
              ),
              name: 'UPayments',
            );
            upaymentsLog(
              'PaymentTab',
              'verify poll TIMEOUT (reused pending) orderId=${webResult.orderId} → forceNew retry',
            );
            alreadyForcedNewRetry = true;
            shouldContinueExisting = false;
            shouldForceNew = true;
            continue;
          }
        } else {
          finalResult = webResult;
        }
        break;
      }
      if (_isTerminalStatus(finalResult.status)) {
        _clearActiveCheckout();
      }

      if (!mounted) return;
      log(
        upayFlowLine(
          'PAY_FLOW_FINISHED',
          'flowId=$flowId orderId=${finalResult.orderId} status=${finalResult.status.label} '
              'clearedCheckout=${_isTerminalStatus(finalResult.status)}',
        ),
        name: 'UPayments',
      );
      upaymentsLog(
        'PaymentTab',
        '━━ flow END ━━ orderId=${finalResult.orderId} status=${finalResult.status.label} '
            'clearedCheckout=${_isTerminalStatus(finalResult.status)}',
      );
      final success = finalResult.status.isSuccess;
      final message = success
          ? 'Payment successful for order ${finalResult.orderId}.'
          : finalResult.status == UPaymentStatus.pending
          ? 'Payment processing, check again.'
          : finalResult.status == UPaymentStatus.cancelled
          ? 'Payment cancelled.'
          : (finalResult.message ??
                'Payment status: ${finalResult.status.label} for order ${finalResult.orderId}.');
      if (success) {
        await _showPaymentSuccessDialog(
          orderId: finalResult.orderId,
          message: 'Your payment has been completed successfully.',
        );
        await PushNotificationService.instance.showLocalNotification(
          title: 'Payment successful',
          body:
              'Your KNET payment was completed (Order ${finalResult.orderId}).',
          data: const {'screen': 'takhmin', 'type': 'payment_success'},
        );
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message)));
      }

      await _load();
    } catch (e, st) {
      log(upayFlowLine('PAY_FLOW_ERROR', e.toString()), name: 'UPayments');
      upaymentsLog('PaymentTab', 'FLOW ERROR $e');
      log('PaymentTab stack', name: 'UPayments', error: e, stackTrace: st);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Unable to start payment: $e')));
    } finally {
      paymentsProvider.setPaymentFlowInProgress(false);
    }
  }

  bool _isTerminalStatus(UPaymentStatus status) {
    return status == UPaymentStatus.captured ||
        status == UPaymentStatus.declined ||
        status == UPaymentStatus.cancelled ||
        status == UPaymentStatus.failed;
  }

  Future<_VerifyPollResult> _pollVerifyUntilTerminal({
    required PaymentsProvider paymentsProvider,
    required String token,
    required String orderId,
    required String flowId,
  }) async {
    final startedAt = DateTime.now();
    var attempt = 0;
    while (true) {
      attempt++;
      final verify = await paymentsProvider.verifyUPayment(
        token: token,
        orderId: orderId,
      );
      final elapsedMs = DateTime.now().difference(startedAt).inMilliseconds;
      log(
        upayFlowLine(
          'PAY_VERIFY_POLL_TICK',
          'flowId=$flowId attempt=$attempt orderId=$orderId status=${verify.status.label} elapsedMs=$elapsedMs',
        ),
        name: 'UPayments',
      );
      upaymentsLog(
        'PaymentTab',
        'verify POLL tick #$attempt orderId=$orderId status=${verify.status.label} elapsedMs=$elapsedMs',
      );
      if (verify.status != UPaymentStatus.pending ||
          _isTerminalStatus(verify.status)) {
        log(
          upayFlowLine(
            'PAY_VERIFY_POLL_DONE',
            'flowId=$flowId reason=terminal status=${verify.status.label} attempts=$attempt elapsedMs=$elapsedMs',
          ),
          name: 'UPayments',
        );
        upaymentsLog(
          'PaymentTab',
          'verify POLL STOP terminal=${verify.status.label} attempts=$attempt elapsedMs=$elapsedMs',
        );
        return _VerifyPollResult(result: verify, timedOut: false);
      }
      final elapsed = DateTime.now().difference(startedAt);
      if (elapsed >= _kVerifyPollTimeout) {
        log(
          upayFlowLine(
            'PAY_VERIFY_POLL_DONE',
            'flowId=$flowId reason=timeout lastStatus=${verify.status.label} attempts=$attempt elapsedMs=${elapsed.inMilliseconds}',
          ),
          name: 'UPayments',
        );
        upaymentsLog(
          'PaymentTab',
          'verify POLL STOP TIMEOUT lastStatus=${verify.status.label} attempts=$attempt elapsedMs=${elapsed.inMilliseconds}',
        );
        return _VerifyPollResult(result: verify, timedOut: true);
      }
      final wait = _nextVerifyDelay(attempt);
      await Future.delayed(wait);
      if (!mounted) {
        log(
          upayFlowLine(
            'PAY_VERIFY_POLL_DONE',
            'flowId=$flowId reason=unmounted attempts=$attempt',
          ),
          name: 'UPayments',
        );
        upaymentsLog(
          'PaymentTab',
          'verify POLL STOP unmounted attempts=$attempt',
        );
        return _VerifyPollResult(result: verify, timedOut: true);
      }
    }
  }

  Future<UPaymentResultModel> _startPaymentInBrowser({
    required String paymentUrl,
    required String orderId,
    required String flowId,
  }) async {
    if (!mounted) {
      return UPaymentResultModel(
        status: UPaymentStatus.cancelled,
        orderId: orderId,
      );
    }
    final parsed = Uri.tryParse(paymentUrl);
    if (parsed == null || !parsed.hasScheme) {
      throw const FormatException('Invalid payment URL');
    }

    log(
      upayFlowLine(
        'PAY_WEBVIEW_OPEN',
        'flowId=$flowId orderId=$orderId host=${paymentUrlHost(paymentUrl)} url=${paymentUrlSummary(paymentUrl)}',
      ),
      name: 'UPayments',
    );
    upaymentsLog(
      'PaymentTab',
      'WebView PUSH orderId=$orderId paymentHost=${paymentUrlHost(paymentUrl)} '
          'url=${paymentUrlSummary(paymentUrl)}',
    );
    final result = await Navigator.of(context).push<UPaymentResultModel>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => KnetWebViewScreen(
          paymentUrl: paymentUrl,
          orderId: orderId,
          flowId: flowId,
        ),
      ),
    );

    return result ??
        UPaymentResultModel(status: UPaymentStatus.cancelled, orderId: orderId);
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<PaymentsProvider, HomeProvider>(
      builder: (context, payments, home, _) {
        final isProcessing =
            payments.isPaymentFlowInProgress || payments.isInitiatingUPayment;
        final hasTakhmin = home.progressTotalKd > 0;

        final subscriptionTotal = hasTakhmin ? home.progressTotalKd : 0.0;
        final subscriptionPaid = hasTakhmin ? home.progressPaidKd : 0.0;
        final subscriptionRemaining = hasTakhmin ? home.remainingKd : 0.0;

        final packageLabel = home.userPackage != null
            ? (home.userPackage!.name.isNotEmpty
                  ? home.userPackage!.name
                  : '${home.userPackage!.tier.label} Package')
            : 'Food Package';
        final quickAmounts = _quickAmountsFor(home, subscriptionRemaining);
        return TabShellPopScope(
          handleShellBack: widget.handleShellBack,
          child: Scaffold(
            backgroundColor: _kPaymentListBg,
            body: GestureDetector(
              onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
              behavior: HitTestBehavior.translucent,
              child: Column(
              children: [
                const AppHeader(title: 'Payment'),
                Expanded(
                  child: payments.isLoading
                      ? (_hasLoadedOnce
                            ? RefreshIndicator(
                                onRefresh: _load,
                                color: AppColors.fmbPrimary,
                                child: _PaymentContentList(
                                  payments: payments,
                                  hasTakhmin: hasTakhmin,
                                  subscriptionTotal: subscriptionTotal,
                                  subscriptionPaid: subscriptionPaid,
                                  subscriptionRemaining: subscriptionRemaining,
                                  packageLabel: packageLabel,
                                  minPaymentKd: _minPaymentKd,
                                  quickAmounts: quickAmounts,
                                  selectedQuickAmount: _quickAmountKd,
                                  customAmountController: _customAmountController,
                                  customAmountFocusNode: _customAmountFocusNode,
                                  isProcessing: isProcessing,
                                  onPayBalance: () {
                                    setState(() {
                                      _quickAmountKd = null;
                                      final r = subscriptionRemaining;
                                      _customAmountController.text = r % 1 == 0
                                          ? r.toStringAsFixed(0)
                                          : r.toStringAsFixed(2);
                                    });
                                  },
                                  onQuickAmountSelected: (v) {
                                    setState(() {
                                      _quickAmountKd = v;
                                      _customAmountController.text = v % 1 == 0
                                          ? v.toStringAsFixed(0)
                                          : v.toStringAsFixed(2);
                                    });
                                  },
                                  onCustomAmountChanged: (_) {
                                    if (_quickAmountKd != null) {
                                      setState(() => _quickAmountKd = null);
                                    }
                                  },
                                  onStartPayment: _startKnetPayment,
                                ),
                              )
                            : const Center(child: AppLogoLoader()))
                      : RefreshIndicator(
                          onRefresh: _load,
                          color: AppColors.fmbPrimary,
                          child: _PaymentContentList(
                            payments: payments,
                            hasTakhmin: hasTakhmin,
                            subscriptionTotal: subscriptionTotal,
                            subscriptionPaid: subscriptionPaid,
                            subscriptionRemaining: subscriptionRemaining,
                            packageLabel: packageLabel,
                            minPaymentKd: _minPaymentKd,
                            quickAmounts: quickAmounts,
                            selectedQuickAmount: _quickAmountKd,
                            customAmountController: _customAmountController,
                            customAmountFocusNode: _customAmountFocusNode,
                            isProcessing: isProcessing,
                            onPayBalance: () {
                              setState(() {
                                _quickAmountKd = null;
                                final r = subscriptionRemaining;
                                _customAmountController.text = r % 1 == 0
                                    ? r.toStringAsFixed(0)
                                    : r.toStringAsFixed(2);
                              });
                            },
                            onQuickAmountSelected: (v) {
                              setState(() {
                                _quickAmountKd = v;
                                _customAmountController.text = v % 1 == 0
                                    ? v.toStringAsFixed(0)
                                    : v.toStringAsFixed(2);
                              });
                            },
                            onCustomAmountChanged: (_) {
                              if (_quickAmountKd != null) {
                                setState(() => _quickAmountKd = null);
                              }
                            },
                            onStartPayment: _startKnetPayment,
                          ),
                        ),
                ),
              ],
            ),
          ),
        ),
        );
      },
    );
  }
}

class _VerifyPollResult {
  final UPaymentResultModel result;
  final bool timedOut;
  const _VerifyPollResult({required this.result, required this.timedOut});
}

class _PaymentContentList extends StatelessWidget {
  const _PaymentContentList({
    required this.payments,
    required this.hasTakhmin,
    required this.subscriptionTotal,
    required this.subscriptionPaid,
    required this.subscriptionRemaining,
    required this.packageLabel,
    required this.minPaymentKd,
    required this.quickAmounts,
    required this.selectedQuickAmount,
    required this.customAmountController,
    required this.customAmountFocusNode,
    required this.isProcessing,
    required this.onPayBalance,
    required this.onQuickAmountSelected,
    required this.onCustomAmountChanged,
    required this.onStartPayment,
  });

  final PaymentsProvider payments;
  final bool hasTakhmin;
  final double subscriptionTotal;
  final double subscriptionPaid;
  final double subscriptionRemaining;
  final String packageLabel;
  final double minPaymentKd;
  final List<double> quickAmounts;
  final double? selectedQuickAmount;
  final TextEditingController customAmountController;
  final FocusNode customAmountFocusNode;
  final bool isProcessing;
  final VoidCallback onPayBalance;
  final ValueChanged<double> onQuickAmountSelected;
  final ValueChanged<String> onCustomAmountChanged;
  final VoidCallback onStartPayment;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
      children: [
        if (payments.errorMessage != null) ...[
          _ErrorCard(message: payments.errorMessage!),
          const SizedBox(height: 12),
        ],
        if (!hasTakhmin) ...[
          const _NoTakhminAllocationCard(),
          const SizedBox(height: 12),
        ] else if (!payments.isEligibleForPayment) ...[
          const _EligibilityHintBanner(),
          const SizedBox(height: 12),
        ] else ...[
          _SubscriptionSummaryCard(
            packageLabel: packageLabel,
            totalKd: subscriptionTotal,
            paidKd: subscriptionPaid,
            remainingKd: subscriptionRemaining,
          ),
          const SizedBox(height: 12),
          _MinimumPaymentBanner(
            minKd: minPaymentKd,
            subscriptionRemaining: subscriptionRemaining,
            hasTakhmin: hasTakhmin,
          ),
          const SizedBox(height: 12),
          if (subscriptionRemaining >= minPaymentKd) ...[
            _PayTakhminBalanceButton(
              remainingKd: subscriptionRemaining,
              onTap: onPayBalance,
            ),
            const SizedBox(height: 12),
          ],
          _WhiteSectionCard(
            title: 'Quick Amount',
            child: _QuickAmountRow(
              amounts: quickAmounts,
              selected: selectedQuickAmount,
              onSelect: onQuickAmountSelected,
            ),
          ),
          const SizedBox(height: 12),
          _WhiteSectionCard(
            title: 'Custom Amount',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Enter Amount (KD)',
                  style: AppTextStyle.bodySm.copyWith(
                    color: AppColors.gray600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: customAmountController,
                  focusNode: customAmountFocusNode,
                  onChanged: onCustomAmountChanged,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Min ${minPaymentKd.toStringAsFixed(0)} KD',
                    filled: true,
                    fillColor: AppColors.gray100,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 14,
                    ),
                    prefixIcon: Icon(
                      Icons.toll_rounded,
                      color: AppColors.gray500,
                      size: 22,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _WhiteSectionCard(
            title: 'Payment Method',
            child: const _KnetMethodCard(),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: AppButton(
              label: isProcessing ? 'Processing…' : 'Process Payment',
              isLoading: isProcessing,
              enabled: !isProcessing,
              onTap: onStartPayment,
              prefixIcon: Icons.receipt_long_rounded,
              backgroundColor: AppColors.fmbPrimary,
              textColor: AppColors.fmbAccent,
              borderRadius: AppRadius.mdAll,
            ),
          ),
          const SizedBox(height: 16),
          const _ReceiptInfoBanner(),
        ],
      ],
    );
  }
}

// ── Subscription summary (teal card, gold text) ─────────────────────────────

class _SubscriptionSummaryCard extends StatelessWidget {
  const _SubscriptionSummaryCard({
    required this.packageLabel,
    required this.totalKd,
    required this.paidKd,
    required this.remainingKd,
  });

  final String packageLabel;
  final double totalKd;
  final double paidKd;
  final double remainingKd;

  String _fmtKd(double v) => '${v.toStringAsFixed(0)} KD';

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.fmbPrimary,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppShadow.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _goldRow('Package', packageLabel),
          const SizedBox(height: 10),
          _goldRow('Total Price', totalKd > 0 ? _fmtKd(totalKd) : '—'),
          const SizedBox(height: 10),
          _goldRow('Paid', _fmtKd(paidKd)),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Divider(
              color: AppColors.fmbAccent.withValues(alpha: 0.35),
              height: 1,
            ),
          ),
          Text(
            'Remaining',
            style: TextStyle(
              color: AppColors.fmbAccent.withValues(alpha: 0.85),
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            remainingKd > 0 ? _fmtKd(remainingKd) : _fmtKd(0),
            style: const TextStyle(
              color: AppColors.fmbAccent,
              fontSize: 26,
              fontWeight: FontWeight.w800,
              height: 1.1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _goldRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 100,
          child: Text(
            '$label:',
            style: TextStyle(
              color: AppColors.fmbAccent.withValues(alpha: 0.8),
              fontSize: 13,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              color: AppColors.fmbAccent,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class _MinimumPaymentBanner extends StatelessWidget {
  const _MinimumPaymentBanner({
    required this.minKd,
    required this.subscriptionRemaining,
    required this.hasTakhmin,
  });

  final double minKd;
  final double subscriptionRemaining;
  final bool hasTakhmin;

  @override
  Widget build(BuildContext context) {
    final amt = minKd.toStringAsFixed(0);
    final showFinalRemainingMessage =
        hasTakhmin &&
        subscriptionRemaining > 0 &&
        subscriptionRemaining < minKd;
    final remainingText = subscriptionRemaining % 1 == 0
        ? subscriptionRemaining.toStringAsFixed(0)
        : subscriptionRemaining.toStringAsFixed(2);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.warningBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.warningBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_outline_rounded,
            color: AppColors.warningText,
            size: 24,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Minimum Payment',
                  style: TextStyle(
                    color: AppColors.warningText,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text.rich(
                  showFinalRemainingMessage
                      ? TextSpan(
                          style: TextStyle(
                            color: AppColors.warningText.withValues(
                              alpha: 0.95,
                            ),
                            fontSize: 13,
                            height: 1.35,
                          ),
                          children: [
                            const TextSpan(text: 'Final remaining takhmin is '),
                            TextSpan(
                              text: '$remainingText KD',
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const TextSpan(
                              text: '. You can pay this exact amount.',
                            ),
                          ],
                        )
                      : TextSpan(
                          style: TextStyle(
                            color: AppColors.warningText.withValues(
                              alpha: 0.95,
                            ),
                            fontSize: 13,
                            height: 1.35,
                          ),
                          children: [
                            const TextSpan(text: 'The minimum payment is '),
                            TextSpan(
                              text: '$amt KD',
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PayTakhminBalanceButton extends StatelessWidget {
  const _PayTakhminBalanceButton({
    required this.remainingKd,
    required this.onTap,
  });

  final double remainingKd;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final label = remainingKd % 1 == 0
        ? remainingKd.toStringAsFixed(0)
        : remainingKd.toStringAsFixed(2);
    return Material(
      color: AppColors.card,
      borderRadius: BorderRadius.circular(12),
      elevation: 0,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AppColors.fmbPrimary.withValues(alpha: 0.35),
            ),
            boxShadow: AppShadow.sm,
          ),
          child: Row(
            children: [
              Icon(
                Icons.account_balance_wallet_outlined,
                color: AppColors.fmbPrimary,
                size: 22,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Pay remaining takhmin ($label KD)',
                  style: const TextStyle(
                    color: AppColors.foreground,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: AppColors.gray500),
            ],
          ),
        ),
      ),
    );
  }
}

class _WhiteSectionCard extends StatelessWidget {
  const _WhiteSectionCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
        boxShadow: AppShadow.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.foreground,
            ),
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _QuickAmountRow extends StatelessWidget {
  const _QuickAmountRow({
    required this.amounts,
    required this.selected,
    required this.onSelect,
  });

  final List<double> amounts;
  final double? selected;
  final ValueChanged<double> onSelect;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < amounts.length; i++) ...[
          if (i > 0) const SizedBox(width: 10),
          Expanded(
            child: _QuickChip(
              amountKd: amounts[i],
              selected: selected == amounts[i],
              onTap: () => onSelect(amounts[i]),
            ),
          ),
        ],
      ],
    );
  }
}

class _QuickChip extends StatelessWidget {
  const _QuickChip({
    required this.amountKd,
    required this.selected,
    required this.onTap,
  });

  final double amountKd;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final numText = amountKd % 1 == 0
        ? amountKd.toStringAsFixed(0)
        : amountKd.toStringAsFixed(2);
    return Material(
      color: AppColors.gray100,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? AppColors.fmbPrimary : AppColors.border,
              width: selected ? 2 : 1,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                numText,
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 20,
                  color: selected ? AppColors.fmbPrimary : AppColors.gray700,
                  height: 1.1,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'KD',
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                  fontSize: 11,
                  color: AppColors.gray500,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _KnetMethodCard extends StatelessWidget {
  const _KnetMethodCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.successBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.successBorder, width: 1.5),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 24,
            height: 24,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.foreground, width: 2),
                  ),
                ),
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.foreground,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 4),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFE3F2FD),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.credit_card_rounded,
              color: Colors.blue.shade700,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'K-Net',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    color: AppColors.foreground,
                  ),
                ),
                Text(
                  'Online payment',
                  style: TextStyle(fontSize: 12, color: AppColors.gray600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ReceiptInfoBanner extends StatelessWidget {
  const _ReceiptInfoBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.infoBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.infoBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.infoBorder),
            ),
            child: Icon(
              Icons.payments_outlined,
              color: AppColors.infoText,
              size: 22,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Receipt & Confirmation',
                  style: TextStyle(
                    color: AppColors.infoText,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "You'll receive an auto-generated receipt via email with payment details.",
                  style: TextStyle(
                    color: AppColors.infoText.withValues(alpha: 0.9),
                    fontSize: 12,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Shown when the user is not in `GET /payments/eligible-users` for this Misri year.
/// Payment UI stays available; initiate may still succeed or return a clear API error.
class _EligibilityHintBanner extends StatelessWidget {
  const _EligibilityHintBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.infoBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.infoBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded, color: AppColors.infoText, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'You are not on the eligible-users list for this Misri year yet (e.g. takhmin may need to be completed). You can still enter an amount and pay—if the server rejects it, follow the message or contact support.',
              style: AppTextStyle.bodySm.copyWith(
                color: AppColors.infoText,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NoTakhminAllocationCard extends StatelessWidget {
  const _NoTakhminAllocationCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.infoBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.infoBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded, color: AppColors.infoText, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'No takhmin amount is allocated to your account yet. Payment options will appear once takhmin is assigned.',
              style: AppTextStyle.bodySm.copyWith(
                color: AppColors.infoText,
                height: 1.35,
              ),
            ),
          ),
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
