import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/auth_provider.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _controller =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 600))..forward();
  late final Animation<double> _fade = CurvedAnimation(parent: _controller, curve: Curves.easeIn);

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

  ({double percent, String label}) _progressFor(AuthProvider auth) {
    switch (auth.sessionCheckStage) {
      case SessionCheckStage.idle:
        return (percent: 0, label: 'INICIANDO...');
      case SessionCheckStage.checkingSession:
        return (percent: 0.4, label: 'COMPROBANDO SESIÓN...');
      case SessionCheckStage.validatingAccess:
        return (percent: 0.75, label: 'VALIDANDO ACCESO...');
      case SessionCheckStage.done:
        final verified = auth.status == AuthStatus.authenticated;
        return (percent: 1, label: verified ? 'ACCESO VERIFICADO' : 'SIN SESIÓN ACTIVA');
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final progress = _progressFor(auth);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: FadeTransition(
        opacity: _fade,
        child: Stack(
          children: [
            const Positioned.fill(child: _SplashBackground()),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                child: Column(
                  children: [
                    const _SplashHeader(),
                    const Expanded(child: Center(child: _SplashHero())),
                    _SplashProgress(percent: progress.percent, label: progress.label),
                    const SizedBox(height: 20),
                    const _SplashFooter(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SplashHeader extends StatelessWidget {
  const _SplashHeader();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: AppColors.primaryGreen,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                'LFP FEED CONNECTED',
                style: AppTextStyles.mono(fontSize: 10, color: AppColors.textSecondary)
                    .copyWith(letterSpacing: 1.2),
              ),
            ],
          ),
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.diamond_outlined, size: 12, color: AppColors.textSecondary),
            const SizedBox(width: 4),
            Text(
              'EST. 2026',
              style: AppTextStyles.mono(fontSize: 10, color: AppColors.primaryGreen)
                  .copyWith(letterSpacing: 0.8),
            ),
          ],
        ),
      ],
    );
  }
}

class _SplashHero extends StatelessWidget {
  const _SplashHero();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 112,
          height: 112,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: AppColors.primaryGreen.withOpacity(0.25),
                blurRadius: 32,
                spreadRadius: 2,
              ),
            ],
          ),
          child: const Text('🔥', style: TextStyle(fontSize: 48)),
        ),
        const SizedBox(height: 20),
        RichText(
          text: TextSpan(
            style: AppTextStyles.headline(fontSize: 28).copyWith(letterSpacing: 1),
            children: const [
              TextSpan(text: 'CLAUSULAZOS'),
              TextSpan(text: '.', style: TextStyle(color: AppColors.primaryGreen)),
            ],
          ),
        ),
        const SizedBox(height: 8),
        RichText(
          textAlign: TextAlign.center,
          text: TextSpan(
            style: AppTextStyles.body(fontSize: 14, color: AppColors.textSecondary),
            children: [
              const TextSpan(text: 'Control de Cláusulas para '),
              TextSpan(
                text: 'LaLiga Fantasy',
                style: AppTextStyles.body(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.bolt_rounded, size: 16, color: AppColors.primaryGreen),
              const SizedBox(width: 6),
              Text(
                'MERCADO EN TIEMPO REAL',
                style: AppTextStyles.mono(fontSize: 11, fontWeight: FontWeight.w600)
                    .copyWith(letterSpacing: 0.8),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SplashProgress extends StatelessWidget {
  const _SplashProgress({required this.percent, required this.label});

  final double percent;
  final String label;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 260),
      child: Column(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: Container(
              height: 4,
              color: AppColors.surfaceElevated,
              alignment: Alignment.centerLeft,
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: percent),
                duration: const Duration(milliseconds: 400),
                curve: Curves.easeOut,
                builder: (context, value, _) {
                  return FractionallySizedBox(
                    widthFactor: value.clamp(0, 1),
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppColors.primaryGreen,
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primaryGreen.withOpacity(0.6),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: AppTextStyles.mono(fontSize: 10, color: AppColors.textSecondary)
                    .copyWith(letterSpacing: 1),
              ),
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: percent),
                duration: const Duration(milliseconds: 400),
                curve: Curves.easeOut,
                builder: (context, value, _) {
                  return Text(
                    '${(value.clamp(0, 1) * 100).round()}%',
                    style: AppTextStyles.mono(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.primaryGreen),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SplashFooter extends StatelessWidget {
  const _SplashFooter();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.verified_rounded, size: 12, color: AppColors.primaryGreen),
            const SizedBox(width: 6),
            Text(
              'V1.1 PWA OFICIAL',
              style: AppTextStyles.mono(fontSize: 10, color: AppColors.textSecondary)
                  .copyWith(letterSpacing: 1.4),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'Blindaje y ejecución táctica instantánea',
          style: AppTextStyles.body(fontSize: 11, color: AppColors.textSecondary),
        ),
      ],
    );
  }
}

class _SplashBackground extends StatelessWidget {
  const _SplashBackground();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: CustomPaint(
        painter: _SplashBackgroundPainter(),
        size: Size.infinite,
      ),
    );
  }
}

class _SplashBackgroundPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width * 0.55;

    final linePaint = Paint()
      ..color = AppColors.textSecondary.withOpacity(0.06)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    _drawDashedCircle(canvas, center, radius, linePaint);

    canvas.drawCircle(center, 2.5, Paint()..color = AppColors.textSecondary.withOpacity(0.08));

    canvas.drawLine(Offset(0, center.dy), Offset(size.width, center.dy), linePaint);

    _drawDashedLine(canvas, Offset(center.dx, center.dy - radius * 1.2),
        Offset(center.dx, center.dy + radius * 1.2), linePaint);

    final boxPaint = Paint()
      ..color = AppColors.textSecondary.withOpacity(0.05)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final boxRect = Rect.fromCenter(center: center, width: size.width * 0.7, height: size.height * 0.35);
    canvas.drawRRect(RRect.fromRectAndRadius(boxRect, const Radius.circular(4)), boxPaint);

    final glowPaint = Paint()
      ..shader = RadialGradient(
        colors: [AppColors.primaryGreen.withOpacity(0.08), Colors.transparent],
      ).createShader(Rect.fromCircle(center: Offset(size.width / 2, size.height * 0.12), radius: size.width * 0.7));
    canvas.drawRect(Offset.zero & size, glowPaint);
  }

  void _drawDashedCircle(Canvas canvas, Offset center, double radius, Paint paint) {
    const dashLength = 6.0;
    const gapLength = 5.0;
    final circumference = 2 * math.pi * radius;
    final dashCount = (circumference / (dashLength + gapLength)).floor();
    final angleStep = (dashLength + gapLength) / radius;

    for (var i = 0; i < dashCount; i++) {
      final startAngle = i * angleStep;
      final sweep = dashLength / radius;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweep,
        false,
        paint,
      );
    }
  }

  void _drawDashedLine(Canvas canvas, Offset start, Offset end, Paint paint) {
    const dashLength = 4.0;
    const gapLength = 4.0;
    final total = (end - start).distance;
    final direction = (end - start) / total;
    var distance = 0.0;
    while (distance < total) {
      final segmentEnd = math.min(distance + dashLength, total);
      canvas.drawLine(start + direction * distance, start + direction * segmentEnd, paint);
      distance += dashLength + gapLength;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
