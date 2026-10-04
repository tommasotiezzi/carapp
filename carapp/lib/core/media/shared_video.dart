import 'package:video_player/video_player.dart';

/// A video player that more than one screen can hold.
///
/// The feed lends the player of the listing on screen to the listing
/// page, so the video continues from where it was instead of being
/// downloaded again. Whoever holds it calls [retain] / [release]; the
/// player is disposed by the last [release]. Only one holder drives
/// play / pause at a time (the feed stops while the listing is open).
class SharedVideo {
  SharedVideo(this.url) : controller = VideoPlayerController.networkUrl(
          Uri.parse(url),
          videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
        ) {
    controller.setLooping(true);
  }

  final String url;
  final VideoPlayerController controller;
  int _holders = 1;
  Future<void>? _initializing;

  bool get isDisposed => _holders <= 0;

  /// Starts loading once, whoever asks first.
  Future<void> initialize() => _initializing ??= controller.initialize();

  SharedVideo retain() {
    assert(!isDisposed, 'retain() on a released SharedVideo');
    _holders++;
    return this;
  }

  void release() {
    if (isDisposed) return;
    _holders--;
    if (_holders == 0) controller.dispose();
  }
}
