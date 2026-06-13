import 'dart:developer' show log;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../constants/colors.dart';
import '../../../constants/styles.dart';
import '../../../models/upayment_result_model.dart';
import '../../../models/zabihat_model.dart';
import '../../../providers/auth/user_data_provider.dart';
import '../../../providers/payments_provider.dart';
import '../../../providers/zabihat_provider.dart';
import '../../../utils/upayments_app_log.dart';
import '../../../widgets/app_header.dart';
import '../../../widgets/app_logo_loader.dart';
import '../../../widgets/tab_shell_pop_scope.dart';
import '../../payment/knet_webview_screen.dart';

// ─── Responsive helpers ────────────────────────────────────────────────────────
double _rw(
  BuildContext ctx,
  double v, {
  double min = 0,
  double max = double.infinity,
}) => (v * MediaQuery.sizeOf(ctx).width / 390).clamp(min, max);
double _rh(
  BuildContext ctx,
  double v, {
  double min = 0,
  double max = double.infinity,
}) => (v * MediaQuery.sizeOf(ctx).height / 844).clamp(min, max);
double _sp(BuildContext ctx, double s) =>
    (s * MediaQuery.textScalerOf(ctx).scale(1)).clamp(s * 0.8, s * 1.2);

// ─── ZabihatTab ───────────────────────────────────────────────────────────────

class ZabihatTab extends StatefulWidget {
  const ZabihatTab({super.key, this.handleShellBack = false});

  /// When true, this tab is visible in the bottom shell; intercept system back.
  final bool handleShellBack;

  @override
  State<ZabihatTab> createState() => _ZabihatTabState();
}

class _ZabihatTabState extends State<ZabihatTab> {
  bool _hasLoadedOnce = false;

  static const Duration _payTapDebounce = Duration(seconds: 2);
  static const Duration _verifyPollMinInterval = Duration(seconds: 3);
  static const Duration _verifyPollMaxInterval = Duration(seconds: 10);
  static const Duration _verifyPollTimeout = Duration(seconds: 60);
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

  String? _activeOrderId;
  String? _activePaymentUrl;
  String? _activePayingOfferingId;
  bool _activeCheckoutReusedPending = false;

  /// After user closes KNET WebView without paying, next `/initiate` must send
  /// `forceNew` so the backend does not reuse the abandoned pending order.
  bool _forceNewAfterCheckoutAbandon = false;
  DateTime? _lastPayTapAt;

