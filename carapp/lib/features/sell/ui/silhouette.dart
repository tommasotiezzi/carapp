import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// Shadow of the vehicle over the camera (a soft filled shape with a
/// dashed outline) so every listing is framed the same way. [name] is
/// `capture_steps[].silhouette` ('car_front', 'car_side_l', ...).
/// Unknown names draw nothing.
class Silhouette extends StatelessWidget {
  const Silhouette({super.key, required this.name, this.color = Colors.white});

  final String? name;
  final Color color;

  static const known = {
    'car_side_l',
    'car_side_r',
    'car_front',
    'car_front_3q',
    'car_rear',
    'moto_side_l',
    'moto_side_r',
    'moto_rear',
  };

  @override
  Widget build(BuildContext context) {
    if (!known.contains(name)) return const SizedBox.shrink();
    return IgnorePointer(
      child: CustomPaint(painter: _SilhouettePainter(name!, color), size: Size.infinite),
    );
  }
}

class _SilhouettePainter extends CustomPainter {
  _SilhouettePainter(this.name, this.color);

  final String name;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    // Drawn in a box 90% wide, centred, with the shape's own aspect.
    final aspect = switch (name) {
      'car_side_l' || 'car_side_r' => 2.6,
      'moto_side_l' || 'moto_side_r' => 1.6,
      'car_front' => 1.3,
      'car_front_3q' => 1.7,
      'car_rear' => 1.35,
      _ => 0.75, // moto_rear
    };
    final w = size.width * 0.9;
    final h = w / aspect;
    final box = Rect.fromCenter(center: size.center(Offset.zero), width: w, height: h);

    // Unit-box shapes to pixels (the stroke stays even on both axes).
    // Left views are the right ones mirrored.
    final mirror = name.endsWith('_l');
    final m = Float64List.fromList([
      mirror ? -box.width : box.width, 0, 0, 0,
      0, box.height, 0, 0,
      0, 0, 1, 0,
      mirror ? box.right : box.left, box.top, 0, 1,
    ]);

    // The shadow: every filled part drawn opaque in one layer, the layer
    // made translucent, so overlaps (wheels on the body) stay even.
    canvas.saveLayer(box.inflate(4), Paint()..color = color.withValues(alpha: 0.24));
    final fill = Paint()..color = color;
    for (final path in _shadow(name)) {
      canvas.drawPath(path.transform(m), fill);
    }
    canvas.restore();

