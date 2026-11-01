import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'theme.dart';

const _gold = Color(0xFFE5B842);
const _goldLight = Color(0xFFFFF0A8);

/// Shared clock that also respects the system's reduced-motion preference.
class LoadingMotion extends StatefulWidget {
  const LoadingMotion({super.key, required this.builder});
  final Widget Function(BuildContext context, double phase) builder;

  @override
  State<LoadingMotion> createState() => _LoadingMotionState();
}

class _LoadingMotionState extends State<LoadingMotion>
    with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 3200),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final media = MediaQuery.of(context);
    if (media.disableAnimations || media.accessibleNavigation) {
      _controller.stop();
      _controller.value = .25;
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _controller,
    builder: (context, _) => widget.builder(context, _controller.value),
  );
}

class StartupScreen extends StatelessWidget {
  const StartupScreen({super.key});

  @override
  Widget build(BuildContext context) => AnnotatedRegion<SystemUiOverlayStyle>(
    value: const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Color(0xFF040C1E),
      systemNavigationBarIconBrightness: Brightness.light,
    ),
    child: Scaffold(
      backgroundColor: const Color(0xFF040C1E),
      body: Semantics(
        label: 'Đang mở Khách sạn Ngàn Sao',
        liveRegion: true,
        child: ExcludeSemantics(
          child: LoadingMotion(
            builder: (context, phase) => Stack(
              fit: StackFit.expand,
              children: [
                RepaintBoundary(
                  child: CustomPaint(painter: _AtmospherePainter(phase)),
                ),
                SafeArea(
                  child: Column(
                    children: [
                      Expanded(
                        child: Center(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  // Central Hotel & Star Emblem with dynamic starlight halo
                                  SizedBox(
                                    width: 170,
                                    height: 170,
                                    child: Stack(
                                      alignment: Alignment.center,
                                      children: [
                                        CustomPaint(
                                          size: const Size(170, 170),
                                          painter: _LogoHaloPainter(phase),
                                        ),
                                        Container(
                                          width: 130,
                                          height: 130,
                                          decoration: BoxDecoration(
                                            borderRadius: BorderRadius.circular(
                                              26,
                                            ),
                                            border: Border.all(
                                              color: _gold.withValues(
                                                alpha: .5,
                                              ),
                                              width: 1.5,
                                            ),
                                            boxShadow: [
                                              BoxShadow(
                                                color: _gold.withValues(
                                                  alpha: .28,
                                                ),
                                                blurRadius: 28,
                                                spreadRadius: 2,
                                              ),
                                              BoxShadow(
                                                color: Colors.black.withValues(
                                                  alpha: .55,
                                                ),
                                                blurRadius: 16,
                                                offset: const Offset(0, 8),
                                              ),
                                            ],
                                          ),
                                          child: ClipRRect(
                                            borderRadius: BorderRadius.circular(
                                              24,
                                            ),
                                            child: Image.asset(
                                              'assets/images/logo.png',
                                              fit: BoxFit.cover,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 20),
                                  // Hotel Name
                                  const Text(
                                    'KHÁCH SẠN NGÀN SAO',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: Color(0xFFFFF7DB),
                                      fontSize: 22,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 2.5,
                                      height: 1.2,
                                      shadows: [
                                        Shadow(
                                          color: Color(0x99D4AF37),
                                          blurRadius: 14,
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  // Subtitle with 5 golden stars
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: List.generate(5, (index) {
                                      final starPhase =
                                          (math.sin(
                                                phase * math.pi * 2 +
                                                    index * .7,
                                              ) +
                                              1) /
                                          2;
                                      return Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 3,
                                        ),
                                        child: Icon(
                                          Icons.star_rounded,
                                          size: 15,
                                          color: _gold.withValues(
                                            alpha: .50 + starPhase * .50,
                                          ),
                                        ),
                                      );
                                    }),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    'ĐẲNG CẤP LƯU TRÚ & NGHỈ DƯỠNG',
                                    style: TextStyle(
                                      color: _gold.withValues(alpha: .80),
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 2.2,
                                    ),
                                  ),
                                  const SizedBox(height: 32),
                                  _LoadingDots(phase: phase),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      Container(
                        width: 36,
                        height: 3,
                        margin: const EdgeInsets.only(bottom: 24),
                        decoration: BoxDecoration(
                          color: _gold.withValues(alpha: .3),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

/// Compact star & building loader for buttons, dialogs and inline requests.
class AsterLoader extends StatelessWidget {
  const AsterLoader({super.key, this.size = 36, this.color = AsterColors.teal});
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Đang tải',
    child: SizedBox.square(
      dimension: size,
      child: RepaintBoundary(
        child: LoadingMotion(
          builder: (_, phase) => CustomPaint(
            painter: _AsterPainter(phase: phase, color: color, compact: true),
          ),
        ),
      ),
    ),
  );
}

class _LoadingDots extends StatelessWidget {
  const _LoadingDots({required this.phase});
  final double phase;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: List.generate(5, (i) {
      final wave = (math.sin(phase * math.pi * 2 - i * .8) + 1) / 2;
      return Container(
        width: 6,
        height: 6,
        margin: const EdgeInsets.symmetric(horizontal: 5),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: _goldLight.withValues(alpha: .25 + wave * .75),
          boxShadow: [
            if (wave > 0.4)
              BoxShadow(
                color: _gold.withValues(alpha: wave * .8),
                blurRadius: 8,
                spreadRadius: 1,
              ),
          ],
        ),
      );
    }),
  );
}

class _LogoHaloPainter extends CustomPainter {
  _LogoHaloPainter(this.phase);
  final double phase;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final angle = phase * math.pi * 2;
    final pulse = (math.sin(angle) + 1) / 2;

    // Soft golden starlight aura
    canvas.drawCircle(
      center,
      size.width * .48,
      Paint()
        ..shader =
            RadialGradient(
              colors: [
                _gold.withValues(alpha: .18 + pulse * .08),
                _gold.withValues(alpha: 0),
              ],
            ).createShader(
              Rect.fromCircle(center: center, radius: size.width * .48),
            ),
    );

    // Rotating subtle light rays
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(phase * math.pi * 0.3);
    final rayPaint = Paint()
      ..color = _goldLight.withValues(alpha: .06 + pulse * .04)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    for (var i = 0; i < 8; i++) {
      canvas.save();
      canvas.rotate(i * math.pi / 4);
      canvas.drawLine(
        Offset(0, -size.width * .36),
        Offset(0, -size.width * .48),
        rayPaint,
      );
      canvas.restore();
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_LogoHaloPainter oldDelegate) =>
      phase != oldDelegate.phase;
}

class _AsterPainter extends CustomPainter {
  _AsterPainter({
    required this.phase,
    required this.color,
    this.compact = false,
  });
  final double phase;
  final Color color;
  final bool compact;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final unit = size.shortestSide;
    final angle = phase * math.pi * 2;
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    if (!compact) {
      // Full loader: Hotel Arch & 5-Star Constellation
      canvas.drawCircle(
        center,
        unit * .48,
        Paint()
          ..shader = RadialGradient(
            colors: [color.withValues(alpha: .15), color.withValues(alpha: 0)],
          ).createShader(Rect.fromCircle(center: center, radius: unit * .48)),
      );

      // Celestial orbit
      canvas.drawCircle(
        center,
        unit * .40,
        stroke
          ..strokeWidth = 1.0
          ..color = color.withValues(alpha: .18),
      );

      // Orbiting starlight arc
      final rect = Rect.fromCircle(center: center, radius: unit * .40);
      canvas.drawArc(
        rect,
        angle,
        math.pi * .55,
        false,
        stroke
          ..strokeWidth = 2.0
          ..shader = SweepGradient(
            transform: GradientRotation(angle),
            colors: [color.withValues(alpha: 0), color.withValues(alpha: .9)],
            startAngle: 0,
            endAngle: math.pi * .55,
          ).createShader(rect),
      );
      stroke.shader = null;

      // Hotel Arch base
      final archRect = Rect.fromCenter(
        center: Offset(center.dx, center.dy + unit * .12),
        width: unit * .60,
        height: unit * .45,
      );
      canvas.drawArc(
        archRect,
        math.pi * .9,
        math.pi * 1.2,
        false,
        stroke
          ..strokeWidth = 1.8
          ..color = color.withValues(alpha: .45),
      );

      // Hotel Towers
      final bPaint = Paint()..style = PaintingStyle.fill;
      // Left tower
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(
            center.dx - unit * .16,
            center.dy - unit * .04,
            unit * .08,
            unit * .22,
          ),
          Radius.circular(unit * .02),
        ),
        bPaint..color = color.withValues(alpha: .50),
      );
      // Center tower (tallest)
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(
            center.dx - unit * .05,
            center.dy - unit * .12,
            unit * .10,
            unit * .30,
          ),
          Radius.circular(unit * .02),
        ),
        bPaint..color = color.withValues(alpha: .85),
      );
      // Right tower
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(
            center.dx + unit * .08,
            center.dy - unit * .04,
            unit * .08,
            unit * .22,
          ),
          Radius.circular(unit * .02),
        ),
        bPaint..color = color.withValues(alpha: .50),
      );

      // The Golden Star at summit
      final starCenter = Offset(center.dx, center.dy - unit * .22);
      final starBreath = (math.sin(angle) + 1) / 2;
      _draw4PointStar(
        canvas,
        starCenter,
        unit * (.09 + starBreath * .03),
        Paint()..color = color,
      );

      // 4 Satellite Stars
      for (var i = 0; i < 4; i++) {
        final a = math.pi * .85 + i * (math.pi * 1.3 / 3);
        final starPt =
            center + Offset(math.cos(a), math.sin(a) * .7) * (unit * .38);
        final twinkle = (math.sin(angle - i * 1.1) + 1) / 2;
        canvas.drawCircle(
          starPt,
          unit * (.016 + twinkle * .014),
          Paint()..color = color.withValues(alpha: .3 + twinkle * .7),
        );
      }
    } else {
      // Compact loader: A brilliant rotating 4-pointed Star with starlight ring
      final radius = unit * .40;
      final rect = Rect.fromCircle(center: center, radius: radius);
      canvas.drawArc(
        rect,
        angle,
        math.pi * 1.3,
        false,
        stroke
          ..strokeWidth = math.max(1.5, unit * .09)
          ..shader = SweepGradient(
            transform: GradientRotation(angle),
            colors: [color.withValues(alpha: 0), color],
            startAngle: 0,
            endAngle: math.pi * 1.3,
          ).createShader(rect),
      );
      stroke.shader = null;

      // Central 4-pointed Star
      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.rotate(-angle * .4);
      final starR = unit * .25;
      _draw4PointStar(canvas, Offset.zero, starR, Paint()..color = color);
      canvas.restore();
    }
  }

  void _draw4PointStar(Canvas canvas, Offset c, double r, Paint p) {
    final path = Path();
    final innerR = r * .28;
    for (var i = 0; i < 8; i++) {
      final a = i * math.pi / 4;
      final curR = (i % 2 == 0) ? r : innerR;
      final x = c.dx + math.cos(a) * curR;
      final y = c.dy + math.sin(a) * curR;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();
    canvas.drawPath(path, p);
  }

  @override
  bool shouldRepaint(_AsterPainter oldDelegate) =>
      phase != oldDelegate.phase ||
      color != oldDelegate.color ||
      compact != oldDelegate.compact;
}

class _AtmospherePainter extends CustomPainter {
  _AtmospherePainter(this.phase);
  final double phase;

  static final List<
    (double x, double y, double r, double speed, double offset, bool sparkle)
  >
  _stars = [
    (0.12, 0.15, 1.8, 1.0, 0.2, true),
    (0.24, 0.08, 1.2, 0.7, 1.1, false),
    (0.38, 0.18, 1.5, 1.3, 2.5, true),
    (0.68, 0.11, 2.0, 0.9, 0.8, true),
    (0.82, 0.19, 1.3, 1.2, 3.1, false),
    (0.88, 0.07, 1.6, 0.8, 1.7, true),
    (0.08, 0.35, 1.1, 1.4, 0.5, false),
    (0.92, 0.38, 1.4, 0.6, 2.2, true),
    (0.15, 0.52, 1.3, 1.1, 1.9, false),
    (0.85, 0.55, 1.5, 1.0, 0.4, false),
    (0.06, 0.72, 1.6, 0.8, 2.8, true),
    (0.94, 0.76, 1.2, 1.5, 1.3, false),
    (0.18, 0.85, 1.4, 0.7, 0.9, false),
    (0.82, 0.88, 1.5, 1.2, 2.0, true),
    (0.48, 0.05, 2.2, 1.0, 0.0, true),
    (0.55, 0.16, 1.2, 1.3, 1.6, false),
    (0.28, 0.78, 1.0, 0.9, 2.4, false),
    (0.72, 0.82, 1.1, 1.1, 0.7, false),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final bounds = Offset.zero & size;

    // 1. Midnight Sky Royal Blue Gradient
    canvas.drawRect(
      bounds,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF030A1C),
            Color(0xFF071738),
            Color(0xFF0A1E4A),
            Color(0xFF040D24),
          ],
          stops: [0.0, 0.35, 0.7, 1.0],
        ).createShader(bounds),
    );

    // 2. Warm golden celestial nebula in upper center
    final nebulaCenter = Offset(size.width * .5, size.height * .32);
    canvas.drawCircle(
      nebulaCenter,
      size.width * .85,
      Paint()
        ..shader =
            RadialGradient(
              colors: [
                _gold.withValues(alpha: .10),
                const Color(0xFF1E3A8A).withValues(alpha: .15),
                Colors.transparent,
              ],
              stops: const [0.0, 0.45, 1.0],
            ).createShader(
              Rect.fromCircle(center: nebulaCenter, radius: size.width * .85),
            ),
    );

    // 3. Hotel Horizon Arch (Curved arches framing the hotel base)
    final archPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = _gold.withValues(alpha: .12);

    for (var i = 0; i < 3; i++) {
      final inset = 24.0 + i * 22;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTRB(
            inset,
            size.height * .14 + i * 24,
            size.width - inset,
            size.height + 120,
          ),
          Radius.circular(size.width * .6),
        ),
        archPaint..color = _gold.withValues(alpha: .08 - i * .02),
      );
    }

    // 4. Twinkling Stars & 4-pointed Sparkles
    for (final (nx, ny, r, speed, offset, sparkle) in _stars) {
      final x = nx * size.width;
      final y = ny * size.height;
      final twinkle = (math.sin(phase * math.pi * 2 * speed + offset) + 1) / 2;
      final alpha = (0.2 + twinkle * 0.8).clamp(0.0, 1.0);

      // Star point core
      canvas.drawCircle(
        Offset(x, y),
        r * (0.8 + twinkle * 0.4),
        Paint()..color = _goldLight.withValues(alpha: alpha),
      );

      // Star soft glow
      if (twinkle > 0.3) {
        canvas.drawCircle(
          Offset(x, y),
          r * 2.8,
          Paint()..color = _gold.withValues(alpha: alpha * 0.3),
        );
      }

      // 4-pointed diamond star sparkle for bright stars
      if (sparkle && twinkle > 0.45) {
        final sparkLength = r * (2.5 + twinkle * 3.0);
        final sparkPaint = Paint()
          ..color = _goldLight.withValues(alpha: alpha * 0.85)
          ..strokeWidth = 0.9;
        canvas.drawLine(
          Offset(x - sparkLength, y),
          Offset(x + sparkLength, y),
          sparkPaint,
        );
        canvas.drawLine(
          Offset(x, y - sparkLength),
          Offset(x, y + sparkLength),
          sparkPaint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_AtmospherePainter oldDelegate) =>
      phase != oldDelegate.phase;
}
