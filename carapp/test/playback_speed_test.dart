import 'package:carapp/core/media/playback_speed.dart';
import 'package:carapp/core/storage/preferences.dart';
import 'package:carapp/l10n/gen/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('labels', () {
    expect(speedLabel(1), '1×');
    expect(speedLabel(1.5), '1,5×');
    expect(speedLabel(2), '2×');
  });

  testWidgets('the pill cycles 1× → 1,5× → 2× → 1× and is remembered', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    Widget app() => ProviderScope(
          key: UniqueKey(),
          overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
          child: const MaterialApp(
            locale: Locale('it'),
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            home: Scaffold(body: Center(child: SpeedButton())),
          ),
        );
    await tester.pumpWidget(app());
    expect(find.text('1×'), findsOneWidget);
    expect(find.bySemanticsLabel('Velocità 1×'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('speed-button')));
    await tester.pump();
    expect(find.text('1,5×'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('speed-button')));
    await tester.pump();
    expect(find.text('2×'), findsOneWidget);
    expect(prefs.getDouble(PrefKeys.playbackSpeed), 2.0);

    // A new start of the app keeps it.
    await tester.pumpWidget(app());
    expect(find.text('2×'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('speed-button')));
    await tester.pump();
    expect(find.text('1×'), findsOneWidget);
  });
}
