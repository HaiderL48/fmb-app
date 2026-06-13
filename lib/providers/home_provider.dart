import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import '../apis/api_manager.dart' show ApiException, ApiManager;
import '../models/menu_model.dart';
import '../models/mumin_due_model.dart';
import '../models/package_model.dart';
import '../models/payment_model.dart';
import '../models/thali_pause_model.dart';
import '../models/user_model.dart';

class HomeProvider with ChangeNotifier {
  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  /// When [PaymentTab] and [HomeTab] both call [loadHomeData] in the same frame,
  /// the second call must await this future — not return early — or the dashboard
  /// can stay empty and payment flows miss [progressMisriYear].
  Future<void>? _loadHomeDataInFlight;

  PackageModel? _userPackage;
  PackageModel? get userPackage => _userPackage;

  double _totalPaidKd = 0;
  double get totalPaidKd => _totalPaidKd;
  double _progressTotalKd = 0;
  double _progressPaidKd = 0;
  double _progressRemainingKd = 0;
  int? _progressMisriYear;
  double get progressTotalKd => _progressTotalKd;
  double get progressPaidKd => _progressPaidKd;
  double get progressRemainingKd => _progressRemainingKd;
  int? get progressMisriYear => _progressMisriYear;

  List<PaymentModel> _recentPayments = [];
  List<PaymentModel> get recentPayments => _recentPayments;

  List<MenuModel> _weeklyMenu = [];
  List<MenuModel> get weeklyMenu => _weeklyMenu;

  int _selectedMenuIndex = 0;
  int get selectedMenuIndex => _selectedMenuIndex;

  MenuModel? get selectedMenu =>
      _weeklyMenu.isNotEmpty ? _weeklyMenu[_selectedMenuIndex] : null;

  // ─── Feedback (one submit per menu day; server enforces + we cache menu ids) ─
  int _feedbackRating = 0;
  int get feedbackRating => _feedbackRating;

  final TextEditingController feedbackController = TextEditingController();
  final Set<String> _feedbackMenuIds = <String>{};

  /// True if the user already submitted feedback for this menu (same calendar day / menu row).
  bool hasFeedbackForMenu(MenuModel menu) => _feedbackMenuIds.contains(menu.id);

  List<ThaliPauseModel> _myThaliPauses = [];
  List<ThaliPauseModel> get myThaliPauses =>
      List<ThaliPauseModel>.unmodifiable(_myThaliPauses);

  bool _thaliPauseBusy = false;
  bool get thaliPauseBusy => _thaliPauseBusy;

  // ─── Menu item exclusions (subscriber; max 2 per day; day-before rule on API) ─
  String _sessionToken = '';
  List<String> _excludedMenuItems = [];
  bool _menuExclusionsLoading = false;
  bool _menuExclusionsSaving = false;

  List<String> get excludedMenuItems =>
      List<String>.unmodifiable(_excludedMenuItems);
  bool get menuExclusionsLoading => _menuExclusionsLoading;
  bool get menuExclusionsSaving => _menuExclusionsSaving;

  /// Same rule as Thali pause: changes only allowed before the menu **calendar day**.
  static bool canEditMenuExclusionsForDate(DateTime menuDate) {
    final d = DateTime(menuDate.year, menuDate.month, menuDate.day);
    final today = DateTime.now();
    final t = DateTime(today.year, today.month, today.day);
    return d.isAfter(t);
  }

  /// Calendar date only (local).
  static DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

  /// Users can only change/cancel a pause *before* its start date.
  static bool canModifyPause(ThaliPauseModel pause) {
    final today = _day(DateTime.now());
    return _day(pause.startDate).isAfter(today);
  }

  /// Currently paused today, or the next scheduled pause, if any.
  ThaliPauseModel? get highlightedThaliPause {
    final today = _day(DateTime.now());
    ThaliPauseModel? activeNow;
    ThaliPauseModel? upcoming;
    for (final p in _myThaliPauses) {
      if (!p.isActive) continue;
      final s = _day(p.startDate);
      final e = _day(p.endDate);
      if (e.isBefore(today)) continue;
      if (!s.isAfter(today) && !e.isBefore(today)) {
        activeNow = p;
        break;
      }
      if (s.isAfter(today)) {
        if (upcoming == null || s.isBefore(_day(upcoming.startDate))) {
          upcoming = p;
        }
      }
    }
    return activeNow ?? upcoming;
  }

