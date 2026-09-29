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
    with TickerProviderStateMixin {
  // Drives the gavel animation only (about 1.6 s, inside the 3 s minimum splash time set in
  // `AuthProvider`); unrelated to the session check.
  late final AnimationController _controller = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1600))
    ..forward();

  // The loading wave over "CLAUSULAZOS": loops for as long as the splash is on screen (e.g. while Render
  // wakes up), so the app visibly keeps working. Disposed with the splash; no timers.
  late final AnimationController _wave =
      AnimationController(vsync: this, duration: SplashWaveText.cycle)
        ..repeat();

  // Slow "breathing" of the glow behind the gavel while the splash waits: 2.5 s up, 2.5 s down (a 5 s
  // cycle), eased at both ends. Independent of the strike; disposed with the splash.
  late final AnimationController _pulse = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 2500))
    ..repeat(reverse: true);
  late final Animation<double> _breath =
      CurvedAnimation(parent: _pulse, curve: Curves.easeInOut);

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
    _wave.dispose();
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) =>
              _SplashHero(t: _controller.value, wave: _wave, breath: _breath),
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
///   0.00 – 0.22  the tile fades/settles in, gavel held up, head raised around the grip on its handle
///   0.22 – 0.30  anticipation: the wrist cocks the head a little higher
///   0.30 – 0.46  the strike: the gavel turns around the grip and the head comes down onto the block
///                (accelerating, `easeIn`)
///   0.46 – 0.62  impact: a short damped shake + tiny scale bump, and a small rebound of the head
///   0.46 – 0.80  a soft green ring spreads from the block and fades
///   0.40 – 0.70  "CLAUSULAZOS" fades in
///   after that   everything stays still, except the loading wave running through the name (`wave`)
class _SplashHero extends StatelessWidget {
  const _SplashHero({
    required this.t,
    required this.wave,
    required this.breath,
  });

  final double t;
  final Animation<double> wave;

  /// 0..1..0 over 5 s: how far the glow behind the gavel is into its slow brightening (see
  /// `_glowBreathAmplitude`).
  final Animation<double> breath;

  // Extra alpha the ambient glow gains at the top of each breath: small next to its 0.10 base, so it
  // softly brightens and dims without ever disappearing or flashing.
  static const double _glowBreathAmplitude = 0.04;

  @override
  Widget build(BuildContext context) {
    final appear = _segment(t, 0.0, 0.22, Curves.easeOut);
    final windUp = _segment(t, 0.22, 0.30, Curves.easeOut);
    final drop = _segment(t, 0.30, 0.46, Curves.easeIn);
    final rebound = _segment(t, 0.46, 0.58);
    final impact = _segment(t, 0.46, 0.62);
    final ring = _segment(t, 0.46, 0.80);
    final text = _segment(t, 0.40, 0.70, Curves.easeOut);

    // Gavel angle around the grip on its handle (see `GavelLogo.angle`): raised ~32°, cocked to ~39°,
    // struck at 0°, then a small bounce back of a few degrees.
    const raised = 0.55;
    const windUpExtra = 0.13;
    final angle = (raised + windUpExtra * windUp) * (1 - drop) +
        (rebound > 0 && rebound < 1 ? 0.07 * math.sin(rebound * math.pi) : 0.0);
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
              // Ambient glow behind the icon, breathing slowly (only this layer rebuilds on each breath tick).
              Opacity(
                opacity: appear,
                child: AnimatedBuilder(
                  animation: breath,
                  builder: (context, _) => Container(
                    width: 300,
                    height: 300,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          AppColors.primaryGreen.withValues(
                              alpha:
                                  glow + _glowBreathAmplitude * breath.value),
                          AppColors.primaryGreen.withValues(alpha: 0),
                        ],
                      ),
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
                    child: GavelLogo(
                        size: 128, striking: true, angle: angle, ring: ring),
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
            child: SplashWaveText(
              text: 'CLAUSULAZOS',
              style: AppTextStyles.headline(
                      fontSize: 30, fontWeight: FontWeight.w700)
                  .copyWith(letterSpacing: 4),
              animation: wave,
            ),
          ),
        ),
      ],
    );
  }
}

/// The splash name with a slow loading wave: a soft crest of light travels through the letters from left
/// to right, lifting each one a few pixels and giving it a faint green glow as it passes, then starts
/// again from the left. Neighbouring letters overlap in the crest, so it reads as one wave rather than
/// letters hopping one by one. At rest (no crest nearby) every letter is drawn exactly with `style`.
///
/// `animation` is the wave's phase, 0..1 per pass (see [cycle]). Only this widget rebuilds on each tick.
class SplashWaveText extends StatelessWidget {
  const SplashWaveText({
    super.key,
    required this.text,
    required this.style,
    required this.animation,
  });

  final String text;
  final TextStyle style;
  final Animation<double> animation;

  /// One full pass of the wave, including the short lead-in/out beyond both ends of the text.
  static const Duration cycle = Duration(milliseconds: 3200);

  // Width of the crest, in letters: how far the effect spreads to the neighbours.
  static const double _spread = 1.0;
  // The crest starts and ends this many letters outside the text, where the effect has faded to almost
  // nothing, so looping back to the start is seamless.
  static const double _lead = 3;
  static const double _maxLift = 3;
  static const double _maxGlowAlpha = 0.8;
  static const double _maxTint = 0.25;

  /// Effect strength (0..1) on letter `index` of `count` at wave `phase` (0..1): a Gaussian bump around
  /// the crest, which moves linearly from `_lead` letters before the first one to `_lead` after the last.
  static double intensity(int index, int count, double phase) {
    final crest = -_lead + phase * (count - 1 + 2 * _lead);
    final distance = (index - crest) / _spread;
    return math.exp(-0.5 * distance * distance);
  }

  @override
  Widget build(BuildContext context) {
    final letters = text.characters.toList();
    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < letters.length; i++)
            _letter(letters[i], intensity(i, letters.length, animation.value)),
        ],
      ),
    );
  }

  Widget _letter(String letter, double strength) {
    // Below this the change would be invisible; draw the plain letter.
    if (strength < 0.01) return Text(letter, style: style);
    const glow = AppColors.primaryGreen;
    return Transform.translate(
      offset: Offset(0, -_maxLift * strength),
      child: Text(
        letter,
        style: style.copyWith(
          // A touch of green light on the letter itself, plus a close and a wide halo.
          color: Color.lerp(style.color, glow, _maxTint * strength),
          shadows: [
            Shadow(
                color: glow.withValues(alpha: _maxGlowAlpha * strength),
                blurRadius: 6),
            Shadow(
                color: glow.withValues(alpha: 0.5 * _maxGlowAlpha * strength),
                blurRadius: 16),
          ],
        ),
      ),
    );
  }
}
