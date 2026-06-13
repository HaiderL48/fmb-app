import 'package:flutter/material.dart';

import '../apis/api_manager.dart' show ApiException;
import '../constants/colors.dart';
import '../constants/styles.dart';
import '../models/menu_model.dart';
import '../providers/home_provider.dart';
import 'app_button.dart';

double _rw(
  BuildContext context,
  double value, {
  double min = 0,
  double max = double.infinity,
}) =>
    (value * MediaQuery.sizeOf(context).width / 390).clamp(min, max);

double _rh(
  BuildContext context,
  double value, {
  double min = 0,
  double max = double.infinity,
}) =>
    (value * MediaQuery.sizeOf(context).height / 844).clamp(min, max);

double _sp(BuildContext context, double size) =>
    (size * MediaQuery.textScalerOf(context).scale(1)).clamp(
      size * 0.8,
      size * 1.2,
    );

/// Rate-this-menu UI (same behaviour as the former Home tab block).
class MenuFeedbackSection extends StatelessWidget {
  const MenuFeedbackSection({
    super.key,
    required this.provider,
    required this.menu,
    required this.token,
  });

  final HomeProvider provider;
  final MenuModel menu;
  final String token;

  @override
  Widget build(BuildContext context) {
    if (provider.hasFeedbackForMenu(menu)) {
      return Container(
        padding: EdgeInsets.all(_rw(context, 12, min: 10)),
        decoration: BoxDecoration(
          color: AppColors.successBackground,
          borderRadius: AppRadius.mdAll,
          border: Border.all(color: AppColors.successBorder),
        ),
        child: Row(
          children: [
            Icon(
              Icons.check_circle,
              color: AppColors.successText,
              size: _rw(context, 18, min: 14),
            ),
            SizedBox(width: _rw(context, 8, min: 6)),
            Flexible(
              child: Text(
                'Feedback submitted for this menu day. Thank you!',
                style: TextStyle(
                  color: AppColors.successText,
                  fontSize: _sp(context, 13),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Rate This Menu',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: _sp(context, 14),
            color: AppColors.foreground,
          ),
        ),
        SizedBox(height: _rh(context, 8, min: 6)),
        Row(
          children: List.generate(5, (i) {
            final filled = i < provider.feedbackRating;
            return GestureDetector(
              onTap: () => provider.setRating(i + 1),
              child: Padding(
                padding: EdgeInsets.only(right: _rw(context, 6, min: 4)),
                child: Icon(
                  filled ? Icons.star_rounded : Icons.star_outline_rounded,
                  color: filled ? AppColors.fmbAccent : AppColors.gray400,
                  size: _rw(context, 30, min: 24, max: 36),
                ),
              ),
            );
          }),
        ),
        SizedBox(height: _rh(context, 12, min: 8)),
        Container(
          decoration: BoxDecoration(
            color: AppColors.inputBackground,
            borderRadius: AppRadius.mdAll,
            border: Border.all(color: AppColors.border),
          ),
          child: TextField(
            controller: provider.feedbackController,
            maxLines: 3,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => FocusManager.instance.primaryFocus?.unfocus(),
            style: TextStyle(
              fontSize: _sp(context, 14),
              color: AppColors.foreground,
            ),
            decoration: InputDecoration(
              hintText: 'Share your feedback...',
              hintStyle: TextStyle(
                color: AppColors.gray400,
                fontSize: _sp(context, 14),
              ),
              border: InputBorder.none,
              contentPadding: EdgeInsets.all(_rw(context, 12, min: 10)),
            ),
          ),
        ),
        SizedBox(height: _rh(context, 12, min: 8)),
        AppButton(
          label: 'Submit Feedback',
          isLoading: provider.isLoading,
          enabled: provider.feedbackRating > 0,
          onTap: () async {
            try {
              await provider.submitFeedback(token: token, menu: menu);
            } on ApiException catch (e) {
              if (!context.mounted) return;
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(SnackBar(content: Text(e.message)));
            }
          },
        ),
      ],
    );
  }
}