  bool get hasActiveThaliPauseToday {
    final h = highlightedThaliPause;
    if (h == null || !h.isActive) return false;
    final today = _day(DateTime.now());
    final s = _day(h.startDate);
    final e = _day(h.endDate);
    return !s.isAfter(today) && !e.isBefore(today);
  }

  // ─── Load ─────────────────────────────────────────────────────────────────
  Future<void> loadHomeData(UserModel? user, {String token = ''}) async {
    final existing = _loadHomeDataInFlight;
    if (existing != null) {
      await existing;
      return;
    }
    final run = _loadHomeDataImpl(user, token: token);
    _loadHomeDataInFlight = run;
    try {
      await run;
    } finally {
      if (identical(_loadHomeDataInFlight, run)) {
        _loadHomeDataInFlight = null;
      }
    }
  }

  Future<void> _loadHomeDataImpl(UserModel? user, {String token = ''}) async {
    // Log token state for debugging
    /* debugPrint(
      '[HomeProvider] loadHomeData called — token empty: ${token.isEmpty} — userId: ${user?.id}',
    );*/

    _setLoading(true);
    _errorMessage = null;

    try {
      // ── Packages ──────────────────────────────────────────────────────────
      final packages = await ApiManager.getPackages(token: token);
      // debugPrint('[HomeProvider] Packages received: ${packages.length} items');
      if (user?.packageId != null) {
        PackageModel? match;
        for (final p in packages) {
          if (p.id == user!.packageId) {
            match = p;
            break;
          }
        }
        _userPackage = match ?? (packages.isNotEmpty ? packages.first : null);
      } else if (packages.isNotEmpty) {
        _userPackage = packages.first;
      } else {
        _userPackage = null;
      }
      /* debugPrint(
        '[HomeProvider] User package: ${_userPackage?.name ?? "none"}',
      );*/

      // ── Payments ──────────────────────────────────────────────────────────
      final receipts = await ApiManager.getPaymentReceipts(token: token);
      /* debugPrint(
        '[HomeProvider] Payment receipts received: ${receipts.length} items',
      );*/
      final userReceipts =
          receipts.where((p) => p.userId == (user?.id ?? '')).toList()
            ..sort((a, b) => b.receivedAt.compareTo(a.receivedAt));
      _recentPayments = userReceipts;
      _totalPaidKd = userReceipts
          .where((p) => p.status == PaymentStatus.completed)
          .fold(0, (sum, p) => sum + p.amountKd);
      /* debugPrint(
        '[HomeProvider] User payments: ${userReceipts.length} items, total paid: $_totalPaidKd KD',
      );*/

      // ── Payment progress: prefer external Mumin Due (Takhmin + Due), else
      //    fall back to the internal takhmin history. ──────────────────────────
      try {
        final due = await ApiManager.getMuminDueMe(token: token);
        if (due != null && due.hasDue) {
          _applyMuminDue(due);
        } else {
          await _loadTakhminProgressFallback(token);
        }
      } catch (_) {
        // debugPrint('[HomeProvider] Mumin Due skipped — using takhmin history');
        await _loadTakhminProgressFallback(token);
      }

      // ── Weekly menus ──────────────────────────────────────────────────────
      final now = DateTime.now();
      final from = _fmt(now);
      final to = _fmt(now.add(const Duration(days: 6)));
      final menus = await ApiManager.getMenus(token: token, from: from, to: to);
      // Only published menus can use menu-exclusions (API rejects drafts with MENU_NOT_FOUND).
      _weeklyMenu = menus.where((m) => m.isPublished).toList();
      /* debugPrint(
        '[HomeProvider] Menus received: ${_weeklyMenu.length} items (from: $from, to: $to)',
      );*/
      _selectedMenuIndex = 0;
      await _loadFeedbackMenuIds(token);
      await _loadThaliPauses(token);
      _sessionToken = token;
      await _loadMenuExclusionsForSelectedMenu();
    } on ApiException catch (e) {
      _errorMessage = e.message;
      _clearData();
    } on SocketException {
      _errorMessage = 'No internet connection.';
      _clearData();
    } on TimeoutException {
      _errorMessage = 'Request timed out. Please try again.';
      _clearData();
    } catch (_) {
      _errorMessage = 'Something went wrong. Please try again.';
      _clearData();
    }

    _setLoading(false);
  }

