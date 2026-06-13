import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import '../../../constants/colors.dart';
import '../../../utils/misri_year.dart';
import '../../../constants/styles.dart';
import '../../../models/menu_model.dart';
import '../../../constants/svg.dart';
import '../../../models/payment_model.dart';
import '../../../models/user_model.dart';
import '../../../apis/api_manager.dart' show ApiException;
import '../../../providers/home_provider.dart';
import '../../../providers/auth/user_data_provider.dart';
import '../../../utils/app_snackbar.dart';
import '../../../widgets/app_header.dart';
import '../../../widgets/app_logo_loader.dart';
import '../../../widgets/tab_shell_pop_scope.dart';

// ─── Responsive helpers ────────────────────────────────────────────────────────

/// Returns a value scaled relative to a 390px design width.
/// Clamps between [min] and [max] so it never gets too small or too large.
double _rw(
  BuildContext context,
  double value, {
  double min = 0,
  double max = double.infinity,
}) {
  final w = MediaQuery.sizeOf(context).width;
  return (value * w / 390).clamp(min, max);
}

double _rh(
  BuildContext context,
  double value, {
  double min = 0,
  double max = double.infinity,
}) {
  final h = MediaQuery.sizeOf(context).height;
  return (value * h / 844).clamp(min, max);
}

double _sp(BuildContext context, double size) =>
    (size * MediaQuery.textScalerOf(context).scale(1)).clamp(
      size * 0.8,
      size * 1.2,
    );

// ─── HomeTab ───────────────────────────────────────────────────────────────────

class HomeTab extends StatefulWidget {
  const HomeTab({
    super.key,
    this.user,
    this.handleShellBack = false,
  });

  final UserModel? user;

  /// When true, this tab is visible in the bottom shell; intercept system back.
  final bool handleShellBack;

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  bool _hasLoadedOnce = false;

  String _token() =>
      Provider.of<UserDataProvider>(context, listen: false).token;