  Future<void> _load() async {
    final token = Provider.of<UserDataProvider>(context, listen: false).token;
    try {
      await Provider.of<ZabihatProvider>(
        context,
        listen: false,
      ).loadOfferings(token: token);
    } finally {
      if (mounted && !_hasLoadedOnce) {
        setState(() => _hasLoadedOnce = true);
      }
    }
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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _load();
    });
  }

  Future<void> _startZabihatPayment({
    required String offeringId,
    required double amountKd,
    required String productName,
  }) async {
    final userData = Provider.of<UserDataProvider>(context, listen: false);
    final paymentsProvider = Provider.of<PaymentsProvider>(
      context,
      listen: false,
    );
    if (paymentsProvider.isPaymentFlowInProgress || _isDebouncedTap()) {
      log(
        upayFlowLine(
          paymentsProvider.isPaymentFlowInProgress
              ? 'PAY_GUARD_BLOCKED_FLOW_BUSY'
              : 'PAY_GUARD_BLOCKED_DEBOUNCE',
          'offeringId=$offeringId',
        ),
        name: 'UPayments',
      );
      return;
    }

    final activeAction = await _promptForActiveCheckout();
    if (!mounted) {
      log(
        upayFlowLine(
          'PAY_DIALOG_CLOSED',
          'reason=unmounted offeringId=$offeringId',
        ),
        name: 'UPayments',
      );
      return;
    }
    if (activeAction == 'cancel') {
      log(
        upayFlowLine('PAY_DIALOG_CANCELLED', 'offeringId=$offeringId'),
        name: 'UPayments',
      );
      return;
    }
    log(
      upayFlowLine(
        'PAY_DIALOG_RESULT',
        'action=$activeAction offeringId=$offeringId amountKd=$amountKd',
      ),
      name: 'UPayments',
    );
    final forceNewCheckout = activeAction == 'start_over';
    if (activeAction == 'start_over') {
      setState(_clearActiveCheckout);
    }
    final continueExisting = _hasActiveCheckout && activeAction == 'continue';

    paymentsProvider.setPaymentFlowInProgress(true);
    if (mounted) {
      setState(() => _activePayingOfferingId = offeringId);
    }
    try {
      upaymentsDebugBannerOnce();
      final flowId = _newPaymentFlowId();
      log(
        upayFlowLine(
          'PAY_FLOW_ENTER',
          'flowId=$flowId screen=ZabihatTab offeringId=$offeringId amountKd=$amountKd '
              'forceNewCheckout=$forceNewCheckout continueExisting=$continueExisting',
        ),
        name: 'UPayments',
      );
      upaymentsLog(
        'ZabihatTab',
        '━━ flow START ━━ flowId=$flowId offeringId=$offeringId amountKd=$amountKd '
            'activeAction=$activeAction forceNewCheckout=$forceNewCheckout continueExisting=$continueExisting',
      );
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
            'ZabihatTab',
            'reuse ACTIVE SESSION orderId=$orderId paymentHost=${paymentUrlHost(paymentUrl)} '
                'reusedPendingFlag=$reusedPendingFromInitiate',
          );
        } else {
          final abandonBoost = _forceNewAfterCheckoutAbandon;
          final useForceNew = shouldForceNew || abandonBoost;
          log(
            upayFlowLine(
              'PAY_INITIATE_CALLING_API',
              'flowId=$flowId offeringId=$offeringId forceNew=$useForceNew amountKd=$amountKd',
            ),
            name: 'UPayments',
          );
          final init = await paymentsProvider.initiateUPayment(
            token: userData.token,
            amountKd: amountKd,
            productName: productName,
            clientOrderId: 'zabihat-$offeringId',
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
            'ZabihatTab',
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
          'ZabihatTab',
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
              'flowId=$flowId orderId=${webResult.orderId} interval=${_verifyPollMinInterval.inSeconds}-${_verifyPollMaxInterval.inSeconds}s(backoff) '
                  'timeout=${_verifyPollTimeout.inSeconds}s',
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
              'ZabihatTab',
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
          'flowId=$flowId offeringId=$offeringId orderId=${finalResult.orderId} status=${finalResult.status.label}',
        ),
        name: 'UPayments',
      );
      upaymentsLog(
        'ZabihatTab',
        '━━ flow END ━━ offeringId=$offeringId orderId=${finalResult.orderId} status=${finalResult.status.label}',
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
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message)));
      }
      if (success && mounted) {
        await Provider.of<ZabihatProvider>(
          context,
          listen: false,
        ).loadOfferings(token: userData.token);
      }
    } catch (e, st) {
      log(upayFlowLine('PAY_FLOW_ERROR', e.toString()), name: 'UPayments');
      upaymentsLog('ZabihatTab', 'FLOW ERROR $e');
      log('ZabihatTab stack', name: 'UPayments', error: e, stackTrace: st);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Unable to start payment: $e')));
    } finally {
      paymentsProvider.setPaymentFlowInProgress(false);
      if (mounted) {
        setState(() => _activePayingOfferingId = null);
      }
    }
  }

  bool _isTerminalStatus(UPaymentStatus status) {
    return status == UPaymentStatus.captured ||
        status == UPaymentStatus.declined ||
        status == UPaymentStatus.cancelled ||
        status == UPaymentStatus.failed;
  }

  Duration _nextVerifyDelay(int attempt) {
    final secs = (2 + (attempt * 2)).clamp(
      _verifyPollMinInterval.inSeconds,
      _verifyPollMaxInterval.inSeconds,
    );
    return Duration(seconds: secs);
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
        'ZabihatTab',
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
          'ZabihatTab',
          'verify POLL STOP terminal=${verify.status.label} attempts=$attempt elapsedMs=$elapsedMs',
        );
        return _VerifyPollResult(result: verify, timedOut: false);
      }
      final elapsed = DateTime.now().difference(startedAt);
      if (elapsed >= _verifyPollTimeout) {
        log(
          upayFlowLine(
            'PAY_VERIFY_POLL_DONE',
            'flowId=$flowId reason=timeout lastStatus=${verify.status.label} attempts=$attempt elapsedMs=${elapsed.inMilliseconds}',
          ),
          name: 'UPayments',
        );
        upaymentsLog(
          'ZabihatTab',
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
          'ZabihatTab',
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
      'ZabihatTab',
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
    return Consumer<ZabihatProvider>(
      builder: (context, provider, _) {
        return TabShellPopScope(
          handleShellBack: widget.handleShellBack,
          child: Scaffold(
            backgroundColor: AppColors.background,
            body: Column(
              children: [
                const AppHeader(title: 'Zabihat'),
                Expanded(
                  child: provider.isLoading
                      ? (_hasLoadedOnce
                            ? RefreshIndicator(
                                onRefresh: _load,
                                child: _ZabihatBody(
                                  provider: provider,
                                  activePayingOfferingId: _activePayingOfferingId,
                                  onPay: _startZabihatPayment,
                                ),
                              )
                            : const Center(child: AppLogoLoader()))
                      : RefreshIndicator(
                          onRefresh: _load,
                          child: _ZabihatBody(
                            provider: provider,
                            activePayingOfferingId: _activePayingOfferingId,
                            onPay: _startZabihatPayment,
                          ),
                        ),
                ),
              ],
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

// ── Body ───────────────────────────────────────────────────────────────────────

class _ZabihatBody extends StatelessWidget {
  const _ZabihatBody({
    required this.provider,
    required this.activePayingOfferingId,
    required this.onPay,
  });
  final ZabihatProvider provider;
  final String? activePayingOfferingId;
  final Future<void> Function({
    required String offeringId,
    required double amountKd,
    required String productName,
  })
  onPay;

  @override
  Widget build(BuildContext context) {
    final h = _rw(context, 16, min: 12);
    final v = _rh(context, 16, min: 12);

    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.fromLTRB(h, v, h, 100),
      itemCount: provider.offerings.length + 1, // +1 for info banner
      separatorBuilder: (_, __) => SizedBox(height: _rh(context, 16, min: 12)),
      itemBuilder: (context, i) {
        if (i == 0) return const _AboutBanner();
        final zabihat = provider.offerings[i - 1];
        return _ZabihatCard(
          zabihat: zabihat,
          provider: provider,
          activePayingOfferingId: activePayingOfferingId,
          onPay: onPay,
        );
      },
    );
  }
}

// ── About banner ───────────────────────────────────────────────────────────────

class _AboutBanner extends StatelessWidget {
  const _AboutBanner();

  static const _bg = Color(0xFFDBEAFE); // blue-100
  static const _fg = Color(0xFF1D4ED8); // blue-700
  static const _head = Color(0xFF1E3A5F); // dark navy

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(_rw(context, 14, min: 10)),
      decoration: BoxDecoration(
        color: _bg,
        borderRadius: BorderRadius.circular(_rw(context, 12, min: 8)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_outline_rounded,
            color: _fg,
            size: _rw(context, 18, min: 14),
          ),
          SizedBox(width: _rw(context, 8, min: 6)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'About Zabihat',
                  style: TextStyle(
                    color: _head,
                    fontWeight: FontWeight.w700,
                    fontSize: _sp(context, 13),
                  ),
                ),
                SizedBox(height: _rh(context, 3, min: 2)),
                Text(
                  'Fresh halal meat prepared according to Islamic guidelines. '
                  'Limited units – reserve yours today!',
                  style: TextStyle(
                    color: _fg,
                    fontSize: _sp(context, 12),
                    height: 1.4,
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

// ── Zabihat card ───────────────────────────────────────────────────────────────

class _ZabihatCard extends StatelessWidget {
  const _ZabihatCard({
    required this.zabihat,
    required this.provider,
    required this.activePayingOfferingId,
    required this.onPay,
  });
  final ZabihatModel zabihat;
  final ZabihatProvider provider;
  final String? activePayingOfferingId;
  final Future<void> Function({
    required String offeringId,
    required double amountKd,
    required String productName,
  })
  onPay;

  @override
  Widget build(BuildContext context) {
    final qty = provider.quantityFor(zabihat.id);
    final total = provider.totalFor(zabihat.id, zabihat.priceKd);
    final paid = provider.isPaid(zabihat.id);
    final pad = _rw(context, 16, min: 12);

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(pad),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(_rw(context, 16, min: 12)),
        border: Border.all(color: AppColors.border),
        boxShadow: AppShadow.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ────────────────────────────────────────────────────────
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  zabihat.title,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: _sp(context, 17),
                    color: AppColors.foreground,
                  ),
                ),
              ),
              SizedBox(width: _rw(context, 8, min: 6)),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  RichText(
                    text: TextSpan(
                      children: [
                        TextSpan(
                          text: zabihat.priceKd.toStringAsFixed(0),
                          style: TextStyle(
                            color: AppColors.fmbPrimary,
                            fontWeight: FontWeight.w800,
                            fontSize: _sp(context, 22),
                          ),
                        ),
                        TextSpan(
                          text: 'KD',
                          style: TextStyle(
                            color: AppColors.fmbPrimary,
                            fontWeight: FontWeight.w700,
                            fontSize: _sp(context, 13),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    'per unit',
                    style: TextStyle(
                      color: AppColors.gray500,
                      fontSize: _sp(context, 11),
                    ),
                  ),
                ],
              ),
            ],
          ),

          // Availability
          SizedBox(height: _rh(context, 6, min: 4)),
          Text(
            '${zabihat.available} units available',
            style: TextStyle(
              color: zabihat.available > 5
                  ? AppColors.successText
                  : AppColors.destructive,
              fontSize: _sp(context, 12),
              fontWeight: FontWeight.w500,
            ),
          ),

          SizedBox(height: _rh(context, 14, min: 10)),

          // ── Quantity selector ─────────────────────────────────────────────
          Text(
            'Select Quantity',
            style: TextStyle(
              color: AppColors.gray600,
              fontSize: _sp(context, 12),
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: _rh(context, 8, min: 6)),
          _QuantitySelector(
            quantity: qty,
            onDecrement: () => provider.decrement(zabihat.id),
            onIncrement: () =>
                provider.increment(zabihat.id, zabihat.available),
          ),

          SizedBox(height: _rh(context, 14, min: 10)),

          // ── Total price box ───────────────────────────────────────────────
          Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(
              vertical: _rh(context, 12, min: 8),
              horizontal: _rw(context, 14, min: 10),
            ),
            decoration: BoxDecoration(
              color: const Color(0xFFE6F4F1), // light teal-green
              borderRadius: BorderRadius.circular(_rw(context, 10, min: 8)),
            ),
            child: Column(
              children: [
                Text(
                  'Total Price',
                  style: TextStyle(
                    color: AppColors.gray600,
                    fontSize: _sp(context, 12),
                  ),
                ),
                SizedBox(height: _rh(context, 4, min: 2)),
                Text(
                  '${total.toStringAsFixed(0)} KD',
                  style: TextStyle(
                    color: AppColors.fmbPrimary,
                    fontWeight: FontWeight.w800,
                    fontSize: _sp(context, 22),
                  ),
                ),
              ],
            ),
          ),

          SizedBox(height: _rh(context, 14, min: 10)),

          // ── Pay Now button ────────────────────────────────────────────────
          paid
              ? _PaidBadge()
              : _PayNowButton(
                  isLoading: activePayingOfferingId == zabihat.id,
                  onTap: () async {
                    log(
                      upayFlowLine(
                        'PAY_NOW_CLICKED',
                        'screen=ZabihatCard offeringId=${zabihat.id} amountKd=$total title=${zabihat.title}',
                      ),
                      name: 'UPayments',
                    );
                    await onPay(
                      offeringId: zabihat.id,
                      amountKd: total,
                      productName: 'Zabihat - ${zabihat.title}',
                    );
                  },
                ),
        ],
      ),
    );
  }
}

// ── Quantity selector ──────────────────────────────────────────────────────────

class _QuantitySelector extends StatelessWidget {
  const _QuantitySelector({
    required this.quantity,
    required this.onDecrement,
    required this.onIncrement,
  });

  final int quantity;
  final VoidCallback onDecrement;
  final VoidCallback onIncrement;

  @override
  Widget build(BuildContext context) {
    final btnSz = _rw(context, 36, min: 30, max: 44);

    return Row(
      children: [
        // Minus
        _QtyButton(icon: Icons.remove, onTap: onDecrement, size: btnSz),
        // Count
        Expanded(
          child: Container(
            height: btnSz,
            margin: EdgeInsets.symmetric(horizontal: _rw(context, 8, min: 6)),
            decoration: BoxDecoration(
              color: AppColors.gray100,
              borderRadius: BorderRadius.circular(_rw(context, 8, min: 6)),
            ),
            child: Center(
              child: Text(
                '$quantity',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: _sp(context, 16),
                  color: AppColors.foreground,
                ),
              ),
            ),
          ),
        ),
        // Plus
        _QtyButton(icon: Icons.add, onTap: onIncrement, size: btnSz),
      ],
    );
  }
}

class _QtyButton extends StatelessWidget {
  const _QtyButton({
    required this.icon,
    required this.onTap,
    required this.size,
  });

  final IconData icon;
  final VoidCallback onTap;
  final double size;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: AppColors.gray100,
          borderRadius: BorderRadius.circular(size / 4),
          border: Border.all(color: AppColors.border),
        ),
        child: Icon(icon, size: size * 0.5, color: AppColors.foreground),
      ),
    );
  }
}

