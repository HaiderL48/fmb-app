import 'package:flutter/material.dart';

import '../constants/colors.dart';

/// Consistent **floating** snackbars: success (green), error (red), warning (amber).
final class AppSnackBar {
  AppSnackBar._();

  static const Duration _duration = Duration(seconds: 4);
  static const double _radius = 10;

  static void _present(
    BuildContext context,
    String message, {
    required Color backgroundColor,
    required Color contentColor,
    Duration? duration,
  }) {
    if (!context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: TextStyle(
            color: contentColor,
            fontWeight: FontWeight.w500,
            height: 1.35,
          ),
        ),
        behavior: SnackBarBehavior.floating,
        backgroundColor: backgroundColor,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 88),
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(_radius),
        ),
        duration: duration ?? _duration,
      ),
    );
  }

  static void success(BuildContext context, String message, {Duration? duration}) {
    _present(
      context,
      message,
      backgroundColor: AppColors.fmbButtonGreen,
      contentColor: Colors.white,
      duration: duration,
    );
  }

  static void error(BuildContext context, String message, {Duration? duration}) {
    _present(
      context,
      message,
      backgroundColor: AppColors.destructive,
      contentColor: AppColors.destructiveForeground,
      duration: duration,
    );
  }

  /// Non-blocking notices (policy, “contact admin”, limits).
  static void warning(BuildContext context, String message, {Duration? duration}) {
    _present(
      context,
      message,
      backgroundColor: AppColors.warningBackground,
      contentColor: AppColors.warningText,
      duration: duration,
    );
  }
}