  void _clearData() {
    _userPackage = null;
    _recentPayments = [];
    _totalPaidKd = 0;
    _progressTotalKd = 0;
    _progressPaidKd = 0;
    _progressRemainingKd = 0;
    _progressMisriYear = null;
    _weeklyMenu = [];
    _selectedMenuIndex = 0;
    _feedbackMenuIds.clear();
    _myThaliPauses = [];
    _sessionToken = '';
    _excludedMenuItems = [];
    _menuExclusionsLoading = false;
    _menuExclusionsSaving = false;
  }

  Future<void> _loadThaliPauses(String token) async {
    if (token.isEmpty) {
      _myThaliPauses = [];
      return;
    }
    try {
      _myThaliPauses = await ApiManager.getMyThaliPauses(token: token);
      // debugPrint('[HomeProvider] Thali pauses: ${_myThaliPauses.length}');
    } catch (_) {
      // debugPrint('[HomeProvider] Thali pauses skipped: $e');
      _myThaliPauses = [];
    }
  }

  Future<void> scheduleThaliPause({
    required String token,
    required DateTime start,
    required DateTime end,
    String? reason,
  }) async {
    if (token.isEmpty) return;
    final today = _day(DateTime.now());
    if (!_day(start).isAfter(today)) {
      throw const ApiException(
        statusCode: 400,
        code: 'PAUSE_TOO_LATE',
        message:
            'You can only schedule a Thali pause before the start date. Please choose a start date after today.',
      );
    }
    String ymd(DateTime d) =>
        '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    _thaliPauseBusy = true;
    notifyListeners();
    try {
      await ApiManager.createMyThaliPause(
        token: token,
        startDateYmd: ymd(_day(start)),
        endDateYmd: ymd(_day(end)),
        reason: reason,
      );
      await _loadThaliPauses(token);
    } finally {
      _thaliPauseBusy = false;
      notifyListeners();
    }
  }

  Future<void> cancelHighlightedThaliPause({required String token}) async {
    final id = highlightedThaliPause?.id;
    final pause = highlightedThaliPause;
    if (token.isEmpty || id == null || pause == null) return;
    if (!canModifyPause(pause)) {
      throw const ApiException(
        statusCode: 400,
        code: 'PAUSE_TOO_LATE',
        message:
            'You can only cancel a Thali pause before its start date. Since the start date is today (or in the past), it cannot be cancelled.',
      );
    }
    _thaliPauseBusy = true;
    notifyListeners();
    try {
      await ApiManager.patchMyThaliPause(
        token: token,
        pauseId: id,
        isActive: false,
      );
      await _loadThaliPauses(token);
    } finally {
      _thaliPauseBusy = false;
      notifyListeners();
    }
  }

  Future<void> _loadFeedbackMenuIds(String token) async {
    if (token.isEmpty) return;
    try {
      final body = await ApiManager.getFeedback(
        token: token,
        page: 1,
        limit: 200,
      );
      final data = body['data'];
      if (data is! List) return;
      _feedbackMenuIds.clear();
      for (final item in data) {
        if (item is Map<String, dynamic>) {
          final mid = item['menuId'] as String?;
          if (mid != null && mid.isNotEmpty) {
            _feedbackMenuIds.add(mid);
          }
        }
      }
      /* debugPrint(
        '[HomeProvider] Feedback history — menuIds with feedback: ${_feedbackMenuIds.length}',
      );*/
    } catch (_) {
      // debugPrint('[HomeProvider] Could not load feedback history: $e');
    }
  }

  /// Loads internal takhmin history and applies it to the progress card.
  /// Used as a fallback when the external Mumin Due lookup is unavailable.
  Future<void> _loadTakhminProgressFallback(String token) async {
    try {
      final takhminRows = await ApiManager.getMyTakhminHistory(token: token);
      _applyTakhminProgress(takhminRows);
    } catch (_) {
      _applyTakhminProgress(const []);
    }
  }

  /// Drives the Home payment-progress card from the external Mumin Due record:
  /// Takhmin = takhmeen, Remaining = due, Paid = takhmeen - due (clamped).
  void _applyMuminDue(MuminDueModel due) {
    _progressMisriYear = due.misriYear;
    final total = due.takhmeenKd ?? 0;
    final remaining = due.dueKd ?? 0;
    _progressTotalKd = total < 0 ? 0 : total;
    _progressRemainingKd = remaining < 0 ? 0 : remaining;
    var paid = _progressTotalKd - _progressRemainingKd;
    if (paid < 0) paid = 0;
    if (paid > _progressTotalKd) paid = _progressTotalKd;
    _progressPaidKd = paid;
  }

