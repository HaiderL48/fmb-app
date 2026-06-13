import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import '../apis/api_manager.dart';
import '../models/package_model.dart';
import '../models/user_model.dart';

class PackagesProvider with ChangeNotifier {
  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _selectingPackageId;
  String? get selectingPackageId => _selectingPackageId;

  List<PackageModel> _packages = [];
  List<PackageModel> get packages => _packages;

  String? _currentPackageId;
  String? get currentPackageId => _currentPackageId;

  String? _selectedPackageId;
  String? get selectedPackageId => _selectedPackageId;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  bool _selectSuccess = false;
  bool get selectSuccess => _selectSuccess;

  // ─── Load ─────────────────────────────────────────────────────────────────
  Future<void> loadPackages(UserModel? user, {String token = ''}) async {
    if (_isLoading) return;
    _selectingPackageId = null;
    _setLoading(true);
    _errorMessage = null;
    _selectSuccess = false;

    try {
      _packages = await ApiManager.getPackages(token: token);
      _packages.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
      /* debugPrint(
        '[PackagesProvider] Packages received: ${_packages.length} items',
      );*/
      // debugPrint('[PackagesProvider] Packages received: ${_packages.length} items');
    } on ApiException catch (e) {
      // debugPrint('[PackagesProvider] ApiException: ${e.message}');
      _errorMessage = e.message;
      _packages = [];
    } on SocketException {
      _errorMessage = 'No internet connection.';
      _packages = [];
    } on TimeoutException {
      _errorMessage = 'Request timed out.';
      _packages = [];
    } catch (e) {
      // debugPrint('[PackagesProvider] Unknown error: $e');
      _errorMessage = 'Something went wrong. Please try again.';
      _packages = [];
    }

    _currentPackageId = user?.packageId;
    _selectedPackageId = user?.packageId;
    _setLoading(false);
  }

  // ─── Select package ───────────────────────────────────────────────────────
  Future<void> selectPackage(
    String packageId, {
    required String token,
    required String userId,
  }) async {
    if (_selectedPackageId == packageId) return;
    _selectingPackageId = packageId;
    _setLoading(true);
    _errorMessage = null;
    _selectSuccess = false;

    try {
      await ApiManager.updateUser(
        token: token,
        userId: userId,
        fields: {'packageId': packageId},
      );
      _selectedPackageId = packageId;
      _currentPackageId = packageId;
      _selectSuccess = true;
    } on ApiException catch (e) {
      _errorMessage = e.message;
    } on SocketException {
      _errorMessage = 'No internet connection.';
    } on TimeoutException {
      _errorMessage = 'Request timed out.';
    } catch (e) {
      _errorMessage = 'Something went wrong. Please try again.';
    }

    _selectingPackageId = null;
    _setLoading(false);
  }

  void clearSuccess() {
    _selectSuccess = false;
    notifyListeners();
  }

  void _setLoading(bool v) {
    _isLoading = v;
    notifyListeners();
  }
}