// ── Pay Now button ─────────────────────────────────────────────────────────────

class _PayNowButton extends StatelessWidget {
  const _PayNowButton({required this.onTap, required this.isLoading});
  final VoidCallback onTap;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final paymentsProvider = context.watch<PaymentsProvider>();
    final isDisabled =
        paymentsProvider.isPaymentFlowInProgress ||
        paymentsProvider.isInitiatingUPayment;
    return SizedBox(
      width: double.infinity,
      height: _rh(context, 48, min: 40, max: 56),
      child: Material(
        color: isDisabled
            ? AppColors.fmbPrimary.withValues(alpha: 0.6)
            : AppColors.fmbPrimary,
        borderRadius: BorderRadius.circular(_rw(context, 10, min: 8)),
        child: InkWell(
          onTap: isDisabled ? null : onTap,
          borderRadius: BorderRadius.circular(_rw(context, 10, min: 8)),
          child: Center(
            child: isLoading
                ? SizedBox(
                    width: _rw(context, 20, min: 16),
                    height: _rw(context, 20, min: 16),
                    child: const CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation(AppColors.fmbAccent),
                    ),
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.payment_rounded,
                        color: AppColors.fmbAccent,
                        size: _rw(context, 18, min: 14),
                      ),
                      SizedBox(width: _rw(context, 8, min: 6)),
                      Text(
                        isLoading ? 'Processing...' : 'Pay Now',
                        style: TextStyle(
                          color: AppColors.fmbAccent,
                          fontWeight: FontWeight.w600,
                          fontSize: _sp(context, 15),
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

// ── Paid badge ─────────────────────────────────────────────────────────────────

class _PaidBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: _rh(context, 48, min: 40, max: 56),
      decoration: BoxDecoration(
        color: AppColors.successBackground,
        borderRadius: BorderRadius.circular(_rw(context, 10, min: 8)),
        border: Border.all(color: AppColors.successBorder),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.check_circle_rounded,
            color: AppColors.successText,
            size: _rw(context, 18, min: 14),
          ),
          SizedBox(width: _rw(context, 8, min: 6)),
          Text(
            'Payment Successful',
            style: TextStyle(
              color: AppColors.successText,
              fontWeight: FontWeight.w600,
              fontSize: _sp(context, 14),
            ),
          ),
        ],
      ),
    );
  }
}