  void _applyTakhminProgress(List<Map<String, dynamic>> rows) {
    if (rows.isEmpty) {
      _progressTotalKd = 0;
      _progressPaidKd = _totalPaidKd;
      _progressRemainingKd = 0;
      _progressMisriYear = null;
      return;
    }

    int misriYearOf(Map<String, dynamic> m) =>
        _rowInt(m, const ['misriYear', 'misri_year', 'year']) ?? 0;

    rows.sort((a, b) => misriYearOf(b).compareTo(misriYearOf(a)));
    final latest = _normalizeTakhminRow(rows.first);

    _progressMisriYear = _rowInt(latest, const [
      'misriYear',
      'misri_year',
      'year',
    ]);
    _progressTotalKd =
        _rowDouble(latest, const [
          'amountKd',
          'amount_kd',
          'amount',
          'takhminAmountKd',
          'takhmin_amount_kd',
          'takhminAmount',
          'takhmin_amount',
        ]) ??
        0;
    _progressPaidKd =
        _rowDouble(latest, const [
          'totalPaidKd',
          'total_paid_kd',
          'paidKd',
          'paid_kd',
          'paidAmountKd',
          'paid_amount_kd',
          'totalPaid',
          'total_paid',
        ]) ??
        (_progressTotalKd -
            (_rowDouble(latest, const ['remainingKd', 'remaining_kd']) ??
                _progressTotalKd));
    _progressRemainingKd =
        _rowDouble(latest, const [
          'remainingKd',
          'remaining_kd',
          'remainingAmountKd',
          'remaining_amount_kd',
          'balanceKd',
          'balance_kd',
          'dueKd',
          'due_kd',
        ]) ??
        (_progressTotalKd - _progressPaidKd);
    if (_progressPaidKd < 0) _progressPaidKd = 0;
    if (_progressPaidKd > _progressTotalKd) _progressPaidKd = _progressTotalKd;
    if (_progressRemainingKd < 0) _progressRemainingKd = 0;
  }

  /// Merges nested `appUser` / `app_user` maps so home progress reads the same fields as flat DTOs.
  Map<String, dynamic> _normalizeTakhminRow(Map<String, dynamic> raw) {
    final merged = Map<String, dynamic>.from(raw);
    final nested = raw['appUser'] ?? raw['app_user'];
    if (nested is Map) {
      for (final e in nested.entries) {
        merged.putIfAbsent(e.key.toString(), () => e.value);
      }
    }
    return merged;
  }

  double? _rowDouble(Map<String, dynamic> row, List<String> keys) {
    for (final k in keys) {
      final d = _asDouble(row[k]);
      if (d != null) return d;
    }
    return null;
  }

  int? _rowInt(Map<String, dynamic> row, List<String> keys) {
    for (final k in keys) {
      final v = row[k];
      if (v is num) return v.toInt();
      if (v is String) return int.tryParse(v);
    }
    return null;
  }

