import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/theme/tokens.dart';
import '../../../l10n/gen/app_localizations.dart';

/// The walk-around seen from above: the car in the middle (front up), the
/// path walked so far and where the phone is ([position], 0..360°).
class WalkMap extends StatelessWidget {
  const WalkMap({
    super.key,
    required this.position,
    this.walked = 0,
    this.clockwise = true,
    this.size = 76,
    this.from = 0,
  });

  final double position;
  final double walked;
  final bool clockwise;
  final double size;

  /// Where the walked arc starts (a quarter shot again starts at 90k°).
  final double from;

  @override
  Widget build(BuildContext context) => SizedBox.square(
        dimension: size,
        child: CustomPaint(painter: _WalkMapPainter(position, walked, clockwise, from)),
      );
}

class _WalkMapPainter extends CustomPainter {
  _WalkMapPainter(this.position, this.walked, this.clockwise, this.from);

  final double position;
  final double walked;
  final bool clockwise;
  final double from;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width * 0.42;
    canvas.drawCircle(c, size.width / 2, Paint()..color = const Color(0x99000000));

    // The path around, then what is done.
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..color = const Color(0x55FFFFFF)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    final sign = clockwise ? 1.0 : -1.0;
    double rad(double deg) => deg * math.pi / 180;
    if (walked > 0) {
      canvas.drawArc(
        Rect.fromCircle(center: c, radius: r),
        -math.pi / 2 + sign * rad(from),
        sign * rad(walked),
        false,
        Paint()
          ..color = AppColors.primary
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3.5
          ..strokeCap = StrokeCap.round,
      );
    }

    // The car, front up.
    final car = RRect.fromRectAndRadius(
      Rect.fromCenter(center: c, width: size.width * 0.22, height: size.width * 0.42),
      Radius.circular(size.width * 0.06),
    );
    canvas.drawRRect(car, Paint()..color = Colors.white.withValues(alpha: 0.9));
    canvas.drawRect(
      Rect.fromCenter(
        center: c.translate(0, -size.width * 0.11),
        width: size.width * 0.16,
        height: size.width * 0.07,
      ),
      Paint()..color = const Color(0xFF6B7280), // windscreen: the front
    );

    // The phone, looking at the car.
    final a = -math.pi / 2 + sign * rad(position);
    final p = c + Offset(math.cos(a), math.sin(a)) * r;
    final toCar = (c - p) / (c - p).distance;
    final side = Offset(-toCar.dy, toCar.dx);
    final cone = Path()
      ..moveTo(p.dx, p.dy)
      ..lineTo((p + toCar * r * 0.55 + side * r * 0.28).dx, (p + toCar * r * 0.55 + side * r * 0.28).dy)
      ..lineTo((p + toCar * r * 0.55 - side * r * 0.28).dx, (p + toCar * r * 0.55 - side * r * 0.28).dy)
      ..close();
    canvas.drawPath(cone, Paint()..color = AppColors.primary.withValues(alpha: 0.35));
    canvas.drawCircle(p, size.width * 0.06, Paint()..color = AppColors.primary);
    canvas.drawCircle(
      p,
      size.width * 0.06,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
  }

  @override
  bool shouldRepaint(_WalkMapPainter old) =>
      old.position != position || old.walked != walked || old.clockwise != clockwise || old.from != from;
}

/// "Come fare il giro a 360°": the walk shown on the map, in a loop, with
/// the four tips. Before the first walk, and from "Come si fa".
class WalkDemo extends StatefulWidget {
  const WalkDemo({super.key, required this.onDone});

  final VoidCallback onDone;

  @override
  State<WalkDemo> createState() => _WalkDemoState();
}

class _WalkDemoState extends State<WalkDemo> with SingleTickerProviderStateMixin {
  late final AnimationController _loop = AnimationController(vsync: this, duration: const Duration(seconds: 6))
    ..repeat();

  @override
  void dispose() {
    _loop.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final tips = [t.walkDemoTip1, t.walkDemoTip2, t.walkDemoTip3, t.walkDemoTip4];
    return Container(
      key: const ValueKey('walk-demo'),
      margin: const EdgeInsets.all(AppSpacing.l),
      padding: const EdgeInsets.all(AppSpacing.l),
      decoration: BoxDecoration(
        color: const Color(0xEE111316),
        borderRadius: BorderRadius.circular(AppRadius.l),
        border: Border.all(color: AppColors.glassBorder),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            t.walkDemoTitle,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: AppSpacing.m),
          Center(
            child: AnimatedBuilder(
              animation: _loop,
              builder: (context, _) {
                // A short wait in front, then once around.
                final v = ((_loop.value - 0.1) / 0.85).clamp(0.0, 1.0);
                final deg = 360 * Curves.easeInOut.transform(v);
                return WalkMap(position: deg, walked: deg, size: 150);
              },
            ),
          ),
          const SizedBox(height: AppSpacing.m),
          for (final (i, tip) in tips.indexed)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.xs),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 20,
                    height: 20,
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                    child: Text(
                      '${i + 1}',
                      style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.s),
                  Expanded(child: Text(tip, style: const TextStyle(color: Colors.white, fontSize: 14))),
                ],
              ),
            ),
          const SizedBox(height: AppSpacing.m),
          FilledButton(onPressed: widget.onDone, child: Text(t.walkDemoOk)),
        ],
      ),
    );
  }
}
