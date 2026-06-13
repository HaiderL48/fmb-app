import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import '../apis/api_manager.dart';
import '../models/zabihat_model.dart';

class ZabihatProvider with ChangeNotifier {
  bool _isLoading = false;
  bool get isLoading => _isLoading;
  bool _hasLoadedOfferingsOnce = false;
  bool get hasLoadedOfferingsOnce => _hasLoadedOfferingsOnce;

  List<ZabihatModel> _offerings = [];
  List<ZabihatModel> get offerings => _offerings;

  final Map<String, int> _quantities = {};
  final Map<String, bool> _paidItems = {};

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  // ─── Load ─────────────────────────────────────────────────────────────────
  Future<void> loadOfferings({String token = ''}) async {
    if (_isLoading) return;
    _setLoading(true);
    _errorMessage = null;

    try {
      _offerings = await ApiManager.getZabihat(token: token);
      _offerings.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
      for (final z in _offerings) {
        _quantities.putIfAbsent(z.id, () => 1);
      }
      /* debugPrint(
        '[ZabihatProvider] Offerings received: ${_offerings.length} items',
      );*/
    } on ApiException catch (e) {
      // debugPrint('[ZabihatProvider] ApiException: ${e.message}');
      _errorMessage = e.message;
      _offerings = [];
    } on SocketException {
      // debugPrint('[ZabihatProvider] SocketException: $e');
      _errorMessage = 'No internet connection.';
      _offerings = [];
    } on TimeoutException {
      // debugPrint('[ZabihatProvider] TimeoutException: $e');
      _errorMessage = 'Request timed out.';
      _offerings = [];
    } catch (e) {
      //    debugPrint('[ZabihatProvider] Unknown error: $e');
      _errorMessage = 'Something went wrong. Please try again.';
      _offerings = [];
    }

    _hasLoadedOfferingsOnce = true;
    _setLoading(false);
  }

  // ─── Quantity helpers ─────────────────────────────────────────────────────
  int quantityFor(String id) => _quantities[id] ?? 1;

  void increment(String id, int maxAvailable) {
    final current = _quantities[id] ?? 1;
    if (current < maxAvailable) {
      _quantities[id] = current + 1;
      notifyListeners();
    }
  }

  void decrement(String id) {
    final current = _quantities[id] ?? 1;
    if (current > 1) {
      _quantities[id] = current - 1;
      notifyListeners();
    }
  }

  double totalFor(String id, double priceKd) => quantityFor(id) * priceKd;

  // ─── Pay Now ──────────────────────────────────────────────────────────────
  Future<void> payNow(
    String zabihatId,
    String userId, {
    required String token,
    required int misriYear,
    required double amountKd,
    String? notes,
  }) async {
    _setLoading(true);
    _errorMessage = null;

    try {
      await ApiManager.createPaymentReceipt(
        token: token,
        userId: userId,
        misriYear: misriYear,
        amountKd: amountKd,
        notes: notes,
      );
      _paidItems[zabihatId] = true;
    } on ApiException catch (e) {
      _errorMessage = e.message;
    } on SocketException {
      _errorMessage = 'No internet connection.';
    } on TimeoutException {
      _errorMessage = 'Request timed out.';
    } catch (e) {
      _errorMessage = 'Something went wrong. Please try again.';
    }

    _setLoading(false);
  }

  bool isPaid(String id) => _paidItems[id] ?? false;

  void _setLoading(bool v) {
    _isLoading = v;
    notifyListeners();
  }
}
