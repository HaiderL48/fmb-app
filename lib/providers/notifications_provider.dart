import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../apis/api_manager.dart';
import '../models/notification_model.dart';

class NotificationsProvider with ChangeNotifier {
  static const _seenLatestNotificationIdKey = 'fmb_seen_latest_notification_id';

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  List<NotificationModel> _items = [];
  List<NotificationModel> get items => _items;
  final List<NotificationModel> _localPushItems = [];
  String _activeToken = '';
  String? _seenLatestNotificationId;
  bool _hasLoadedSeenState = false;

  bool get hasUnseenLatest {
    if (_items.isEmpty) return false;
    return _items.first.id != _seenLatestNotificationId;
  }

  /// Clears in-memory notifications when account/session changes.
  void clearForSessionChange() {
    _isLoading = false;
    _errorMessage = null;
    _items = [];
    _localPushItems.clear();
    _activeToken = '';
    _seenLatestNotificationId = null;
    _hasLoadedSeenState = false;
    SharedPreferences.getInstance().then((prefs) {
      prefs.remove(_seenLatestNotificationIdKey);
    });
    notifyListeners();
  }

  Future<void> _ensureSeenStateLoaded() async {
    if (_hasLoadedSeenState) return;
    final prefs = await SharedPreferences.getInstance();
    _seenLatestNotificationId = prefs.getString(_seenLatestNotificationIdKey);
    _hasLoadedSeenState = true;
  }

  Future<void> markLatestAsSeen() async {
    if (_items.isEmpty) return;
    final latestId = _items.first.id;
    if (_seenLatestNotificationId == latestId) return;
    _seenLatestNotificationId = latestId;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_seenLatestNotificationIdKey, latestId);
    notifyListeners();
  }

  void addFromPush({
    String? id,
    String? title,
    String? body,
    Map<String, dynamic> data = const {},
  }) {
    final resolvedTitle =
        (title ?? data['title']?.toString() ?? 'Notification').trim();
    final resolvedBody =
        (body ?? data['body']?.toString() ?? data['message']?.toString() ?? '')
            .trim();
    if (resolvedTitle.isEmpty && resolvedBody.isEmpty) return;

    final model = NotificationModel(
      id: (id == null || id.isEmpty)
          ? 'push_${DateTime.now().microsecondsSinceEpoch}'
          : id,
      title: resolvedTitle.isEmpty ? 'Notification' : resolvedTitle,
      body: resolvedBody,
      createdAt: DateTime.now(),
    );

    _localPushItems.removeWhere((e) => e.id == model.id);
    _localPushItems.insert(0, model);
    _items = _mergeWithLocalPush(_items);
    notifyListeners();
  }

  Future<void> load({required String token}) async {
    if (_isLoading) return;
    await _ensureSeenStateLoaded();
    if (token != _activeToken) {
      _activeToken = token;
      _items = [];
      _localPushItems.clear();
    }

    if (token.isEmpty) {
      _errorMessage = null;
      _items = [];
      notifyListeners();
      return;
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final rows = await ApiManager.getNotifications(token: token);
      final apiItems = rows.map(NotificationModel.fromJson).toList()
        ..sort((a, b) {
          final aTime = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
          final bTime = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
          return bTime.compareTo(aTime);
        });
      _items = _mergeWithLocalPush(apiItems);
    } on ApiException catch (e) {
      _errorMessage = e.message;
      _items = List<NotificationModel>.from(_localPushItems);
    } on SocketException {
      _errorMessage = 'No internet connection.';
      _items = List<NotificationModel>.from(_localPushItems);
    } on TimeoutException {
      _errorMessage = 'Request timed out.';
      _items = List<NotificationModel>.from(_localPushItems);
    } catch (_) {
      _errorMessage = 'Unable to load notifications.';
      _items = List<NotificationModel>.from(_localPushItems);
    }

    _isLoading = false;
    notifyListeners();
  }

  List<NotificationModel> _mergeWithLocalPush(List<NotificationModel> apiItems) {
    final merged = <NotificationModel>[..._localPushItems];
    final seenIds = merged.map((e) => e.id).toSet();
    for (final item in apiItems) {
      if (seenIds.contains(item.id)) continue;
      merged.add(item);
      seenIds.add(item.id);
    }
    merged.sort((a, b) {
      final aTime = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bTime = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      return bTime.compareTo(aTime);
    });
    return merged;
  }
}
