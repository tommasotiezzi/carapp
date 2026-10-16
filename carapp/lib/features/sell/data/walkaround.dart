import 'dart:async';
import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sensors_plus/sensors_plus.dart';

/// How the phone has turned around the vertical since listening began, in
/// degrees (counter-clockwise seen from above is positive). Walking around
/// a car while filming it turns the phone once around: 360°.
typedef RotationWatch = Stream<double> Function();

/// The gyroscope's rate around the "up" axis (from the accelerometer, so
/// it works however the phone is tilted), integrated over time. The
/// compass is not used: next to a car (metal) it is wrong.
final rotationWatchProvider = Provider<RotationWatch>((ref) => _gyroRotation);

Stream<double> _gyroRotation() {
  late final StreamController<double> out;
  StreamSubscription<AccelerometerEvent>? accel;
  StreamSubscription<GyroscopeEvent>? gyro;
  // Upright portrait until the accelerometer says otherwise.
  var up = (x: 0.0, y: 1.0, z: 0.0);
  var angle = 0.0;
  DateTime? last;

  out = StreamController<double>(
    onListen: () {
      accel = accelerometerEventStream(samplingPeriod: SensorInterval.gameInterval).listen((e) {
        // Low-pass: gravity only, not the steps of the walk.
        const k = 0.1;
        up = (x: up.x + (e.x - up.x) * k, y: up.y + (e.y - up.y) * k, z: up.z + (e.z - up.z) * k);
      });
      gyro = gyroscopeEventStream(samplingPeriod: SensorInterval.gameInterval).listen((e) {
        final previous = last;
        last = e.timestamp;
        if (previous == null) return;
        final dt = e.timestamp.difference(previous).inMicroseconds / 1e6;
        if (dt <= 0 || dt > 0.5) return; // a gap: skip rather than jump
        final norm = math.sqrt(up.x * up.x + up.y * up.y + up.z * up.z);
        if (norm < 1e-3) return;
        final yawRate = (e.x * up.x + e.y * up.y + e.z * up.z) / norm; // rad/s
        angle += yawRate * dt * 180 / math.pi;
        if (!out.isClosed) out.add(angle);
      });
    },
    onCancel: () async {
      await accel?.cancel();
      await gyro?.cancel();
    },
  );
  return out.stream;
}

enum WalkWarning { tooFast, backwards }

/// Follows a walk around the vehicle from the phone's rotation: how far
/// it is (0..[target]°), which way, the time of each quarter, and when to
/// slow down or turn back. Pure logic: fed by [update].
class WalkaroundTracker {
  WalkaroundTracker({this.target = 360});

  /// 360 for the whole walk, 90 to shoot one quarter again.
  final double target;

  /// Faster than this (°/s over the last second): "Più piano". A calm
  /// walk around a car is about 10-15°/s.
  static const maxSpeed = 40.0;

  /// The way is chosen after this much turning.
  static const _decideAfter = 15.0;

  /// Turned back by more than this: "Gira sempre nello stesso verso".
  static const _backTolerance = 20.0;

  /// Stopping this close to the target counts as done.
  static const _doneMargin = 5.0;

  double _angle = 0;
  double _best = 0;
  int? _sign;
  final _markers = <int>[0];
  final _history = <(int, double)>[];
  int _lastMs = 0;

  /// How far along, in degrees (never goes back).
  double get degrees => _best;

  double get progress => (_best / target).clamp(0.0, 1.0);

  bool get done => _best >= target - _doneMargin;

  /// Seen from above; null until it is clear.
  bool? get clockwise => _sign == null ? null : _sign! < 0;

  /// Where the phone is now, 0..360 along the walk (for the outline and
  /// the little map).
  double get position => (_sign == null ? 0.0 : _angle * _sign!).clamp(0.0, 360.0);

  WalkWarning? get warning {
    if (_sign != null && _best - position > _backTolerance) return WalkWarning.backwards;
    if (_history.length >= 2) {
      final (t0, a0) = _history.first;
      final (t1, a1) = _history.last;
      if (t1 - t0 >= 500 && (a1 - a0).abs() / ((t1 - t0) / 1000) > maxSpeed) return WalkWarning.tooFast;
    }
    return null;
  }

  /// [angle]: the phone's rotation since recording started (degrees);
  /// [elapsed]: time since recording started.
  void update(double angle, Duration elapsed) {
    final ms = elapsed.inMilliseconds;
    _angle = angle;
    _lastMs = ms;
    _sign ??= angle.abs() >= _decideAfter ? (angle > 0 ? 1 : -1) : null;
    _history
      ..add((ms, angle))
      ..removeWhere((h) => ms - h.$1 > 1000);
    if (_sign == null) return;
    final along = angle * _sign!;
    if (along <= _best) return;
    _best = math.min(along, target);
    // The time of each quarter crossed (whole walk only).
    if (target == 360) {
      while (_markers.length < 4 && _best >= 90.0 * _markers.length) {
        _markers.add(ms);
      }
    }
  }

  /// At the end of the recording: the quarter times for a full walk
  /// (0°, 90°, 180°, 270°, end), null when the walk was not completed.
  List<int>? markersAt(Duration end) {
    if (target != 360 || !done || _markers.length < 4) return null;
    return [..._markers, math.max(end.inMilliseconds, _lastMs)];
  }
}
