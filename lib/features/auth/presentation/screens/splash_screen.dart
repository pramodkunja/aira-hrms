import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_app/core/router/app_router.dart';
import 'package:mobile_app/core/theme/app_colors.dart';
import '../providers/auth_providers.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with TickerProviderStateMixin {
  // One-shot timeline: a confetti burst + reveal ring fire as the badge
  // lands, then headline, divider, subtitle and loader stagger in behind
  // it — one loud beat up front, then a clean sequence.
  late final AnimationController _entrance;
  // Loops for as long as the splash is up.
  late final AnimationController _pulse; // logo breathing glow
  late final AnimationController _ripple; // continuous sonar rings
  late final AnimationController _shine; // logo specular sweep + gradient cycle
  late final AnimationController _loaderBar;

  late final Animation<double> _ringSweep;
  late final Animation<double> _ringOpacity;
  late final Animation<double> _burst;
  late final Animation<double> _logoOpacity;
  late final Animation<double> _logoScale;
  late final Animation<double> _logoRotate;
  late final Animation<double> _headlineOpacity;
  late final Animation<Offset> _headlineSlide;
  late final Animation<double> _headlineTracking;
  late final Animation<double> _dividerDot;
  late final Animation<double> _dividerLine;
  late final Animation<double> _subtitleOpacity;
  late final Animation<Offset> _subtitleSlide;
  late final Animation<double> _loaderOpacity;

  @override
  void initState() {
    super.initState();

    _entrance = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3200),
    );

    _ringSweep = CurvedAnimation(
      parent: _entrance,
      curve: const Interval(0.0, 0.28, curve: Curves.easeOutCubic),
    );
    _ringOpacity = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 8),
      TweenSequenceItem(tween: ConstantTween(1.0), weight: 55),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 37),
    ]).animate(CurvedAnimation(
      parent: _entrance,
      curve: const Interval(0.0, 0.46, curve: Curves.linear),
    ));
    _burst = CurvedAnimation(
      parent: _entrance,
      curve: const Interval(0.0, 0.50, curve: Curves.easeOut),
    );

    _logoOpacity = CurvedAnimation(
      parent: _entrance,
      curve: const Interval(0.0, 0.18, curve: Curves.easeOut),
    );
    _logoScale = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(
        parent: _entrance,
        curve: const Interval(0.0, 0.34, curve: Curves.elasticOut),
      ),
    );
    _logoRotate = Tween<double>(begin: -0.22, end: 0.0).animate(
      CurvedAnimation(
        parent: _entrance,
        curve: const Interval(0.0, 0.34, curve: Curves.easeOutBack),
      ),
    );

    _headlineOpacity = CurvedAnimation(
      parent: _entrance,
      curve: const Interval(0.30, 0.48, curve: Curves.easeOut),
    );
    _headlineSlide =
        Tween<Offset>(begin: const Offset(0, 0.35), end: Offset.zero)
            .animate(CurvedAnimation(
      parent: _entrance,
      curve: const Interval(0.30, 0.54, curve: Curves.easeOutCubic),
    ));
    _headlineTracking = Tween<double>(begin: 3.5, end: 0.2).animate(
      CurvedAnimation(
        parent: _entrance,
        curve: const Interval(0.30, 0.56, curve: Curves.easeOut),
      ),
    );

    _dividerDot = CurvedAnimation(
      parent: _entrance,
      curve: const Interval(0.50, 0.62, curve: Curves.elasticOut),
    );
    _dividerLine = CurvedAnimation(
      parent: _entrance,
      curve: const Interval(0.58, 0.74, curve: Curves.easeOutCubic),
    );

    _subtitleOpacity = CurvedAnimation(
      parent: _entrance,
      curve: const Interval(0.70, 0.86, curve: Curves.easeOut),
    );
    _subtitleSlide =
        Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero)
            .animate(CurvedAnimation(
      parent: _entrance,
      curve: const Interval(0.70, 0.90, curve: Curves.easeOutCubic),
    ));

    _loaderOpacity = CurvedAnimation(
      parent: _entrance,
      curve: const Interval(0.88, 1.0, curve: Curves.easeOut),
    );

    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);

    _ripple = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    )..repeat();

    _shine = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    )..repeat();

    _loaderBar = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();

    _entrance.forward();
    _resolveSession();
  }

  @override
  void dispose() {
    _entrance.dispose();
    _pulse.dispose();
    _ripple.dispose();
    _shine.dispose();
    _loaderBar.dispose();
    super.dispose();
  }

  Future<void> _resolveSession() async {
    // Session restore can resolve in a handful of milliseconds (no stored
    // session at all), which was dismissing this screen before the entrance
    // animation — or even a single frame of it — ever had a chance to show.
    // Enforcing a minimum display time guarantees the splash is always
    // actually seen; it never adds extra wait beyond however long the real
    // auth check takes, since this timer runs concurrently with it.
    final minDisplayTime =
        Future<void>.delayed(const Duration(milliseconds: 3000));
    try {
      // authStateProvider.future resolves the moment AuthNotifier.build() completes.
      // This is the canonical Riverpod way to await an AsyncNotifier's first value.
      final authState = await ref.read(authStateProvider.future);
      await minDisplayTime;
      if (!mounted) return;
      context.go(
          authState.isAuthenticated ? AppRoutes.dashboard : AppRoutes.login);
    } catch (_) {
      // Any error (e.g., storage failure on web) → treat as not authenticated.
      await minDisplayTime;
      if (!mounted) return;
      context.go(AppRoutes.login);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Soft brand-tinted gradient rather than flat white — matches the
    // native launch screen's plain background at frame one, then eases
    // into a bit more depth as the entrance animation plays.
    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFFFFFFF), Color(0xFFF3F6FC), Color(0xFFEAEFF9)],
          ),
        ),
        child: Stack(
          children: [
            // A large, slow-breathing wash of brand color sitting behind
            // everything — depth without a busy particle field.
            AnimatedBuilder(
              animation: _pulse,
              builder: (context, _) => Align(
                alignment: const Alignment(0, -0.15),
                child: Container(
                  width: 440,
                  height: 440,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        AppColors.primary
                            .withValues(alpha: 0.06 + _pulse.value * 0.03),
                        AppColors.primary.withValues(alpha: 0),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            // Continuous sonar rings pulsing outward from the badge.
            Center(
              child: AnimatedBuilder(
                animation: _ripple,
                builder: (context, _) => CustomPaint(
                  size: const Size(360, 360),
                  painter: _RippleRingsPainter(_ripple.value),
                ),
              ),
            ),
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  AnimatedBuilder(
                    animation: Listenable.merge([_entrance, _pulse, _shine]),
                    builder: (context, child) {
                      final breathe =
                          1.0 + (math.sin(_pulse.value * math.pi) * 0.035);
                      final innerGlow =
                          (0.22 + (_pulse.value * 0.18)) * _logoOpacity.value;
                      final outerGlow =
                          (0.10 + (_pulse.value * 0.10)) * _logoOpacity.value;
                      return Stack(
                        alignment: Alignment.center,
                        children: [
                          // Confetti burst — fires once as the badge lands.
                          CustomPaint(
                            size: const Size(320, 320),
                            painter: _BurstPainter(_burst.value),
                          ),
                          // Wide, soft outer glow.
                          Container(
                            width: 260,
                            height: 260,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: RadialGradient(
                                colors: [
                                  AppColors.secondary
                                      .withValues(alpha: outerGlow),
                                  AppColors.secondary.withValues(alpha: 0),
                                ],
                              ),
                            ),
                          ),
                          // Tighter inner glow, breathing with the logo.
                          Container(
                            width: 200,
                            height: 200,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: RadialGradient(
                                colors: [
                                  AppColors.primary
                                      .withValues(alpha: innerGlow),
                                  AppColors.primary.withValues(alpha: 0),
                                ],
                              ),
                            ),
                          ),
                          // One-shot ring that draws itself fully around the
                          // badge as it lands, then dissolves.
                          Opacity(
                            opacity: _ringOpacity.value,
                            child: CustomPaint(
                              size: const Size(226, 226),
                              painter:
                                  _RevealRingPainter(sweep: _ringSweep.value),
                            ),
                          ),
                          Opacity(
                            opacity: _logoOpacity.value,
                            child: Transform.rotate(
                              angle: _logoRotate.value,
                              child: Transform.scale(
                                scale: _logoScale.value * breathe,
                                child: ShaderMask(
                                  blendMode: BlendMode.srcATop,
                                  shaderCallback: (bounds) {
                                    final sweep = (_shine.value * 2.6) - 0.8;
                                    return LinearGradient(
                                      begin: const Alignment(-1.4, -1.0),
                                      end: const Alignment(1.4, 1.0),
                                      colors: const [
                                        Colors.transparent,
                                        Colors.transparent,
                                        Colors.white,
                                        Colors.transparent,
                                        Colors.transparent,
                                      ],
                                      stops: [
                                        0,
                                        (sweep - 0.16).clamp(0.0, 1.0),
                                        sweep.clamp(0.0, 1.0),
                                        (sweep + 0.16).clamp(0.0, 1.0),
                                        1,
                                      ],
                                    ).createShader(bounds);
                                  },
                                  child: child,
                                ),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                    child: Image.asset(
                      'assets/images/logo.png',
                      width: 200,
                    ),
                  ),
                  const SizedBox(height: 26),
                  FadeTransition(
                    opacity: _headlineOpacity,
                    child: SlideTransition(
                      position: _headlineSlide,
                      child: AnimatedBuilder(
                        animation:
                            Listenable.merge([_headlineTracking, _shine]),
                        builder: (context, _) => Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: ShaderMask(
                            blendMode: BlendMode.srcIn,
                            shaderCallback: (bounds) {
                              final shift =
                                  math.sin(_shine.value * 2 * math.pi);
                              return LinearGradient(
                                begin: Alignment(-1 + shift, 0),
                                end: Alignment(1 + shift, 0),
                                colors: [
                                  AppColors.primary,
                                  AppColors.accentPurple,
                                  AppColors.secondary,
                                  AppColors.primary,
                                ],
                              ).createShader(bounds);
                            },
                            child: Text(
                              'Adaptive Intelligence for Resource Automation',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                letterSpacing: _headlineTracking.value,
                                height: 1.3,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  _GradientDivider(dot: _dividerDot, line: _dividerLine),
                  const SizedBox(height: 14),
                  FadeTransition(
                    opacity: _subtitleOpacity,
                    child: SlideTransition(
                      position: _subtitleSlide,
                      child: Text(
                        'AI-Powered HRMS & Workforce Intelligence Platform',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.6,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 46),
                  FadeTransition(
                    opacity: _loaderOpacity,
                    child: _GradientLoaderBar(controller: _loaderBar),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Small colored shards flung outward from the badge's center and fading
/// as they go — the "confetti burst" flourish that fires once, on landing.
class _BurstPainter extends CustomPainter {
  final double t; // 0..1
  _BurstPainter(this.t);

  static const _particleCount = 26;

  @override
  void paint(Canvas canvas, Size size) {
    if (t <= 0) return;
    final center = size.center(Offset.zero);
    final colors = [
      AppColors.primary,
      AppColors.secondary,
      AppColors.accentPurple,
      AppColors.info,
      AppColors.success,
    ];
    final opacity =
        t < 0.15 ? t / 0.15 : (1 - (t - 0.15) / 0.85).clamp(0.0, 1.0);
    if (opacity <= 0) return;

    for (var i = 0; i < _particleCount; i++) {
      final angle =
          (i / _particleCount) * 2 * math.pi + math.sin(i * 12.9) * 0.15;
      final speedVariance = 0.7 + (i % 5) * 0.14;
      final distance = Curves.easeOut.transform(t) * 118 * speedVariance;
      final offset =
          center + Offset(math.cos(angle), math.sin(angle)) * distance;
      final color = colors[i % colors.length];
      final paint = Paint()..color = color.withValues(alpha: opacity * 0.85);
      final particleSize = 2.2 + (i % 4) * 0.9;

      if (i % 3 == 0) {
        // Tiny diamond sparkle for variety.
        canvas.save();
        canvas.translate(offset.dx, offset.dy);
        canvas.rotate(angle);
        final path = Path()
          ..moveTo(0, -particleSize)
          ..lineTo(particleSize, 0)
          ..lineTo(0, particleSize)
          ..lineTo(-particleSize, 0)
          ..close();
        canvas.drawPath(path, paint);
        canvas.restore();
      } else {
        canvas.drawCircle(offset, particleSize, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _BurstPainter oldDelegate) => oldDelegate.t != t;
}

/// Three faint rings expanding outward from the badge on a continuous
/// loop, staggered in phase — a subtle "energy field" that keeps the
/// splash feeling alive after the entrance settles.
class _RippleRingsPainter extends CustomPainter {
  final double t; // 0..1, looping
  _RippleRingsPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    const phases = [0.0, 0.33, 0.66];
    final colors = [
      AppColors.primary,
      AppColors.secondary,
      AppColors.accentPurple,
    ];
    for (var i = 0; i < phases.length; i++) {
      final localT = (t + phases[i]) % 1.0;
      final radius = 46 + localT * 120;
      final opacity = (1 - localT) * 0.28;
      if (opacity <= 0) continue;
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..color = colors[i].withValues(alpha: opacity);
      canvas.drawCircle(center, radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _RippleRingsPainter oldDelegate) =>
      oldDelegate.t != t;
}

/// A ring that sweeps itself in from nothing to a full circle around the
/// badge — a `Canvas.drawArc` rather than a decorated container, since a
/// partial-sweep gradient stroke isn't expressible with `BoxDecoration`.
class _RevealRingPainter extends CustomPainter {
  final double sweep; // 0..1
  _RevealRingPainter({required this.sweep});

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.width / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.6
      ..strokeCap = StrokeCap.round
      ..shader = SweepGradient(
        startAngle: -math.pi / 2,
        endAngle: -math.pi / 2 + 2 * math.pi,
        colors: [
          AppColors.primary,
          AppColors.secondary,
          AppColors.accentPurple,
          AppColors.primary,
        ],
      ).createShader(rect);
    canvas.drawArc(rect, -math.pi / 2, sweep * 2 * math.pi, false, paint);
  }

  @override
  bool shouldRepaint(covariant _RevealRingPainter oldDelegate) =>
      oldDelegate.sweep != sweep;
}

/// A center dot that pops in first, then two hairlines draw themselves
/// outward from it — a deliberate "one beat at a time" reveal instead of a
/// divider that simply fades in as a whole.
class _GradientDivider extends StatelessWidget {
  final Animation<double> dot;
  final Animation<double> line;
  const _GradientDivider({required this.dot, required this.line});

  @override
  Widget build(BuildContext context) {
    const maxLineWidth = 72.0;

    Widget growingLine({required bool reversed}) => AnimatedBuilder(
          animation: line,
          builder: (context, _) => Container(
            width: maxLineWidth * line.value,
            height: 1.4,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: reversed ? Alignment.centerRight : Alignment.centerLeft,
                end: reversed ? Alignment.centerLeft : Alignment.centerRight,
                colors: [
                  Colors.transparent,
                  reversed ? AppColors.secondary : AppColors.primary,
                ],
              ),
            ),
          ),
        );

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(width: maxLineWidth, child: growingLine(reversed: false)),
        AnimatedBuilder(
          animation: dot,
          builder: (context, _) => Container(
            width: 5 * dot.value,
            height: 5 * dot.value,
            margin: const EdgeInsets.symmetric(horizontal: 6),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.primary,
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.55),
                  blurRadius: 6,
                  spreadRadius: 1,
                ),
              ],
            ),
          ),
        ),
        SizedBox(width: maxLineWidth, child: growingLine(reversed: true)),
      ],
    );
  }
}

/// A slim rounded track with a gradient bar that sweeps back and forth,
/// carrying a soft glow of its own — reads as "working" without the visual
/// weight of a spinner, and echoes the divider's primary→secondary gradient.
class _GradientLoaderBar extends StatelessWidget {
  final Animation<double> controller;
  const _GradientLoaderBar({required this.controller});

  @override
  Widget build(BuildContext context) {
    const trackWidth = 120.0;
    const barWidth = 46.0;
    return SizedBox(
      width: trackWidth,
      height: 10,
      child: Stack(
        alignment: Alignment.center,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: Container(
              width: trackWidth,
              height: 3.5,
              color: AppColors.border,
            ),
          ),
          AnimatedBuilder(
            animation: controller,
            builder: (context, _) {
              final t = Curves.easeInOut.transform(controller.value);
              final x = (trackWidth - barWidth) *
                  (0.5 - 0.5 * math.cos(t * 2 * math.pi));
              return Align(
                alignment: Alignment.centerLeft,
                child: Transform.translate(
                  offset: Offset(x, 0),
                  child: Container(
                    width: barWidth,
                    height: 3.5,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(4),
                      gradient: LinearGradient(
                        colors: [
                          AppColors.primary,
                          AppColors.accentPurple,
                          AppColors.secondary,
                        ],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.45),
                          blurRadius: 6,
                          spreadRadius: 0.5,
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
