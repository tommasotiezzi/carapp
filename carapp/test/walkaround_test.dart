import 'package:carapp/features/sell/data/walkaround.dart';
import 'package:carapp/features/sell/ui/sell_labels.dart';
import 'package:carapp/features/sell/ui/silhouette.dart';
import 'package:carapp/features/sell/ui/walk_guide.dart';
import 'package:carapp/l10n/gen/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

/// Feeds a walk: [degreesPerSecond] (signed) for [seconds], 20 samples/s.
Duration _walk(WalkaroundTracker t, {required double degreesPerSecond, required double seconds, Duration from = Duration.zero, double start = 0}) {
  var at = from;
  final steps = (seconds * 20).round();
  for (var i = 1; i <= steps; i++) {
    at = from + Duration(milliseconds: i * 50);
    t.update(start + degreesPerSecond * i / 20, at);
  }
  return at;
}

void main() {
  group('WalkaroundTracker', () {
    test('a calm clockwise walk: progress, the quarter times, done at the end', () {
      final t = WalkaroundTracker();
      expect(t.clockwise, isNull);
      // 12°/s clockwise seen from above = negative rotation.
      final end = _walk(t, degreesPerSecond: -12, seconds: 30);
      expect(t.clockwise, isTrue);
      expect(t.done, isTrue);
      expect(t.progress, 1.0);
      expect(t.warning, isNull);
      final m = t.markersAt(end)!;
      expect(m, hasLength(5));
      expect(m.first, 0);
      expect(m[1], closeTo(7500, 60)); // 90° at 12°/s
      expect(m[2], closeTo(15000, 60));
      expect(m[3], closeTo(22500, 60));
      expect(m[4], end.inMilliseconds);
    });

    test('the other way round: counter-clockwise', () {
      final t = WalkaroundTracker();
      _walk(t, degreesPerSecond: 15, seconds: 25);
      expect(t.clockwise, isFalse);
      expect(t.done, isTrue);
    });

    test('a little shake before walking chooses nothing', () {
      final t = WalkaroundTracker();
      t
        ..update(5, const Duration(milliseconds: 100))
        ..update(-6, const Duration(milliseconds: 200))
        ..update(8, const Duration(milliseconds: 300));
      expect(t.clockwise, isNull);
      expect(t.degrees, 0);
      expect(t.position, 0);
    });

    test('turning back warns and does not count', () {
      final t = WalkaroundTracker();
      final at = _walk(t, degreesPerSecond: 12, seconds: 10); // 120°
      expect(t.degrees, closeTo(120, 0.01));
      _walk(t, degreesPerSecond: -12, seconds: 3, from: at, start: 120); // back to 84°
      expect(t.degrees, closeTo(120, 0.01), reason: 'never goes back');
      expect(t.position, closeTo(84, 0.01));
      expect(t.warning, WalkWarning.backwards);
    });

    test('too fast warns, a calm pace does not', () {
      final fast = WalkaroundTracker();
      _walk(fast, degreesPerSecond: 60, seconds: 2);
      expect(fast.warning, WalkWarning.tooFast);
      final calm = WalkaroundTracker();
      _walk(calm, degreesPerSecond: 14, seconds: 4);
      expect(calm.warning, isNull);
    });

    test('stopped early: no quarter times', () {
      final t = WalkaroundTracker();
      final end = _walk(t, degreesPerSecond: 12, seconds: 20); // 240°
      expect(t.done, isFalse);
      expect(t.markersAt(end), isNull);
    });

    test('one quarter again: done at 90°, no quarter times', () {
      final t = WalkaroundTracker(target: 90);
      final end = _walk(t, degreesPerSecond: -12, seconds: 8);
      expect(t.done, isTrue);
      expect(t.progress, 1.0);
      expect(t.markersAt(end), isNull);
    });
  });

  test('walk outline: front, first side, rear, other side', () {
    expect(walkSilhouette(0, clockwise: true), 'car_front');
    expect(walkSilhouette(30, clockwise: true), 'car_front');
    expect(walkSilhouette(90, clockwise: true), 'car_side_r');
    expect(walkSilhouette(90, clockwise: false), 'car_side_l');
    expect(walkSilhouette(180, clockwise: true), 'car_rear');
    expect(walkSilhouette(270, clockwise: true), 'car_side_l');
    expect(walkSilhouette(350, clockwise: true), 'car_front');
  });

  test('quarter names follow the direction', () {
    final t = lookupAppLocalizations(const Locale('it'));
    expect(t.walkQuarterLabel(1, clockwise: true), 'Dal muso al fianco destro');
    expect(t.walkQuarterLabel(2, clockwise: true), 'Dal fianco destro al posteriore');
    expect(t.walkQuarterLabel(4, clockwise: true), 'Dal fianco sinistro al muso');
    expect(t.walkQuarterLabel(1, clockwise: false), 'Dal muso al fianco sinistro');
  });

  testWidgets('the "how to" card: the walk, the tips, "Ho capito"', (tester) async {
    var done = false;
    await tester.pumpWidget(MaterialApp(
      locale: const Locale('it'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: Scaffold(
        backgroundColor: Colors.black,
        body: SingleChildScrollView(child: WalkDemo(onDone: () => done = true)),
      ),
    ));
    await tester.pump(const Duration(seconds: 3));
    expect(find.text('Come fare il giro a 360°'), findsOneWidget);
    expect(find.byType(WalkMap), findsOneWidget);
    expect(find.textContaining('sempre nello stesso verso'), findsOneWidget);
    await tester.tap(find.text('Ho capito'));
    expect(done, isTrue);
  });
}