  Future<void> _refresh() async {
    final userData = Provider.of<UserDataProvider>(context, listen: false);
    try {
      await Provider.of<HomeProvider>(
        context,
        listen: false,
      ).loadHomeData(userData.user ?? widget.user, token: userData.token);
    } finally {
      if (mounted && !_hasLoadedOnce) {
        setState(() => _hasLoadedOnce = true);
      }
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refresh();
    });
  }

  @override
  Widget build(BuildContext context) {
    // Only the scrollable region listens to [HomeProvider] so the app bar and
    // date-picker overlay are not rebuilt on every menu/feedback/pause update.
    return TabShellPopScope(
      handleShellBack: widget.handleShellBack,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: Column(
          children: [
            const AppHeader(title: 'Dashboard'),
            Expanded(
              child: Consumer<HomeProvider>(
                builder: (context, provider, _) {
                  if (provider.isLoading && !_hasLoadedOnce) {
                    return const Center(child: AppLogoLoader());
                  }
                  return RefreshIndicator(
                    onRefresh: _refresh,
                    child: _HomeBody(
                      user: widget.user,
                      provider: provider,
                      token: _token(),
                      onRetry: _refresh,
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Scrollable body ────────────────────────────────────────────────────────────

class _HomeBody extends StatelessWidget {
  const _HomeBody({
    this.user,
    required this.provider,
    required this.token,
    required this.onRetry,
  });
  final UserModel? user;
  final HomeProvider provider;
  final String token;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    final h = _rw(context, 16, min: 12);
    final v = _rh(context, 16, min: 12);

    return RepaintBoundary(
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(h, v, h, 100),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (provider.errorMessage != null) ...[
              _HomeLoadErrorCard(
                message: provider.errorMessage!,
                onRetry: onRetry,
              ),
              SizedBox(height: _rh(context, 12, min: 8)),
            ],
            _UserWelcomeCard(user: user),
            SizedBox(height: _rh(context, 12, min: 8)),
            _StatsRow(provider: provider),
            SizedBox(height: _rh(context, 12, min: 8)),
            _PaymentProgressCard(provider: provider),
            SizedBox(height: _rh(context, 12, min: 8)),
            _WeeklyMenuCard(provider: provider, token: token),
            SizedBox(height: _rh(context, 12, min: 8)),
            _PauseThaliCard(provider: provider, token: token),
            SizedBox(height: _rh(context, 12, min: 8)),
            _RecentPaymentsCard(provider: provider),
          ],
        ),
      ),
    );
  }
}

// ── Load error (API / network) ────────────────────────────────────────────────

class _HomeLoadErrorCard extends StatelessWidget {
  const _HomeLoadErrorCard({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(_rw(context, 14, min: 12)),
      decoration: BoxDecoration(
        color: AppColors.destructive.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(_rw(context, 12, min: 10)),
        border: Border.all(
          color: AppColors.destructive.withValues(alpha: 0.35),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.cloud_off_outlined,
                color: AppColors.destructive,
                size: _rw(context, 22, min: 18),
              ),
              SizedBox(width: _rw(context, 8, min: 6)),
              Expanded(
                child: Text(
                  'Could not load dashboard',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: _sp(context, 15),
                    color: AppColors.foreground,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: _rh(context, 8, min: 6)),
          Text(
            message,
            style: TextStyle(
              fontSize: _sp(context, 13),
              color: AppColors.gray700,
              height: 1.35,
            ),
          ),
          SizedBox(height: _rh(context, 10, min: 8)),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () => onRetry(),
              icon: const Icon(Icons.refresh_rounded, size: 20),
              label: const Text('Try again'),
            ),
          ),
        ],
      ),
    );
  }
}

// ── User welcome card ─────────────────────────────────────────────────────────

class _UserWelcomeCard extends StatelessWidget {
  const _UserWelcomeCard({this.user});
  final UserModel? user;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(_rw(context, 16, min: 12)),
      decoration: BoxDecoration(
        gradient: AppGradient.cardTeal,
        borderRadius: BorderRadius.circular(_rw(context, 16, min: 12)),
        boxShadow: AppShadow.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            user?.fullName ?? 'Welcome',
            style: TextStyle(
              color: AppColors.fmbAccent,
              fontWeight: FontWeight.w700,
              fontSize: _sp(context, 20),
            ),
          ),
          SizedBox(height: _rh(context, 4, min: 2)),
          Text(
            'ITS: ${user?.itsNumber ?? '—'}  •  Sabil: ${user?.sabilNumber ?? '—'}',
            style: TextStyle(
              color: AppColors.fmbAccent.withValues(alpha: 0.8),
              fontSize: _sp(context, 12),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Pause thali (subscriber) ─────────────────────────────────────────────────

String _fmtShortDate(DateTime d) => '${d.day}/${d.month}/${d.year}';

/// Lighter than [showDateRangePicker] (one month grid at a time, less jank on device).
Future<DateTime?> _showAppDatePicker(
  BuildContext context, {
  required DateTime initialDate,
  required DateTime firstDate,
  required DateTime lastDate,
  required String helpText,
}) {
  return showDatePicker(
    context: context,
    useRootNavigator: true,
    initialDate: initialDate,
    firstDate: firstDate,
    lastDate: lastDate,
    helpText: helpText,
    builder: (ctx, child) {
      return Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: Theme.of(ctx).colorScheme.copyWith(
            primary: AppColors.fmbPrimary,
            onPrimary: AppColors.fmbAccent,
            surface: AppColors.card,
            onSurface: AppColors.foreground,
          ),
        ),
        child: child!,
      );
    },
  );
}

class _PauseThaliCard extends StatefulWidget {
  const _PauseThaliCard({required this.provider, required this.token});
  final HomeProvider provider;
  final String token;

  @override
  State<_PauseThaliCard> createState() => _PauseThaliCardState();
}

class _PauseThaliCardState extends State<_PauseThaliCard> {
  DateTime? _pauseStart;
  DateTime? _pauseEnd;
  final TextEditingController _reasonCtrl = TextEditingController();

  /// Tracks server pause row so we clear local draft when a blocking pause appears/changes.
  String? _lastHighlightedPauseId;

  HomeProvider get provider => widget.provider;
  String get token => widget.token;

  @override
  void initState() {
    super.initState();
    _lastHighlightedPauseId = widget.provider.highlightedThaliPause?.id;
    widget.provider.addListener(_onHomeProviderChanged);
  }

  void _onHomeProviderChanged() {
    final h = widget.provider.highlightedThaliPause;
    if (h == null) {
      _lastHighlightedPauseId = null;
      return;
    }
    if (_lastHighlightedPauseId != h.id) {
      _lastHighlightedPauseId = h.id;
      if (_pauseStart != null ||
          _pauseEnd != null ||
          _reasonCtrl.text.isNotEmpty) {
        if (!mounted) return;
        setState(() {
          _pauseStart = null;
          _pauseEnd = null;
          _reasonCtrl.clear();
        });
      }
    }
  }

  DateTime _today() {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day);
  }

  Future<void> _pickStart(BuildContext context) async {
    if (token.isEmpty) return;
    if (provider.highlightedThaliPause != null) {
      AppSnackBar.error(
        context,
        'You already have a pause. Cancel it first, then you can schedule a new one.',
      );
      return;
    }
    // User can only pause/cancel before the start date, so start must be after today.
    final first = _today().add(const Duration(days: 1));
    final last = first.add(const Duration(days: 365));
    final picked = await _showAppDatePicker(
      context,
      initialDate: _pauseStart ?? first,
      firstDate: first,
      lastDate: last,
      helpText: 'Pause — start date',
    );
    if (picked == null || !mounted) return;
    setState(() {
      _pauseStart = picked;
      if (_pauseEnd != null && _pauseEnd!.isBefore(picked)) {
        _pauseEnd = null;
      }
    });
  }

  Future<void> _pickEnd(BuildContext context) async {
    if (token.isEmpty) return;
    if (provider.highlightedThaliPause != null) {
      AppSnackBar.error(
        context,
        'You already have a pause. Cancel it first, then you can schedule a new one.',
      );
      return;
    }
    if (_pauseStart == null) {
      AppSnackBar.error(context, 'Please choose a start date first.');
      return;
    }
    final first = _pauseStart!;
    final last = _today().add(const Duration(days: 365));
    final initial = _pauseEnd != null && !_pauseEnd!.isBefore(first)
        ? _pauseEnd!
        : first;
    final picked = await _showAppDatePicker(
      context,
      initialDate: initial,
      firstDate: first,
      lastDate: last,
      helpText: 'Pause — end date',
    );
    if (picked == null || !mounted) return;
    setState(() => _pauseEnd = picked);
  }

  Future<void> _submit(BuildContext context) async {
    if (token.isEmpty) return;
    if (provider.highlightedThaliPause != null) {
      AppSnackBar.error(
        context,
        'You already have a pause. Cancel it first, then you can schedule a new one.',
      );
      return;
    }
    final start = _pauseStart;
    final end = _pauseEnd;
    if (start == null || end == null) {
      AppSnackBar.error(context, 'Choose both start and end dates.');
      return;
    }
    if (end.isBefore(start)) {
      AppSnackBar.error(
        context,
        'End date must be on or after start date.',
      );
      return;
    }
    final note = _reasonCtrl.text.trim();
    try {
      await provider.scheduleThaliPause(
        token: token,
        start: start,
        end: end,
        reason: note.isEmpty ? null : note,
      );
      if (!context.mounted) return;
      setState(() {
        _pauseStart = null;
        _pauseEnd = null;
        _reasonCtrl.clear();
      });
      AppSnackBar.success(context, 'Thali pause scheduled');
    } on ApiException catch (e) {
      if (!context.mounted) return;
      AppSnackBar.error(context, e.message);
    }
  }

  Widget _dateBox(
    BuildContext context, {
    required String label,
    required DateTime? value,
    required VoidCallback onTap,
    required bool enabled,
    String emptyHint = 'Tap to choose',
    String disabledHint = 'Choose start first',
  }) {
    final borderColor = enabled ? AppColors.border : AppColors.gray100;
    return Opacity(
      opacity: enabled ? 1 : 0.55,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: enabled ? onTap : null,
          borderRadius: AppRadius.mdAll,
          child: Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(
              horizontal: _rw(context, 14, min: 12),
              vertical: _rh(context, 12, min: 10),
            ),
            decoration: BoxDecoration(
              color: AppColors.inputBackground,
              borderRadius: AppRadius.mdAll,
              border: Border.all(color: borderColor),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: TextStyle(
                          fontSize: _sp(context, 11),
                          color: AppColors.gray500,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      SizedBox(height: _rh(context, 4, min: 2)),
                      Text(
                        value != null
                            ? _fmtShortDate(value)
                            : (enabled ? emptyHint : disabledHint),
                        style: TextStyle(
                          fontSize: _sp(context, 15),
                          fontWeight: FontWeight.w600,
                          color: value != null
                              ? AppColors.foreground
                              : AppColors.gray400,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.calendar_month_rounded,
                  color: enabled ? AppColors.fmbPrimary : AppColors.gray400,
                  size: _rw(context, 22, min: 18),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    widget.provider.removeListener(_onHomeProviderChanged);
    _reasonCtrl.dispose();
    super.dispose();
  }

  Future<void> _cancel(BuildContext context) async {
    if (token.isEmpty) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel pause?'),
        content: const Text(
          'Your scheduled pause will be removed. You can schedule a new one anytime.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('No'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Yes, cancel'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    try {
      await provider.cancelHighlightedThaliPause(token: token);
      if (!context.mounted) return;
      AppSnackBar.success(context, 'Pause cancelled');
    } on ApiException catch (e) {
      if (!context.mounted) return;
      AppSnackBar.error(context, e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pad = _rw(context, 16, min: 12);
    final h = provider.highlightedThaliPause;
    final busy = provider.thaliPauseBusy;
    final activeToday = provider.hasActiveThaliPauseToday;
    final canCancelExisting = h != null && HomeProvider.canModifyPause(h);

    /// One active/upcoming pause at a time (Flutter-only; server may still allow more).
    final blockNewPause = h != null;
    final canPickDates = !blockNewPause && !busy && token.isNotEmpty;
    final canPickEnd = _pauseStart != null && canPickDates;
    final canSubmit =
        !blockNewPause &&
        _pauseStart != null &&
        _pauseEnd != null &&
        !_pauseEnd!.isBefore(_pauseStart!) &&
        !busy &&
        token.isNotEmpty;

    final startDisabledHint = blockNewPause
        ? 'Cancel current pause first'
        : 'Tap to choose';
    final endDisabledHint = blockNewPause
        ? 'Cancel current pause first'
        : (_pauseStart == null ? 'Choose start first' : 'Tap to choose');

    String statusTitle;
    String statusDetail;
    if (!blockNewPause) {
      statusTitle = 'Thali delivery';
      statusDetail =
          'Choose start and end below, then submit. Your jamat will see the pause window.';
    } else if (activeToday) {
      statusTitle = 'Thali paused';
      statusDetail =
          'Paused until ${_fmtShortDate(h.endDate)} (inclusive). '
          'Cancel this pause before scheduling another.';
    } else {
      statusTitle = 'Upcoming pause';
      statusDetail =
          '${_fmtShortDate(h.startDate)} – ${_fmtShortDate(h.endDate)}. '
          'Cancel this pause before scheduling another.';
    }

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(pad),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(_rw(context, 16, min: 12)),
        border: Border.all(
          color: activeToday ? AppColors.warningBorder : AppColors.border,
        ),
        boxShadow: AppShadow.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.pause_circle_outline_rounded,
                color: AppColors.fmbPrimary,
                size: _rw(context, 22, min: 18),
              ),
              SizedBox(width: _rw(context, 8, min: 6)),
              Expanded(
                child: Text(
                  'Pause Thali',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: _sp(context, 16),
                    color: AppColors.foreground,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: _rh(context, 8, min: 6)),
          Text(
            statusTitle,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: _sp(context, 14),
              color: AppColors.foreground,
            ),
          ),
          SizedBox(height: _rh(context, 4, min: 2)),
          Text(
            statusDetail,
            style: TextStyle(
              fontSize: _sp(context, 12),
              color: AppColors.gray600,
              height: 1.35,
            ),
          ),
          SizedBox(height: _rh(context, 14, min: 10)),
          _dateBox(
            context,
            label: 'Start date',
            value: _pauseStart,
            enabled: canPickDates,
            emptyHint: 'Tap to choose',
            disabledHint: startDisabledHint,
            onTap: () => _pickStart(context),
          ),
          SizedBox(height: _rh(context, 10, min: 8)),
          _dateBox(
            context,
            label: 'End date',
            value: _pauseEnd,
            enabled: canPickEnd,
            emptyHint: 'Tap to choose',
            disabledHint: endDisabledHint,
            onTap: () => _pickEnd(context),
          ),
          SizedBox(height: _rh(context, 10, min: 8)),
          Opacity(
            opacity: canPickDates ? 1 : 0.55,
            child: IgnorePointer(
              ignoring: !canPickDates,
              child: TextField(
                controller: _reasonCtrl,
                maxLines: 2,
                readOnly: !canPickDates,
                enableInteractiveSelection: canPickDates,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) =>
                    FocusManager.instance.primaryFocus?.unfocus(),
                style: TextStyle(
                  fontSize: _sp(context, 14),
                  color: AppColors.foreground,
                ),
                decoration: InputDecoration(
                  labelText: 'Reason (optional)',
                  alignLabelWithHint: true,
                  floatingLabelStyle: TextStyle(
                    fontSize: _sp(context, 11),
                    color: AppColors.gray500,
                    fontWeight: FontWeight.w500,
                  ),
                  labelStyle: TextStyle(
                    fontSize: _sp(context, 11),
                    color: AppColors.gray500,
                    fontWeight: FontWeight.w500,
                  ),
                  filled: true,
                  fillColor: AppColors.inputBackground,
                  border: OutlineInputBorder(
                    borderRadius: AppRadius.mdAll,
                    borderSide: BorderSide(
                      color: canPickDates
                          ? AppColors.border
                          : AppColors.gray100,
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: AppRadius.mdAll,
                    borderSide: BorderSide(
                      color: canPickDates
                          ? AppColors.border
                          : AppColors.gray100,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: AppRadius.mdAll,
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                ),
              ),
            ),
          ),
          SizedBox(height: _rh(context, 12, min: 8)),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: canSubmit ? () => _submit(context) : null,
                  icon: Icon(
                    Icons.schedule_send_outlined,
                    size: _rw(context, 18, min: 16),
                  ),
                  label: Text(
                    'Submit Pause',
                    style: TextStyle(fontSize: _sp(context, 14)),
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.fmbPrimary,
                    foregroundColor: AppColors.fmbAccent,
                    padding: EdgeInsets.symmetric(
                      vertical: _rh(context, 12, min: 10),
                    ),
                    shape: const RoundedRectangleBorder(
                      borderRadius: AppRadius.mdAll,
                    ),
                  ),
                ),
              ),
              if (h != null) ...[
                SizedBox(width: _rw(context, 10, min: 8)),
                Expanded(
                  child: TextButton.icon(
                    onPressed: busy || token.isEmpty || !canCancelExisting
                        ? null
                        : () => _cancel(context),
                    icon: Icon(
                      Icons.event_busy_outlined,
                      size: _rw(context, 18, min: 16),
                    ),
                    label: Text(
                      'Cancel Pause',
                      style: TextStyle(
                        fontSize: _sp(context, 14),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.destructive,
                      disabledForegroundColor: AppColors.gray400,
                    ),
                  ),
                ),
              ],
            ],
          ),
          if (h != null && !canCancelExisting)
            Padding(
              padding: EdgeInsets.only(top: _rh(context, 8, min: 6)),
              child: Text(
                'You can only cancel a pause before its start date.',
                style: TextStyle(
                  fontSize: _sp(context, 12),
                  color: AppColors.gray600,
                ),
              ),
            ),
          if (busy)
            Padding(
              padding: EdgeInsets.only(top: _rh(context, 10, min: 8)),
              child: const Center(child: AppLogoLoader(size: 32)),
            ),
        ],
      ),
    );
  }
}

// ── Stats row ──────────────────────────────────────────────────────────────────

String _takhminStatSummary(HomeProvider p) {
  final year = p.progressMisriYear;
  final total = p.progressTotalKd;
  if (year != null && total > 0) {
    return '${formatMisriYear(year)} H · ${total.toStringAsFixed(0)} KD';
  }
  if (year != null) {
    return '${formatMisriYear(year)} H';
  }
  if (total > 0) {
    return '${total.toStringAsFixed(0)} KD';
  }
  return 'Not allocated';
}

class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.provider});
  final HomeProvider provider;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // Expanded(
        //   child: _StatCard(
        //     svgIcon: AppSvg.activePackages,
        //     label: 'Package',
        //     value: provider.userPackage?.tier.label ?? '—',
        //   ),
        // ),
        // SizedBox(width: _rw(context, 12, min: 8)),
        Expanded(
          child: _StatCard(
            svgIcon: AppSvg.activeWallet,
            label: 'Takhmin',
            value: _takhminStatSummary(provider),
            valueColor: AppColors.fmbAccent,
          ),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.svgIcon,
    required this.label,
    required this.value,
    this.valueColor,
  });

  final String svgIcon;
  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final iconContainerSz = _rw(context, 36, min: 28, max: 44);
    final iconSz = _rw(context, 18, min: 14, max: 22);

    return Container(
      padding: EdgeInsets.all(_rw(context, 12, min: 10)),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(_rw(context, 12, min: 8)),
        border: Border.all(color: AppColors.border),
        boxShadow: AppShadow.sm,
      ),
      child: Row(
        children: [
          Container(
            width: iconContainerSz,
            height: iconContainerSz,
            decoration: BoxDecoration(
              color: AppColors.fmbPrimary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: SvgPicture.asset(
                svgIcon,
                width: iconSz,
                height: iconSz,
                colorFilter: const ColorFilter.mode(
                  AppColors.fmbPrimary,
                  BlendMode.srcIn,
                ),
              ),
            ),
          ),
          SizedBox(width: _rw(context, 8, min: 6)),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: _sp(context, 11),
                    color: AppColors.gray500,
                  ),
                ),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: _sp(context, 14),
                    fontWeight: FontWeight.w700,
                    color: valueColor ?? AppColors.foreground,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Payment progress card ──────────────────────────────────────────────────────

String _fmtKd(double value) {
  final fixed = value % 1 == 0
      ? value.toStringAsFixed(0)
      : value.toStringAsFixed(2);
  return '$fixed KD';
}

class _PaymentProgressCard extends StatelessWidget {
  const _PaymentProgressCard({required this.provider});
  final HomeProvider provider;

  @override
  Widget build(BuildContext context) {
    final hasTakhmin = provider.progressTotalKd > 0;
    final percent = provider.paymentProgressPercent;
    final pctLabel = '${(percent * 100).toStringAsFixed(0)}%';
    final pad = _rw(context, 16, min: 12);
    final paidText = _fmtKd(provider.progressPaidKd);
    final remainingText = _fmtKd(provider.remainingKd);

    return Container(
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Payment Progress',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: _sp(context, 15),
                        color: AppColors.foreground,
                      ),
                    ),
                    if (provider.progressMisriYear != null) ...[
                      SizedBox(height: _rh(context, 2, min: 1)),
                      Text(
                        'Takhmin · Misri ${formatMisriYear(provider.progressMisriYear)} H',
                        style: TextStyle(
                          fontSize: _sp(context, 11),
                          color: AppColors.gray500,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (hasTakhmin)
                Text(
                  pctLabel,
                  style: TextStyle(
                    color: AppColors.fmbPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: _sp(context, 14),
                  ),
                ),
            ],
          ),
          if (!hasTakhmin) ...[
            SizedBox(height: _rh(context, 12, min: 8)),
            Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(
                horizontal: _rw(context, 12, min: 10),
                vertical: _rh(context, 10, min: 8),
              ),
              decoration: BoxDecoration(
                color: AppColors.infoBackground,
                borderRadius: AppRadius.mdAll,
                border: Border.all(color: AppColors.infoBorder),
              ),
              child: Text(
                'No takhmin amount is allocated to your account yet. Please contact support/admin.',
                style: TextStyle(
                  color: AppColors.infoText,
                  fontSize: _sp(context, 12),
                  height: 1.35,
                ),
              ),
            ),
          ] else ...[
            SizedBox(height: _rh(context, 12, min: 8)),
            ClipRRect(
              borderRadius: AppRadius.fullAll,
              child: LinearProgressIndicator(
                value: percent,
                minHeight: _rh(context, 8, min: 6),
                backgroundColor: AppColors.gray100,
                valueColor: const AlwaysStoppedAnimation(AppColors.fmbPrimary),
              ),
            ),
            SizedBox(height: _rh(context, 12, min: 8)),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Paid: $paidText',
                    style: TextStyle(
                      color: AppColors.gray600,
                      fontSize: _sp(context, 12),
                      fontWeight: FontWeight.w400,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                SizedBox(width: _rw(context, 12, min: 8)),
                Expanded(
                  child: Text(
                    'Remaining: $remainingText',
                    style: TextStyle(
                      color: AppColors.gray600,
                      fontSize: _sp(context, 12),
                      fontWeight: FontWeight.w400,
                    ),
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.right,
                  ),
                ),
              ],
            ),
            SizedBox(height: _rh(context, 16, min: 12)),
            Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(
                horizontal: _rw(context, 14, min: 12),
                vertical: _rh(context, 12, min: 10),
              ),
              decoration: BoxDecoration(
                color: AppColors.warningBackground,
                borderRadius: AppRadius.mdAll,
                border: Border.all(color: AppColors.warningBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$remainingText remaining',
                    style: TextStyle(
                      color: AppColors.fmbAccentDark,
                      fontSize: _sp(context, 14),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  SizedBox(height: _rh(context, 4, min: 2)),
                  Text(
                    provider.remainingKd > 0
                        ? 'Make your next payment to stay active'
                        : 'Your takhmin payment is complete',
                    style: TextStyle(
                      color: AppColors.warningText,
                      fontSize: _sp(context, 12),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Weekly menu card ───────────────────────────────────────────────────────────

class _WeeklyMenuCard extends StatelessWidget {
  const _WeeklyMenuCard({required this.provider, required this.token});
  final HomeProvider provider;
  final String token;

  @override
  Widget build(BuildContext context) {
    final menu = provider.selectedMenu;
    final pad = _rw(context, 16, min: 12);

    return Container(
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
          // Header
          Row(
            children: [
              SvgPicture.asset(
                AppSvg.calendar,
                width: _rw(context, 18, min: 14),
                height: _rw(context, 18, min: 14),
                colorFilter: const ColorFilter.mode(
                  AppColors.fmbPrimary,
                  BlendMode.srcIn,
                ),
              ),
              SizedBox(width: _rw(context, 8, min: 6)),
              Text(
                "This Week's Menu",
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: _sp(context, 15),
                  color: AppColors.foreground,
                ),
              ),
            ],
          ),
          SizedBox(height: _rh(context, 12, min: 8)),

          // Day tabs
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: List.generate(provider.weeklyMenu.length, (i) {
                final isActive = provider.selectedMenuIndex == i;
                final day = provider.weeklyMenu[i].dayLabel;
                return Padding(
                  padding: EdgeInsets.only(right: _rw(context, 8, min: 6)),
                  child: GestureDetector(
                    onTap: () => provider.selectMenuDay(i),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: EdgeInsets.symmetric(
                        horizontal: _rw(context, 12, min: 10),
                        vertical: _rh(context, 8, min: 6),
                      ),
                      decoration: BoxDecoration(
                        color: isActive
                            ? AppColors.fmbPrimary
                            : AppColors.gray100,
                        borderRadius: AppRadius.lgAll,
                      ),
                      child: Text(
                        day,
                        style: TextStyle(
                          color: isActive
                              ? AppColors.fmbAccent
                              : AppColors.gray700,
                          fontWeight: isActive
                              ? FontWeight.w600
                              : FontWeight.w400,
                          fontSize: _sp(context, 13),
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
          SizedBox(height: _rh(context, 12, min: 8)),

          // Today's meal
          if (menu != null) ...[
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(_rw(context, 12, min: 10)),
              decoration: BoxDecoration(
                color: AppColors.gray50,
                borderRadius: AppRadius.lgAll,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Today's Meal",
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: _sp(context, 14),
                      color: AppColors.foreground,
                    ),
                  ),
                  SizedBox(height: _rh(context, 8, min: 4)),
                  ...menu.items.map(
                    (item) => Padding(
                      padding: EdgeInsets.only(bottom: _rh(context, 4, min: 2)),
                      child: Row(
                        children: [
                          Container(
                            width: _rw(context, 6, min: 5),
                            height: _rw(context, 6, min: 5),
                            margin: EdgeInsets.only(
                              right: _rw(context, 8, min: 6),
                              top: 1,
                            ),
                            decoration: const BoxDecoration(
                              color: AppColors.fmbPrimary,
                              shape: BoxShape.circle,
                            ),
                          ),
                          Flexible(
                            child: Text(
                              item,
                              style: TextStyle(
                                color: AppColors.gray700,
                                fontSize: _sp(context, 13),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: _rh(context, 16, min: 12)),
            _MenuExclusionsSection(
              key: ValueKey(menu.id),
              provider: provider,
              menu: menu,
              token: token,
            ),
          ],
        ],
      ),
    );
  }
}

// ── Menu exclusions (subscriber; max 2; day-before rule on API) ───────────────

bool _sameStringSet(List<String> a, List<String> b) {
  if (a.length != b.length) return false;
  final sa = Set<String>.from(a);
  final sb = Set<String>.from(b);
  return sa.length == sb.length && sa.containsAll(sb);
}

class _MenuExclusionsSection extends StatefulWidget {
  const _MenuExclusionsSection({
    super.key,
    required this.provider,
    required this.menu,
    required this.token,
  });

  final HomeProvider provider;
  final MenuModel menu;
  final String token;

  @override
  State<_MenuExclusionsSection> createState() => _MenuExclusionsSectionState();
}

class _MenuExclusionsSectionState extends State<_MenuExclusionsSection> {
  late String _trackedMenuId;
  late List<String> _draft;

  /// True after the user changes checkboxes; blocks overwriting [_draft] from the provider.
  bool _pendingEdits = false;

  HomeProvider get _p => widget.provider;

  @override
  void initState() {
    super.initState();
    _trackedMenuId = widget.menu.id;
    _draft = List<String>.from(_p.excludedMenuItems);
    _p.addListener(_onProvider);
  }

  @override
  void dispose() {
    _p.removeListener(_onProvider);
    super.dispose();
  }

  void _onProvider() {
    if (!mounted) return;
    if (widget.menu.id != _trackedMenuId) return;
    if (_p.menuExclusionsLoading) return;
    if (_pendingEdits) return;
    final server = _p.excludedMenuItems;
    if (_sameStringSet(_draft, server)) return;
    setState(() => _draft = List<String>.from(server));
  }

  @override
  void didUpdateWidget(covariant _MenuExclusionsSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.menu.id != oldWidget.menu.id) {
      _trackedMenuId = widget.menu.id;
      _pendingEdits = false;
      _draft = List<String>.from(_p.excludedMenuItems);
    }
  }

  bool get _hasPendingChanges => !_sameStringSet(_draft, _p.excludedMenuItems);

  String _primaryActionLabel() {
    if (!_hasPendingChanges) return 'No changes to save';
    final n = _draft.length;
    if (n == 0) return 'Save changes';
    return n == 1 ? 'Cancel 1 Item' : 'Cancel $n Items';
  }

  IconData _menuExclusionsActionIcon() {
    final label = _primaryActionLabel();
    if (label.startsWith('Cancel')) {
      return Icons.remove_circle_outline_rounded;
    }
    return Icons.save_outlined;
  }

  Future<void> _commit(BuildContext context) async {
    if (widget.token.isEmpty || !_hasPendingChanges) return;
    try {
      await _p.saveMenuItemExclusions(
        token: widget.token,
        menu: widget.menu,
        items: List<String>.from(_draft),
      );
      if (!context.mounted) return;
      setState(() {
        _pendingEdits = false;
        _draft = List<String>.from(_p.excludedMenuItems);
      });
      AppSnackBar.success(context, 'Your menu choices were updated.');
    } on ApiException catch (e) {
      // debugPrint('══ FMB menu exclusions (ApiException) ══');
      // debugPrint('toString: $e');
      // debugPrint('statusCode: ${e.statusCode}');
      // debugPrint('code: ${e.code}');
      // debugPrint('message: ${e.message}');
      // debugPrint('Stack:\n$st');
      // debugPrint('════════════════════════════════════════');
      if (!context.mounted) return;
      AppSnackBar.error(context, e.message);
    } catch (e) {
      // debugPrint('══ FMB menu exclusions (other error) ══');
      // debugPrint('type: ${e.runtimeType}');
      // debugPrint('toString: $e');
      // debugPrint('Stack:\n$st');
      // debugPrint('════════════════════════════════════════');
      if (!context.mounted) return;
      AppSnackBar.error(
        context,
        'Could not save exclusions. Check your internet connection and try again.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final canEdit = HomeProvider.canEditMenuExclusionsForDate(
      widget.menu.menuDate,
    );
    final saving = _p.menuExclusionsSaving;
    final disabledInputs =
        widget.token.isEmpty || !canEdit || saving || _p.menuExclusionsLoading;
    // Keep the action visible after save so users can uncheck to undo and tap again.
    final showCommitButton =
        canEdit && widget.token.isNotEmpty && !_p.menuExclusionsLoading;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Skip dishes for this menu',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: _sp(context, 14),
            color: AppColors.foreground,
          ),
        ),
        SizedBox(height: _rh(context, 6, min: 4)),
        Text(
          canEdit
              ? 'Pick up to 2 dishes you do not want, then use the button at the bottom to save. You can change this until the day before this menu.'
              : 'You can no longer change skips for this day. The cut-off is the day before the menu—the same as Thali pause.',
          style: TextStyle(
            fontSize: _sp(context, 12),
            color: AppColors.gray600,
            height: 1.35,
          ),
        ),
        SizedBox(height: _rh(context, 10, min: 8)),
        if (_p.menuExclusionsLoading)
          Padding(
            padding: EdgeInsets.symmetric(vertical: _rh(context, 8, min: 6)),
            child: const LinearProgressIndicator(minHeight: 3),
          ),
        ...widget.menu.items.map((item) {
          final excluded = _draft.contains(item);
          return CheckboxListTile(
            value: excluded,
            contentPadding: EdgeInsets.zero,
            dense: true,
            controlAffinity: ListTileControlAffinity.leading,
            onChanged: disabledInputs
                ? null
                : (v) {
                    if (v == true && !excluded && _draft.length >= 2) {
                      AppSnackBar.warning(
                        context,
                        'You can skip at most 2 dishes for this day.',
                      );
                      return;
                    }
                    setState(() {
                      _pendingEdits = true;
                      if (v == true) {
                        if (!_draft.contains(item)) _draft.add(item);
                      } else {
                        _draft.remove(item);
                      }
                    });
                  },
            title: Text(
              item,
              style: TextStyle(
                fontSize: _sp(context, 13),
                color: excluded ? AppColors.gray500 : AppColors.gray700,
                decoration: excluded
                    ? TextDecoration.lineThrough
                    : TextDecoration.none,
              ),
            ),
          );
        }),
        if (showCommitButton) ...[
          SizedBox(height: _rh(context, 12, min: 8)),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: saving || !_hasPendingChanges
                  ? null
                  : () => _commit(context),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.fmbPrimary,
                foregroundColor: AppColors.fmbAccent,
                padding: EdgeInsets.symmetric(
                  vertical: _rh(context, 12, min: 10),
                ),
                shape: const RoundedRectangleBorder(
                  borderRadius: AppRadius.mdAll,
                ),
              ),
              child: saving
                  ? SizedBox(
                      height: _sp(context, 20),
                      width: _sp(context, 20),
                      child: const CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.fmbAccent,
                      ),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _menuExclusionsActionIcon(),
                          size: _rw(context, 18, min: 16),
                        ),
                        SizedBox(width: _rw(context, 8, min: 6)),
                        Flexible(
                          child: Text(
                            _primaryActionLabel(),
                            style: TextStyle(fontSize: _sp(context, 14)),
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ],
      ],
    );
  }
}

// ── Recent payments card ───────────────────────────────────────────────────────

class _RecentPaymentsCard extends StatelessWidget {
  const _RecentPaymentsCard({required this.provider});
  final HomeProvider provider;

  @override
  Widget build(BuildContext context) {
    final payments = provider.recentPayments;
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
          Text(
            'Recent Payments',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: _sp(context, 16),
              color: AppColors.foreground,
            ),
          ),
          SizedBox(height: _rh(context, 12, min: 8)),
          if (payments.isEmpty)
            Padding(
              padding: EdgeInsets.symmetric(vertical: _rh(context, 12, min: 8)),
              child: Text(
                'No payments yet.',
                style: TextStyle(
                  color: AppColors.gray500,
                  fontSize: _sp(context, 13),
                ),
              ),
            )
          else
            ...payments.map((p) => _PaymentRow(payment: p)),
        ],
      ),
    );
  }
}

class _PaymentRow extends StatelessWidget {
  const _PaymentRow({required this.payment});
  final PaymentModel payment;

  @override
  Widget build(BuildContext context) {
    final date =
        '${payment.receivedAt.month}/${payment.receivedAt.day}/${payment.receivedAt.year}';

    Color statusBg;
    Color statusFg;
    switch (payment.status) {
      case PaymentStatus.completed:
        statusBg = AppColors.foreground;
        statusFg = AppColors.background;
        break;
      case PaymentStatus.pending:
        statusBg = AppColors.warningBackground;
        statusFg = AppColors.warningText;
        break;
      case PaymentStatus.failed:
        statusBg = AppColors.errorBackground;
        statusFg = AppColors.errorText;
        break;
    }

    return Container(
      margin: EdgeInsets.only(bottom: _rh(context, 10, min: 8)),
      padding: EdgeInsets.symmetric(
        horizontal: _rw(context, 14, min: 10),
        vertical: _rh(context, 14, min: 10),
      ),
      decoration: BoxDecoration(
        color: AppColors.gray50,
        borderRadius: BorderRadius.circular(_rw(context, 12, min: 8)),
      ),
      child: Row(
        children: [
          // Amount + date
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${payment.amountKd.toStringAsFixed(0)} KD',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: _sp(context, 15),
                    color: AppColors.foreground,
                  ),
                ),
                SizedBox(height: _rh(context, 2, min: 1)),
                Text(
                  date,
                  style: TextStyle(
                    fontSize: _sp(context, 12),
                    color: AppColors.gray500,
                  ),
                ),
              ],
            ),
          ),

          // Status badge + method
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: _rw(context, 12, min: 8),
                  vertical: _rh(context, 5, min: 3),
                ),
                decoration: BoxDecoration(
                  color: statusBg,
                  borderRadius: BorderRadius.circular(
                    _rw(context, 20, min: 14),
                  ),
                ),
                child: Text(
                  payment.status.label,
                  style: TextStyle(
                    color: statusFg,
                    fontWeight: FontWeight.w600,
                    fontSize: _sp(context, 12),
                  ),
                ),
              ),
              SizedBox(height: _rh(context, 4, min: 2)),
              Text(
                payment.method.label,
                style: TextStyle(
                  fontSize: _sp(context, 11),
                  color: AppColors.gray500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