    final paint = Paint()
      ..color = color.withValues(alpha: 0.9)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round;
    for (final path in _paths(name)) {
      _dashed(canvas, path.transform(m), paint, 9);
    }
  }

  /// Shapes in a unit box (0..1 on both axes), facing right.
  static List<Path> _paths(String name) => switch (name) {
        'car_side_l' || 'car_side_r' => _carSide(),
        'car_front' => _carFront(),
        'car_front_3q' => _carFront3q(),
        'car_rear' => _carRear(),
        'moto_side_l' || 'moto_side_r' => _motoSide(),
        _ => _motoRear(),
      };

  /// The filled shape under the outline, same unit box.
  static List<Path> _shadow(String name) => switch (name) {
        'car_side_l' || 'car_side_r' => [
            Path()
              ..moveTo(0.03, 0.72)
              ..lineTo(0.03, 0.55)
              ..quadraticBezierTo(0.04, 0.45, 0.14, 0.42)
              ..lineTo(0.30, 0.38)
              ..quadraticBezierTo(0.38, 0.12, 0.50, 0.10)
              ..lineTo(0.68, 0.10)
              ..quadraticBezierTo(0.76, 0.12, 0.84, 0.36)
              ..lineTo(0.95, 0.42)
              ..quadraticBezierTo(0.98, 0.48, 0.97, 0.72)
              ..close(),
            _wheel(0.225, 0.72, 0.105, 0.105 * 2.6),
            _wheel(0.775, 0.72, 0.105, 0.105 * 2.6),
          ],
        'car_front' => [_carFrontBody(), ..._carFrontMirrors(), ..._carFrontTyres()],
        'car_front_3q' => [
            Path()
              ..moveTo(0.04, 0.70)
              ..lineTo(0.04, 0.48)
              ..lineTo(0.22, 0.40)
              ..lineTo(0.34, 0.16)
              ..lineTo(0.70, 0.12)
              ..lineTo(0.86, 0.36)
              ..lineTo(0.97, 0.42)
              ..lineTo(0.97, 0.70)
              ..lineTo(0.34, 0.78)
              ..close(),
            _wheel(0.255, 0.78, 0.085, 0.085 * 1.7 * 1.1),
            _wheel(0.815, 0.74, 0.075, 0.075 * 1.7 * 1.1),
          ],
        'car_rear' => [_carRear().first],
        'moto_side_l' || 'moto_side_r' => [
            Path()
              ..moveTo(0.12, 0.44)
              ..lineTo(0.18, 0.36)
              ..lineTo(0.40, 0.38)
              ..quadraticBezierTo(0.48, 0.24, 0.64, 0.28)
              ..lineTo(0.70, 0.20)
              ..lineTo(0.76, 0.22)
              ..lineTo(0.82, 0.62)
              ..lineTo(0.62, 0.62)
              ..lineTo(0.40, 0.62)
              ..lineTo(0.30, 0.50)
              ..close(),
            _wheel(0.20, 0.70, 0.16, 0.16 * 1.6),
            _wheel(0.80, 0.70, 0.16, 0.16 * 1.6),
          ],
        _ => _motoRear(),
      };

  static Path _wheel(double cx, double cy, double rx, double ry) =>
      Path()..addOval(Rect.fromCenter(center: Offset(cx, cy), width: rx * 2, height: ry * 2));

  static List<Path> _carSide() {
    final body = Path()
      ..moveTo(0.03, 0.72)
      ..lineTo(0.03, 0.55)
      ..quadraticBezierTo(0.04, 0.45, 0.14, 0.42)
      ..lineTo(0.30, 0.38)
      ..quadraticBezierTo(0.38, 0.12, 0.50, 0.10)
      ..lineTo(0.68, 0.10)
      ..quadraticBezierTo(0.76, 0.12, 0.84, 0.36)
      ..lineTo(0.95, 0.42)
      ..quadraticBezierTo(0.98, 0.48, 0.97, 0.72)
      ..lineTo(0.88, 0.72)
      ..moveTo(0.67, 0.72)
      ..lineTo(0.33, 0.72)
      ..moveTo(0.12, 0.72)
      ..lineTo(0.03, 0.72);
    final windows = Path()
      ..moveTo(0.36, 0.38)
      ..quadraticBezierTo(0.42, 0.18, 0.51, 0.17)
      ..lineTo(0.66, 0.17)
      ..quadraticBezierTo(0.72, 0.19, 0.78, 0.36)
      ..close()
      ..moveTo(0.57, 0.17)
      ..lineTo(0.57, 0.37);
    return [
      body,
      windows,
      _wheel(0.225, 0.72, 0.105, 0.105 * 2.6),
      _wheel(0.775, 0.72, 0.105, 0.105 * 2.6),
      Path()
        ..moveTo(0, 0.9)
        ..lineTo(1, 0.9),
    ];
  }

  // Front view: body up to the shoulders, the cabin narrower on top,
  // mirrors, tyres showing under the bumper.
  static Path _carFrontBody() => Path()
    ..moveTo(0.07, 0.88)
    ..lineTo(0.05, 0.70)
    ..quadraticBezierTo(0.04, 0.56, 0.08, 0.50)
    ..lineTo(0.17, 0.47)
    ..lineTo(0.27, 0.15)
    ..quadraticBezierTo(0.29, 0.10, 0.35, 0.10)
    ..lineTo(0.65, 0.10)
    ..quadraticBezierTo(0.71, 0.10, 0.73, 0.15)
    ..lineTo(0.83, 0.47)
    ..lineTo(0.92, 0.50)
    ..quadraticBezierTo(0.96, 0.56, 0.95, 0.70)
    ..lineTo(0.93, 0.88)
    ..close();

  static List<Path> _carFrontMirrors() => [
        Path()
          ..moveTo(0.18, 0.40)
          ..lineTo(0.08, 0.38)
          ..quadraticBezierTo(0.06, 0.42, 0.08, 0.45)
          ..lineTo(0.17, 0.46)
          ..close(),
        Path()
          ..moveTo(0.82, 0.40)
          ..lineTo(0.92, 0.38)
          ..quadraticBezierTo(0.94, 0.42, 0.92, 0.45)
          ..lineTo(0.83, 0.46)
          ..close(),
      ];

  static List<Path> _carFrontTyres() => [
        Path()..addRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(0.09, 0.80, 0.15, 0.15), const Radius.circular(0.03))),
        Path()..addRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(0.76, 0.80, 0.15, 0.15), const Radius.circular(0.03))),
      ];

  static List<Path> _carFront() {
    final glass = Path()
      ..moveTo(0.21, 0.45)
      ..lineTo(0.30, 0.18)
      ..quadraticBezierTo(0.31, 0.16, 0.34, 0.16)
      ..lineTo(0.66, 0.16)
      ..quadraticBezierTo(0.69, 0.16, 0.70, 0.18)
      ..lineTo(0.79, 0.45)
      ..close();
    final face = Path()
      // Headlights.
      ..moveTo(0.09, 0.56)
      ..lineTo(0.31, 0.59)
      ..lineTo(0.29, 0.65)
      ..lineTo(0.10, 0.63)
      ..close()
      ..moveTo(0.91, 0.56)
      ..lineTo(0.69, 0.59)
      ..lineTo(0.71, 0.65)
      ..lineTo(0.90, 0.63)
      ..close()
      // Grille, plate, bumper line.
      ..addRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(0.35, 0.60, 0.30, 0.09), const Radius.circular(0.02)))
      ..addRect(const Rect.fromLTWH(0.40, 0.74, 0.20, 0.06))
      ..moveTo(0.08, 0.72)
      ..lineTo(0.30, 0.73)
      ..moveTo(0.70, 0.73)
      ..lineTo(0.92, 0.72);
    return [
      _carFrontBody(),
      glass,
      face,
      ..._carFrontMirrors(),
      ..._carFrontTyres(),
      Path()
        ..moveTo(0, 0.95)
        ..lineTo(1, 0.95),
    ];
  }

  static List<Path> _carFront3q() {
    final body = Path()
      ..moveTo(0.04, 0.70)
      ..lineTo(0.04, 0.48)
      ..lineTo(0.22, 0.40)
      ..lineTo(0.34, 0.16)
      ..lineTo(0.70, 0.12)
      ..lineTo(0.86, 0.36)
      ..lineTo(0.97, 0.42)
      ..lineTo(0.97, 0.70)
      ..lineTo(0.90, 0.74)
      ..moveTo(0.73, 0.76)
      ..lineTo(0.34, 0.78)
      ..moveTo(0.17, 0.78)
      ..lineTo(0.04, 0.70);
    final glass = Path()
      ..moveTo(0.24, 0.40)
      ..lineTo(0.36, 0.19)
      ..lineTo(0.56, 0.17)
      ..lineTo(0.62, 0.38)
      ..close()
      ..moveTo(0.62, 0.38)
      ..lineTo(0.69, 0.16)
      ..lineTo(0.82, 0.36);
    final lights = Path()
      ..moveTo(0.06, 0.52)
      ..lineTo(0.18, 0.50)
      ..moveTo(0.88, 0.46)
      ..lineTo(0.95, 0.48);
    return [
      body,
      glass,
      lights,
      _wheel(0.255, 0.78, 0.085, 0.085 * 1.7 * 1.1),
      _wheel(0.815, 0.74, 0.075, 0.075 * 1.7 * 1.1),
    ];
  }

  static List<Path> _carRear() {
    final body = Path()
      ..moveTo(0.06, 0.82)
      ..lineTo(0.04, 0.50)
      ..quadraticBezierTo(0.06, 0.42, 0.16, 0.40)
      ..lineTo(0.24, 0.14)
      ..quadraticBezierTo(0.26, 0.10, 0.32, 0.10)
      ..lineTo(0.68, 0.10)
      ..quadraticBezierTo(0.74, 0.10, 0.76, 0.14)
      ..lineTo(0.84, 0.40)
      ..quadraticBezierTo(0.94, 0.42, 0.96, 0.50)
      ..lineTo(0.94, 0.82)
      ..close();
    final details = Path()
      ..moveTo(0.27, 0.36)
      ..lineTo(0.31, 0.16)
      ..lineTo(0.69, 0.16)
      ..lineTo(0.73, 0.36)
      ..close()
      ..addRect(const Rect.fromLTWH(0.38, 0.58, 0.24, 0.08)) // plate
      ..moveTo(0.08, 0.50)
      ..lineTo(0.24, 0.50)
      ..moveTo(0.76, 0.50)
      ..lineTo(0.92, 0.50);
    return [body, details];
  }

  static List<Path> _motoSide() {
    final frame = Path()
      ..moveTo(0.22, 0.70)
      ..lineTo(0.40, 0.42)
      ..lineTo(0.62, 0.42)
      ..lineTo(0.76, 0.70)
      ..moveTo(0.40, 0.42)
      ..quadraticBezierTo(0.48, 0.26, 0.62, 0.30) // tank
      ..lineTo(0.70, 0.22) // to the bars
      ..moveTo(0.66, 0.20)
      ..lineTo(0.76, 0.18)
      ..moveTo(0.70, 0.22)
      ..lineTo(0.80, 0.70) // fork
      ..moveTo(0.40, 0.42)
      ..lineTo(0.18, 0.38) // seat
      ..lineTo(0.12, 0.44);
    return [
      frame,
      _wheel(0.20, 0.70, 0.16, 0.16 * 1.6),
      _wheel(0.80, 0.70, 0.16, 0.16 * 1.6),
    ];
  }

  static List<Path> _motoRear() {
    final body = Path()
      ..moveTo(0.20, 0.18)
      ..lineTo(0.80, 0.18) // bars
      ..moveTo(0.36, 0.30)
      ..lineTo(0.64, 0.30)
      ..lineTo(0.60, 0.56)
      ..lineTo(0.40, 0.56)
      ..close()
      ..addRect(const Rect.fromLTWH(0.40, 0.60, 0.20, 0.08)); // plate
    final wheel = Path()..addRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(0.43, 0.70, 0.14, 0.26), const Radius.circular(0.06)));
    return [body, wheel];
  }

  static void _dashed(Canvas canvas, Path path, Paint paint, double dash) {
    for (final ui.PathMetric metric in path.computeMetrics()) {
      var d = 0.0;
      while (d < metric.length) {
        final next = (d + dash).clamp(0, metric.length).toDouble();
        canvas.drawPath(metric.extractPath(d, next), paint);
        d = next + dash * 0.7;
      }
    }
  }

  @override
  bool shouldRepaint(_SilhouettePainter old) => old.name != name || old.color != color;
}