  double? _asDouble(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  String _fmt(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> _loadMenuExclusionsForSelectedMenu() async {
    final menu = selectedMenu;
    if (menu == null || _sessionToken.isEmpty) {
      _excludedMenuItems = [];
      _menuExclusionsLoading = false;
      notifyListeners();
      return;
    }
    if (!menu.isPublished) {
      _excludedMenuItems = [];
      _menuExclusionsLoading = false;
      notifyListeners();
      return;
    }
    _menuExclusionsLoading = true;
    notifyListeners();
    try {
      _excludedMenuItems = await ApiManager.getMyMenuExclusions(
        token: _sessionToken,
        menuDateYmd: _fmt(_day(menu.menuDate)),
      );
    } catch (e, st) {
      debugPrint('══ FMB HomeProvider._loadMenuExclusionsForSelectedMenu ══');
      debugPrint('$e');
      debugPrint('$st');
      debugPrint('════════════════════════════════════════');
      _excludedMenuItems = [];
    } finally {
      _menuExclusionsLoading = false;
      notifyListeners();
    }
  }

  /// Replaces exclusions for [menu]'s date (max 2 names; each must appear on the menu).
  Future<void> saveMenuItemExclusions({
    required String token,
    required MenuModel menu,
    required List<String> items,
  }) async {
    if (token.isEmpty) return;
    if (!menu.isPublished) {
      throw const ApiException(
        statusCode: 404,
        code: 'MENU_NOT_FOUND',
        message:
            'This menu day is not published yet. Exclusions are only available for published menus.',
      );
    }
    if (!canEditMenuExclusionsForDate(menu.menuDate)) {
      throw const ApiException(
        statusCode: 400,
        code: 'EXCLUSIONS_CLOSED',
        message:
            'You can only change dish exclusions before that menu day (day-before rule).',
      );
    }
    final deduped = <String>[];
    for (final raw in items) {
      final name = raw.trim();
      if (name.isEmpty) continue;
      if (!menu.items.contains(name)) {
        throw ApiException(
          statusCode: 400,
          code: 'INVALID_MENU_ITEM',
          message: '"$name" is not on this day\'s menu.',
        );
      }
      if (!deduped.contains(name)) deduped.add(name);
    }
    if (deduped.length > 2) {
      throw const ApiException(
        statusCode: 400,
        code: 'EXCLUSION_LIMIT',
        message: 'You can exclude at most 2 dishes per day.',
      );
    }
    _menuExclusionsSaving = true;
    notifyListeners();
    try {
      final saved = await ApiManager.putMyMenuExclusions(
        token: token,
        menuDateYmd: _fmt(_day(menu.menuDate)),
        items: deduped,
      );
      _excludedMenuItems = saved;
    } catch (e, st) {
      debugPrint('══ FMB HomeProvider.saveMenuItemExclusions ══');
      debugPrint('menuDate=${_fmt(_day(menu.menuDate))} items=$deduped');
      debugPrint('$e');
      debugPrint('$st');
      debugPrint('════════════════════════════════════════');
      rethrow;
    } finally {
      _menuExclusionsSaving = false;
      notifyListeners();
    }
  }

  Future<void> toggleMenuItemExclusion({
    required String token,
    required MenuModel menu,
    required String itemName,
  }) async {
    if (token.isEmpty) return;
    final next = List<String>.from(_excludedMenuItems);
    final already = next.contains(itemName);
    if (already) {
      next.remove(itemName);
    } else {
      if (next.length >= 2) {
        throw const ApiException(
          statusCode: 400,
          code: 'EXCLUSION_LIMIT',
          message: 'You can exclude at most 2 dishes per day.',
        );
      }
      next.add(itemName);
    }
    await saveMenuItemExclusions(token: token, menu: menu, items: next);
  }

  // ─── Menu tab ─────────────────────────────────────────────────────────────
  void selectMenuDay(int index) {
    _selectedMenuIndex = index;
    _feedbackRating = 0;
    feedbackController.clear();
    notifyListeners();
    if (_sessionToken.isNotEmpty) {
      unawaited(_loadMenuExclusionsForSelectedMenu());
    }
  }

  // ─── Feedback ─────────────────────────────────────────────────────────────
  void setRating(int rating) {
    _feedbackRating = rating;
    notifyListeners();
  }

  Future<void> submitFeedback({
    required String token,
    required MenuModel menu,
  }) async {
    if (_feedbackRating == 0) return;
    if (token.isEmpty) return;
    if (_feedbackMenuIds.contains(menu.id)) return;

    _setLoading(true);
    try {
      await ApiManager.submitFeedback(
        token: token,
        menuId: menu.id,
        menuDate: _fmt(menu.menuDate),
        rating: _feedbackRating,
        comment: feedbackController.text.trim(),
      );
      _feedbackMenuIds.add(menu.id);
      _feedbackRating = 0;
      feedbackController.clear();
      _setLoading(false);
      notifyListeners();
    } on ApiException {
      _setLoading(false);
      notifyListeners();
      rethrow;
    } catch (_) {
      _setLoading(false);
      notifyListeners();
    }
  }

  // ─── Helpers ──────────────────────────────────────────────────────────────
  double get remainingKd => _progressRemainingKd;

  double get paymentProgressPercent {
    final total = _progressTotalKd;
    if (total == 0) return 0;
    return (_progressPaidKd / total).clamp(0.0, 1.0);
  }

  void _setLoading(bool v) {
    _isLoading = v;
    notifyListeners();
  }

  @override
  void dispose() {
    feedbackController.dispose();
    super.dispose();
  }
}
