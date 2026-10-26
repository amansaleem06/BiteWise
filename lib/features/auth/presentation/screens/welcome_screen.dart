import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/routes.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/errors/error_text.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_snackbar.dart';
import '../providers/auth_providers.dart';
import '../widgets/brand_mark.dart';
import '../widgets/terms_acceptance.dart';

/// Entry screen with a provider-first sign-in choice and animated backdrop.
class WelcomeScreen extends ConsumerWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final session = ref.watch(authStateProvider);
    final authState = ref.watch(authControllerProvider);

    ref.listen(authControllerProvider, (_, next) {
      if (next.hasError && !next.isLoading) {
        AppSnackbar.error(context, userMessageFrom(next.error));
      }
    });

    // Wait for Firebase's persisted session/profile lookup before presenting
    // sign-in actions, so startup cannot flash a false signed-out state.
    if (session.isLoading) {
      return Theme(
        data: AppTheme.dark,
        child: const Scaffold(
          body: Stack(
            fit: StackFit.expand,
            children: [
              _AnimatedAuthBackdrop(),
              Center(child: CircularProgressIndicator()),
            ],
          ),
        ),
      );
    }

    return Theme(
      data: AppTheme.dark,
      child: Scaffold(
        body: Stack(
          fit: StackFit.expand,
          children: [
            const _AnimatedAuthBackdrop(),
            SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) => SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg,
                    vertical: AppSpacing.md,
                  ),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: math.max(
                        0.0,
                        constraints.maxHeight - AppSpacing.md * 2,
                      ),
                    ),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 440),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const SizedBox(height: AppSpacing.xl),
                            const BrandMark(size: 76),
                            const SizedBox(height: AppSpacing.xs),
                            Text(
                              AppStrings.tagline.toUpperCase(),
                              textAlign: TextAlign.center,
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: AppColors.accentLight,
                                letterSpacing: 2.2,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.xxl),
                            Text(
                              'Sign up or log in to TasteWise',
                              textAlign: TextAlign.center,
                              style: theme.textTheme.headlineLarge?.copyWith(
                                height: 1.12,
                                color: AppColors.accent,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            Text(
                              AppStrings.welcomeSubtitle,
                              textAlign: TextAlign.center,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: AppColors.textSecondaryDark,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.xl),
                            if (!kIsWeb &&
                                defaultTargetPlatform ==
                                    TargetPlatform.iOS) ...[
                              _ProviderButton(
                                label: AppStrings.continueWithApple,
                                icon: const Icon(Icons.apple_rounded, size: 24),
                                isLoading: authState.isLoading,
                                onPressed: () => ref
                                    .read(authControllerProvider.notifier)
                                    .signInWithApple(),
                              ),
                              const SizedBox(height: AppSpacing.sm),
                            ],
                            _ProviderButton(
                              label: AppStrings.continueWithGoogle,
                              icon: const Icon(
                                Icons.g_mobiledata_rounded,
                                size: 28,
                              ),
                              isLoading: authState.isLoading,
                              onPressed: () => ref
                                  .read(authControllerProvider.notifier)
                                  .signInWithGoogle(),
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            AppButton(
                              label: 'Continue with email',
                              icon: const Icon(
                                Icons.email_outlined,
                                size: 20,
                              ),
                              onPressed: () => context.push(Routes.signIn),
                            ),
                            const SizedBox(height: AppSpacing.xl),
                            const LegalConsentNotice(),
                            const SizedBox(height: AppSpacing.md),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProviderButton extends StatelessWidget {
  const _ProviderButton({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.isLoading = false,
  });

  final String label;
  final Widget icon;
  final VoidCallback onPressed;
  final bool isLoading;

  @override
  Widget build(BuildContext context) => OutlinedButton(
        onPressed: isLoading ? null : onPressed,
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(58),
          foregroundColor: AppColors.charcoal,
          backgroundColor: AppColors.surfaceLight,
          side: BorderSide(color: Colors.white.withValues(alpha: 0.78)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.pill),
          ),
          textStyle: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: AppColors.charcoal,
                fontWeight: FontWeight.w700,
              ),
        ),
        child: isLoading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2.5),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  icon,
                  const SizedBox(width: AppSpacing.sm),
                  Text(label)
                ],
              ),
      );
}

class _AnimatedAuthBackdrop extends StatefulWidget {
  const _AnimatedAuthBackdrop();

  @override
  State<_AnimatedAuthBackdrop> createState() => _AnimatedAuthBackdropState();
}

class _AnimatedAuthBackdropState extends State<_AnimatedAuthBackdrop>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 24),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) {
      return const CustomPaint(painter: _AuthBackdropPainter(0));
    }
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) => CustomPaint(
          painter: _AuthBackdropPainter(_controller.value),
        ),
      ),
    );
  }
}

class _AuthBackdropPainter extends CustomPainter {
  const _AuthBackdropPainter(this.progress);

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final bounds = Offset.zero & size;
    canvas.drawRect(
      bounds,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF170909), Color(0xFF3A0C10), Color(0xFF110808)],
          stops: [0, 0.48, 1],
        ).createShader(bounds),
    );

    final phase = progress * math.pi * 2;
    _drawGlow(
      canvas,
      Offset(
        size.width * (0.5 + 0.12 * math.sin(phase)),
        size.height * (0.24 + 0.045 * math.cos(phase)),
      ),
      size.width * 0.82,
      const Color(0xFF8B2630),
    );
    _drawGlow(
      canvas,
      Offset(
        size.width * (0.06 + 0.08 * math.cos(phase)),
        size.height * (0.78 + 0.04 * math.sin(phase)),
      ),
      size.width * 0.72,
      AppColors.accent,
    );
    _drawGlow(
      canvas,
      Offset(
        size.width * (0.94 + 0.07 * math.sin(phase)),
        size.height * (0.68 + 0.06 * math.cos(phase)),
      ),
      size.width * 0.75,
      const Color(0xFF6B1B22),
    );

    // Fine plate-rim arcs give the glow a quiet culinary texture.
    final center = Offset(size.width / 2, size.height * 0.23);
    for (var i = 0; i < 3; i++) {
      final radius = size.width * (0.34 + i * 0.09);
      final oval = Rect.fromCenter(
        center: center,
        width: radius * 2,
        height: radius * 1.15,
      );
      canvas.drawOval(
        oval,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = AppColors.cream.withValues(alpha: 0.035 - i * 0.007),
      );
    }
  }

  void _drawGlow(Canvas canvas, Offset center, double radius, Color color) {
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..shader = RadialGradient(
          colors: [color.withValues(alpha: 0.36), color.withValues(alpha: 0)],
        ).createShader(Rect.fromCircle(center: center, radius: radius)),
    );
  }

  @override
  bool shouldRepaint(_AuthBackdropPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
