import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/gen/app_localizations.dart';
import '../storage/preferences.dart';

/// Video speed in the feed and on the listing (1×, 1,5×, 2×): the
/// videos are filmed at normal speed, viewers choose. Remembered on the
/// phone.
class PlaybackSpeedController extends Notifier<double> {
  static const speeds = [1.0, 1.5, 2.0];

  @override
  double build() {
    final saved = ref.read(sharedPreferencesProvider).getDouble(PrefKeys.playbackSpeed);
    return speeds.contains(saved) ? saved! : 1.0;
  }

  /// 1× → 1,5× → 2× → 1×.
  void next() {
    final i = speeds.indexOf(state);
    state = speeds[(i + 1) % speeds.length];
    ref.read(sharedPreferencesProvider).setDouble(PrefKeys.playbackSpeed, state);
  }
}

final playbackSpeedProvider =
    NotifierProvider<PlaybackSpeedController, double>(PlaybackSpeedController.new);

/// "1×" / "1,5×" / "2×".
String speedLabel(double speed) =>
    '${speed == speed.roundToDouble() ? speed.toInt() : speed.toString().replaceAll('.', ',')}×';

/// The speed pill over a video: tap for the next speed.
class SpeedButton extends ConsumerWidget {
  const SpeedButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final speed = ref.watch(playbackSpeedProvider);
    return Semantics(
      button: true,
      label: AppLocalizations.of(context).playbackSpeed(speedLabel(speed)),
      excludeSemantics: true,
      child: GestureDetector(
        key: const ValueKey('speed-button'),
        behavior: HitTestBehavior.opaque,
        onTap: () => ref.read(playbackSpeedProvider.notifier).next(),
        child: Container(
          constraints: const BoxConstraints(minWidth: 48, minHeight: 32),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: speed == 1 ? const Color(0x66000000) : Colors.white,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: const Color(0x66FFFFFF)),
          ),
          child: Text(
            speedLabel(speed),
            style: TextStyle(
              color: speed == 1 ? Colors.white : Colors.black,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}
