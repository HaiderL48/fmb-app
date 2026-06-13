import 'package:flutter/material.dart';
import '../constants/colors.dart';
import '../constants/styles.dart';

/// Primary FMB button — teal background, gold text.
///
/// Usage:
/// ```dart
/// AppButton(
///   label: 'Sign In',
///   onTap: () => provider.login(context, onSuccess: ...),
///   isLoading: provider.isLoading,
///   prefixIcon: Icons.login,
/// )
/// ```
class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    required this.onTap,
    this.isLoading = false,
    this.prefixIcon,
    this.backgroundColor,
    this.textColor,
    this.height = AppSpacing.s12,
    this.borderRadius,
    this.enabled = true,
  });

  final String label;
  final VoidCallback? onTap;
  final bool isLoading;
  final IconData? prefixIcon;
  final Color? backgroundColor;
  final Color? textColor;
  final double height;
  final BorderRadius? borderRadius;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final bg = backgroundColor ?? AppColors.fmbPrimary;
    final fg = textColor ?? AppColors.fmbAccent;
    final isOn = enabled && !isLoading;

    return SizedBox(
      width: double.infinity,
      height: height,
      child: Material(
        color: isOn ? bg : bg.withValues(alpha: 0.6),
        borderRadius: borderRadius ?? AppRadius.mdAll,
        child: InkWell(
          onTap: isOn ? onTap : null,
          borderRadius: borderRadius ?? AppRadius.mdAll,
          splashColor: AppColors.fmbPrimaryDark.withValues(alpha: 0.3),
          child: Center(
            child: isLoading
                ? SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      valueColor: AlwaysStoppedAnimation<Color>(fg),
                    ),
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (prefixIcon != null) ...[
                        Icon(prefixIcon, color: fg, size: AppIconSize.md),
                        const SizedBox(width: AppSpacing.s2),
                      ],
                      Text(
                        label,
                        style: AppTextStyle.button.copyWith(
                          color: fg,
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
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
