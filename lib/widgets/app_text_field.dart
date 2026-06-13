import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../constants/colors.dart';
import '../constants/styles.dart';

/// Reusable styled text field matching the FMB design system.
///
/// Supports both Material [IconData] and SVG asset paths for prefix/suffix icons.
/// Pass either [prefixIcon] (IconData) OR [prefixSvg] (asset path) — not both.
///
/// Usage:
/// ```dart
/// AppTextField(
///   controller: controller,
///   hintText: 'Enter your ITS Number',
///   prefixSvg: AppSvg.profile,
///   label: 'ITS Number',
///   errorText: provider.itsError,
/// )
/// ```
class AppTextField extends StatelessWidget {
  const AppTextField({
    super.key,
    required this.controller,
    required this.hintText,
    this.label,
    this.prefixIcon,
    this.prefixSvg,
    this.suffixIcon,
    this.suffixSvg,
    this.onSuffixTap,
    this.obscureText = false,
    this.keyboardType,
    this.errorText,
    this.onChanged,
    this.textInputAction,
    this.onSubmitted,
    this.enabled = true,
    this.autofocus = false,
  });

  final TextEditingController controller;
  final String hintText;
  final String? label;
  final IconData? prefixIcon;
  final String? prefixSvg; // SVG asset path
  final IconData? suffixIcon;
  final String? suffixSvg; // SVG asset path
  final VoidCallback? onSuffixTap;
  final bool obscureText;
  final TextInputType? keyboardType;
  final String? errorText;
  final ValueChanged<String>? onChanged;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;
  final bool enabled;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    final hasError = errorText != null && errorText!.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // ── Label ──────────────────────────────────────────────────────────
        if (label != null) ...[
          Text(
            label!,
            style: AppTextStyle.label.copyWith(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.foreground,
            ),
          ),
          const SizedBox(height: 6),
        ],

        // ── Input ──────────────────────────────────────────────────────────
        AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          decoration: BoxDecoration(
            color: AppColors.inputBackground,
            borderRadius: AppRadius.mdAll,
            border: Border.all(
              color: hasError ? AppColors.destructive : AppColors.border,
              width: hasError ? 1.5 : 1,
            ),
          ),
          child: TextField(
            controller: controller,
            obscureText: obscureText,
            keyboardType: keyboardType,
            textInputAction: textInputAction ?? TextInputAction.done,
            onSubmitted: (v) {
              onSubmitted?.call(v);
              FocusManager.instance.primaryFocus?.unfocus();
            },
            onChanged: onChanged,
            enabled: enabled,
            autofocus: autofocus,
            style: AppTextStyle.bodyBase.copyWith(
              color: AppColors.foreground,
              fontSize: 15,
            ),
            decoration: InputDecoration(
              hintText: hintText,
              hintStyle: AppTextStyle.bodyBase.copyWith(
                color: AppColors.gray400,
                fontSize: 15,
              ),
              prefixIcon: _buildPrefixIcon(),
              suffixIcon: _buildSuffixIcon(),
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              errorBorder: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.s3,
                vertical: AppSpacing.s3,
              ),
              isDense: true,
            ),
          ),
        ),

        // ── Error text ─────────────────────────────────────────────────────
        if (hasError) ...[
          const SizedBox(height: 4),
          Text(
            errorText!,
            style: AppTextStyle.bodyXs.copyWith(
              color: AppColors.destructive,
              fontSize: 12,
            ),
          ),
        ],
      ],
    );
  }

  // ── Icon builders ──────────────────────────────────────────────────────────

  Widget? _buildPrefixIcon() {
    if (prefixSvg != null) {
      return Padding(
        padding: const EdgeInsets.all(12),
        child: SvgPicture.asset(
          prefixSvg!,
          width: AppIconSize.md,
          height: AppIconSize.md,
          colorFilter: const ColorFilter.mode(
            AppColors.gray400,
            BlendMode.srcIn,
          ),
        ),
      );
    }
    if (prefixIcon != null) {
      return Icon(prefixIcon, size: AppIconSize.md, color: AppColors.gray400);
    }
    return null;
  }

  Widget? _buildSuffixIcon() {
    if (suffixSvg != null) {
      return GestureDetector(
        onTap: onSuffixTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: SvgPicture.asset(
            suffixSvg!,
            width: AppIconSize.md,
            height: AppIconSize.md,
            colorFilter: const ColorFilter.mode(
              AppColors.gray400,
              BlendMode.srcIn,
            ),
          ),
        ),
      );
    }
    if (suffixIcon != null) {
      return GestureDetector(
        onTap: onSuffixTap,
        child: Icon(suffixIcon, size: AppIconSize.md, color: AppColors.gray400),
      );
    }
    return null;
  }
}
