import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import '../apis/api_manager.dart';
import '../models/takhmin_history_model.dart';
import '../models/user_model.dart';

class ProfileProvider with ChangeNotifier {
  // ─── Controllers ──────────────────────────────────────────────────────────
  final TextEditingController fullNameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController contactController = TextEditingController();
  final TextEditingController addressController = TextEditingController();
  final TextEditingController currentPwController = TextEditingController();
  final TextEditingController newPwController = TextEditingController();
  final TextEditingController confirmPwController = TextEditingController();

  // ─── Password visibility ───────────────────────────────────────────────────
  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;

  bool get obscureCurrent => _obscureCurrent;
  bool get obscureNew => _obscureNew;
  bool get obscureConfirm => _obscureConfirm;

  void toggleCurrent() {
    _obscureCurrent = !_obscureCurrent;
    notifyListeners();
  }

  void toggleNew() {
    _obscureNew = !_obscureNew;
    notifyListeners();
  }

  void toggleConfirm() {
    _obscureConfirm = !_obscureConfirm;
    notifyListeners();
  }

  // ─── State ────────────────────────────────────────────────────────────────
  bool _isLoading = false;
  bool _isSaved = false;
  bool _isPasswordSaved = false;
  bool _isHistoryLoading = false;
  String? _errorMessage;
  String? _pwErrorMessage;
  String? _historyErrorMessage;
  List<TakhminHistoryModel> _takhminHistory = [];

  bool get isLoading => _isLoading;
  bool get isSaved => _isSaved;
  bool get isPasswordSaved => _isPasswordSaved;
  bool get isHistoryLoading => _isHistoryLoading;
  String? get errorMessage => _errorMessage;
  String? get pwErrorMessage => _pwErrorMessage;
  String? get historyErrorMessage => _historyErrorMessage;
  List<TakhminHistoryModel> get takhminHistory => _takhminHistory;

  // ─── Init ─────────────────────────────────────────────────────────────────
  void initFromUser(UserModel? user) {
    if (user == null) return;
    fullNameController.text = user.fullName;
    emailController.text = user.email;
    contactController.text = user.contactPhone;
    addressController.text = user.address;
  }

  // ─── Save personal info ───────────────────────────────────────────────────
  /// PATCH /users/:id
  Future<void> saveChanges({
    required String userId,
    required String token,
  }) async {
    _errorMessage = null;
    _isSaved = false;

    if (fullNameController.text.trim().isEmpty) {
      _errorMessage = 'Full name is required';
      notifyListeners();
      return;
    }
    if (emailController.text.trim().isEmpty) {
      _errorMessage = 'Email is required';
      notifyListeners();
      return;
    }

    _setLoading(true);

    try {
      await ApiManager.updateUser(
        token: token,
        userId: userId,
        fields: {
          'fullName': fullNameController.text.trim(),
          'email': emailController.text.trim(),
          'contactPhone': contactController.text.trim().isEmpty
              ? null
              : contactController.text.trim(),
          'address': addressController.text.trim().isEmpty
              ? null
              : addressController.text.trim(),
        },
      );
      _isSaved = true;
    } on ApiException catch (e) {
      _errorMessage = e.message;
    } on SocketException {
      _errorMessage = 'No internet connection.';
    } on TimeoutException {
      _errorMessage = 'Request timed out.';
    } catch (e) {
      _errorMessage = 'An unexpected error occurred.';
    }

    _setLoading(false);
  }

  void clearSaved() {
    _isSaved = false;
    notifyListeners();
  }

  // ─── Update password ──────────────────────────────────────────────────────
  /// PATCH /users/:id  { password }
  Future<void> updatePassword({
    required String userId,
    required String token,
  }) async {
    _pwErrorMessage = null;
    _isPasswordSaved = false;

    if (currentPwController.text.isEmpty) {
      _pwErrorMessage = 'Current password is required';
      notifyListeners();
      return;
    }
    if (newPwController.text.length < 8) {
      _pwErrorMessage = 'New password must be at least 8 characters';
      notifyListeners();
      return;
    }
    if (newPwController.text != confirmPwController.text) {
      _pwErrorMessage = 'Passwords do not match';
      notifyListeners();
      return;
    }

    _setLoading(true);

    try {
      await ApiManager.updateUserPassword(
        token: token,
        userId: userId,
        newPassword: newPwController.text,
      );
      currentPwController.clear();
      newPwController.clear();
      confirmPwController.clear();
      _isPasswordSaved = true;
    } on ApiException catch (e) {
      _pwErrorMessage = e.message;
    } on SocketException {
      _pwErrorMessage = 'No internet connection.';
    } on TimeoutException {
      _pwErrorMessage = 'Request timed out.';
    } catch (e) {
      _pwErrorMessage = 'An unexpected error occurred.';
    }

    _setLoading(false);
  }

  void clearPasswordSaved() {
    _isPasswordSaved = false;
    notifyListeners();
  }

  // ─── Takhmin history ───────────────────────────────────────────────────────
  Future<void> loadTakhminHistory({required String token}) async {
    _isHistoryLoading = true;
    _historyErrorMessage = null;
    notifyListeners();

    try {
      final rows = await ApiManager.getMyTakhminHistory(token: token);
      _takhminHistory = rows.map(TakhminHistoryModel.fromJson).toList()
        ..sort((a, b) => b.misriYear.compareTo(a.misriYear));
    } on ApiException catch (e) {
      _historyErrorMessage = e.message;
      _takhminHistory = [];
    } on SocketException {
      _historyErrorMessage = 'No internet connection.';
      _takhminHistory = [];
    } on TimeoutException {
      _historyErrorMessage = 'Request timed out.';
      _takhminHistory = [];
    } catch (_) {
      _historyErrorMessage = 'Unable to load history right now.';
      _takhminHistory = [];
    }

    _isHistoryLoading = false;
    notifyListeners();
  }

  void _setLoading(bool v) {
    _isLoading = v;
    notifyListeners();
  }

  @override
  void dispose() {
    fullNameController.dispose();
    emailController.dispose();
    contactController.dispose();
    addressController.dispose();
    currentPwController.dispose();
    newPwController.dispose();
    confirmPwController.dispose();
    super.dispose();
  }
}
