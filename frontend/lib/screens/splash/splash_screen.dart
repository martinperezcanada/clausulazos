import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/gavel_logo.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  // Drives the gavel animation only (about 1.6 s, inside the 3 s minimum splash time set in
  // `AuthProvider`); unrelated to the session check.
  late final AnimationController _controller = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1600))
    ..forward();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AuthProvider>().checkSession();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) => _SplashHero(t: _controller.value),
        ),
      ),
    );
  }
}

/// Eased 0..1 progress of `t` between `start` and `end` (clamped).
double _segment(double t, double start, double end,
        [Curve curve = Curves.linear]) =>
    curve.transform(((t - start) / (end - start)).clamp(0.0, 1.0));

/// Splash composition: ambient glow, gavel tile and name. `t` is the animation timeline (0..1 over
/// 1.6 s):
///
///   0.00 – 0.22  the tile fades/settles in, gavel held up
///   0.30 – 0.46  the gavel swings down (accelerating, `easeIn`)
///   0.46 – 0.62  impact: a short damped shake + tiny scale bump
///   0.46 – 0.80  a soft green ring spreads from the block and fades
///   0.40 – 0.70  "CLAUSULAZOS" fades in
///   after that   everything stays still
class _SplashHero extends StatelessWidget {
  const _SplashHero({required this.t});

  final double t;

  @override
  Widget build(BuildContext context) {
    final appear = _segment(t, 0.0, 0.22, Curves.easeOut);
    final swing = _segment(t, 0.30, 0.46, Curves.easeIn);
    final impact = _segment(t, 0.46, 0.62);
    final ring = _segment(t, 0.46, 0.80);
    final text = _segment(t, 0.40, 0.70, Curves.easeOut);

    // Gavel angle: raised (-40°) -> struck (0°).
    final angle = -0.70 * (1 - swing);
    // Damped vertical shake + small squash right after the hit.
    final damping = 1 - impact;
    final shake =
        impact > 0 ? 2.5 * math.sin(impact * math.pi * 5) * damping : 0.0;
    final bump =
        impact > 0 && impact < 1 ? 0.03 * math.sin(impact * math.pi) : 0.0;
    final scale = (0.94 + 0.06 * appear) - bump;

    // The ambient glow warms up a little at the moment of the decision.
    final glow = 0.10 + 0.07 * math.sin(_segment(t, 0.46, 0.85) * math.pi);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 300,
          height: 300,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Ambient glow behind the icon.
              Opacity(
                opacity: appear,
                child: Container(
                  width: 300,
                  height: 300,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        AppColors.primaryGreen.withValues(alpha: glow),
                        AppColors.primaryGreen.withValues(alpha: 0),
                      ],
                    ),
                  ),
                ),
              ),
              Opacity(
                opacity: appear,
                child: Transform.translate(
                  offset: Offset(0, shake),
                  child: Transform.scale(
                    scale: scale,
                    child: GavelLogo(size: 128, angle: angle, ring: ring),
                  ),
                ),
              ),
            ],
          ),
        ),
        Opacity(
          opacity: text,
          child: Transform.translate(
            offset: Offset(0, 8 * (1 - text)),
            child: Text(
              'CLAUSULAZOS',
              style: AppTextStyles.headline(
                      fontSize: 30, fontWeight: FontWeight.w700)
                  .copyWith(letterSpacing: 4),
            ),
          ),
        ),
      ],
    );
  }
}
