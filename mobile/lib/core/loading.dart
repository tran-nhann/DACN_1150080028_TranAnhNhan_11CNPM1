import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'theme.dart';

const _mint = Color(0xFFAAE4CD);

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
      systemNavigationBarColor: Color(0xFF082C30),
      systemNavigationBarIconBrightness: Brightness.light,
    ),
    child: Scaffold(
      backgroundColor: const Color(0xFF082C30),
      body: Semantics(
        label: 'Đang mở Aster Hotel',
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
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                SizedBox(
                                  width: 260,
                                  height: 260,
                                  child: CustomPaint(
                                    painter: _AsterPainter(
                                      phase: phase,
                                      color: _mint,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                const Text(
                                  'aster',
                                  style: TextStyle(
                                    color: Color(0xFFF0F7F2),
                                    fontSize: 38,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 5,
                                    height: 1.2,
                                  ),
                                ),
                                const SizedBox(height: 36),
                                _LoadingDots(phase: phase),
                              ],
                            ),
                          ),
                        ),
                      ),
                      Container(
                        width: 32,
                        height: 3,
                        margin: const EdgeInsets.only(bottom: 28),
                        decoration: BoxDecoration(
                          color: _mint.withValues(alpha: .25),
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

/// Compact version of the same motif for buttons and inline requests.
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
    children: List.generate(3, (i) {
      final wave = (math.sin(phase * math.pi * 2 - i * .8) + 1) / 2;
      return Container(
        width: 5,
        height: 5,
        margin: const EdgeInsets.symmetric(horizontal: 5),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: _mint.withValues(alpha: .2 + wave * .6),
        ),
      );
    }),
  );
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
    final breath = math.sin(angle);
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    if (!compact) {
      canvas.drawCircle(
        center,
        unit * .48,
        Paint()
          ..shader = RadialGradient(
            colors: [color.withValues(alpha: .13), color.withValues(alpha: 0)],
          ).createShader(Rect.fromCircle(center: center, radius: unit * .48)),
      );
      for (final radius in [.36, .45]) {
        canvas.drawCircle(
          center,
          unit * radius,
          stroke
            ..strokeWidth = 1
            ..color = color.withValues(alpha: .10),
        );
      }
      final rect = Rect.fromCircle(center: center, radius: unit * .36);
      canvas.drawArc(
        rect,
        angle - math.pi / 2,
        math.pi * .5,
        false,
        stroke
          ..strokeWidth = 1.5
          ..shader = SweepGradient(
            transform: GradientRotation(angle - math.pi / 2),
            colors: [color.withValues(alpha: 0), color.withValues(alpha: .75)],
            startAngle: 0,
            endAngle: math.pi * .5,
            tileMode: TileMode.clamp,
          ).createShader(rect),
      );
      stroke.shader = null;
      for (var i = 0; i < 3; i++) {
        final a = -angle * .5 + i * math.pi * 2 / 3;
        final point = center + Offset(math.cos(a), math.sin(a)) * (unit * .45);
        canvas.drawCircle(
          point,
          i == 0 ? 3 : 2,
          Paint()..color = color.withValues(alpha: i == 0 ? .85 : .35),
        );
      }
      final tile = RRect.fromRectAndRadius(
        Rect.fromCenter(center: center, width: unit * .44, height: unit * .44),
        Radius.circular(unit * .13),
      );
      canvas.drawRRect(
        tile,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [const Color(0xFF24635C), const Color(0xFF103D3E)],
          ).createShader(tile.outerRect),
      );
      canvas.drawRRect(tile, stroke..color = color.withValues(alpha: .23));
    }

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(compact ? angle : breath * .06);
    final radius = unit * (compact ? .22 : .082) * (1 + breath * .035);
    for (var i = 0; i < 8; i++) {
      canvas.save();
      canvas.rotate(i * math.pi / 4);
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(0, -radius),
          width: radius * .72,
          height: radius * 1.55,
        ),
        Paint()
          ..color = color.withValues(
            alpha: .45 + .55 * ((math.sin(angle - i * .5) + 1) / 2),
          ),
      );
      canvas.restore();
    }
    canvas.drawCircle(Offset.zero, radius * .25, Paint()..color = color);
    canvas.restore();
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

  @override
  void paint(Canvas canvas, Size size) {
    final drift = math.sin(phase * math.pi * 2) * 15;
    final bounds = Offset.zero & size;
    canvas.drawRect(
      bounds,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF163F40), Color(0xFF082C30), Color(0xFF062328)],
        ).createShader(bounds),
    );
    for (final (center, radius, color) in [
      (
        Offset(size.width + drift, size.height * .2),
        size.width * .9,
        const Color(0xFF3E977B),
      ),
      (
        Offset(-drift, size.height * .8),
        size.width * .75,
        const Color(0xFF24777C),
      ),
    ]) {
      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..shader = RadialGradient(
            colors: [color.withValues(alpha: .19), color.withValues(alpha: 0)],
          ).createShader(Rect.fromCircle(center: center, radius: radius)),
      );
    }
    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = _mint.withValues(alpha: .065);
    for (var i = 0; i < 3; i++) {
      final inset = 28.0 + i * 18;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTRB(
            inset,
            size.height * .16 + i * 18,
            size.width - inset,
            size.height + 100,
          ),
          Radius.circular(size.width / 2),
        ),
        line,
      );
    }
    for (final point in [
      Offset(size.width * .18, size.height * .21),
      Offset(size.width * .82, size.height * .68),
      Offset(size.width * .25, size.height * .8),
    ]) {
      canvas.drawCircle(
        point,
        1.5,
        Paint()..color = _mint.withValues(alpha: .3),
      );
    }
  }

  @override
  bool shouldRepaint(_AtmospherePainter oldDelegate) =>
      phase != oldDelegate.phase;
}
