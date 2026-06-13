import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import '../../constants/colors.dart';
import '../../constants/styles.dart';
import '../../constants/images.dart';
import '../../constants/svg.dart';
import '../../providers/auth/login_provider.dart';
import '../../providers/auth/user_data_provider.dart';
import '../../providers/notifications_provider.dart';
import '../../widgets/app_text_field.dart';
import '../../widgets/app_button.dart';
import '../bottom/home_page.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => LoginProvider(),
      child: const _LoginBody(),
    );
  }
}

class _LoginBody extends StatelessWidget {
  const _LoginBody();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.fmbPrimary,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.s4,
              vertical: AppSpacing.s6,
            ),
            child: Column(
              children: [
                // ── App title above card ──────────────────────────────────
                Text(
                  'Food Package Subscription App',
                  style: AppTextStyle.bodySm.copyWith(
                    color: AppColors.fmbAccent.withValues(alpha: 0.85),
                    fontSize: 13,
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: AppSpacing.s4),

                // ── White card ────────────────────────────────────────────
                Container(
                  width: double.infinity,
                  constraints: const BoxConstraints(maxWidth: 420),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: AppShadow.xxl,
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.s6,
                    vertical: AppSpacing.s6,
                  ),
                  child: const _CardContent(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CardContent extends StatelessWidget {
  const _CardContent();

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<LoginProvider>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // ── Logo ─────────────────────────────────────────────────────────
        Image.asset(
          AppImages.logo,
          height: 80,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => const SizedBox(height: 80),
        ),
        const SizedBox(height: AppSpacing.s5),

        // ── Welcome heading ───────────────────────────────────────────────
        Text(
          'Welcome to FMB',
          style: AppTextStyle.h2.copyWith(
            fontWeight: FontWeight.w700,
            fontSize: 22,
            color: AppColors.foreground,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Food Package Subscription',
          style: AppTextStyle.muted.copyWith(fontSize: 14),
        ),
        const SizedBox(height: AppSpacing.s6),

        // ── ITS Number field ──────────────────────────────────────────────
        AppTextField(
          controller: provider.itsController,
          label: 'ITS Number',
          hintText: 'Enter your ITS Number',
          prefixSvg: AppSvg.profile,
          keyboardType: TextInputType.text,
          textInputAction: TextInputAction.next,
          errorText: provider.itsError,
          onChanged: (_) => provider.clearError(),
        ),
        const SizedBox(height: AppSpacing.s4),

        // ── Password field ────────────────────────────────────────────────
        AppTextField(
          controller: provider.passwordController,
          label: 'Password',
          hintText: 'Enter your password',
          prefixSvg: AppSvg.lock,
          obscureText: provider.obscurePassword,
          textInputAction: TextInputAction.done,
          errorText: provider.passwordError,
          suffixIcon: provider.obscurePassword
              ? Icons.visibility_off_outlined
              : Icons.visibility_outlined,
          onSuffixTap: provider.togglePasswordVisibility,
          onChanged: (_) => provider.clearError(),
          onSubmitted: (_) => _handleLogin(context, provider),
        ),
        const SizedBox(height: AppSpacing.s4),

        // ── Global error banner ───────────────────────────────────────────
        if (provider.errorMessage != null) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.s3,
              vertical: AppSpacing.s2,
            ),
            decoration: BoxDecoration(
              color: AppColors.errorBackground,
              borderRadius: AppRadius.mdAll,
              border: Border.all(color: AppColors.errorBorder),
            ),
            child: Text(
              provider.errorMessage!,
              style: AppTextStyle.bodyXs.copyWith(
                color: AppColors.errorText,
                fontSize: 13,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.s3),
        ],

        // ── Sign In button ────────────────────────────────────────────────
        AppButton(
          label: 'Sign In',
          prefixIcon: Icons.login_rounded,
          isLoading: provider.isLoading,
          onTap: () => _handleLogin(context, provider),
        ),
        const SizedBox(height: AppSpacing.s4),

        const SizedBox(height: AppSpacing.s4),

        // ── Forgot password ───────────────────────────────────────────────
        GestureDetector(
          onTap: () {
            // TODO: navigate to forgot password screen
          },
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SvgPicture.asset(
                AppSvg.key,
                width: 14,
                height: 14,
                colorFilter: const ColorFilter.mode(
                  AppColors.fmbPrimary,
                  BlendMode.srcIn,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                'Forgot Password?',
                style: AppTextStyle.bodySm.copyWith(
                  color: AppColors.fmbPrimary,
                  decoration: TextDecoration.underline,
                  decorationColor: AppColors.fmbPrimary,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _handleLogin(BuildContext context, LoginProvider provider) {
    // Capture UserDataProvider here — this context has access to MultiProvider
    final userDataProvider = Provider.of<UserDataProvider>(
      context,
      listen: false,
    );

    provider.login(
      onSuccess: (result) async {
        Provider.of<NotificationsProvider>(
          context,
          listen: false,
        ).clearForSessionChange();
        if (result.isAdmin) {
          // Session save triggers FCM topic subscribe for logged-in users.
          await userDataProvider.saveAdmin(
            token: result.accessToken,
            refreshToken: result.refreshToken,
          );
          if (!context.mounted) return;
          // TODO: navigate to AdminDashboard
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Admin login — dashboard coming soon.'),
              backgroundColor: AppColors.fmbPrimary,
            ),
          );
        } else {
          // Session save triggers FCM topic subscribe for logged-in users.
          await userDataProvider.saveUser(
            result.user,
            token: result.accessToken,
            refreshToken: result.refreshToken,
          );
          if (context.mounted) {
            await Provider.of<NotificationsProvider>(
              context,
              listen: false,
            ).load(token: result.accessToken);
          }
          if (!context.mounted) return;
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => HomePage(user: result.user)),
          );
        }
      },
    );
  }
}
