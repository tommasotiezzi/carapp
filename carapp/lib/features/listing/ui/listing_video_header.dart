import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';

import '../../../core/analytics/event_tracker.dart';
import '../../../core/media/media_url.dart';
import '../../../core/media/shared_video.dart';
import '../../../core/supabase/supabase_client.dart';
import '../../feed/ui/feed_video_view.dart';
import '../data/listing_detail.dart';

/// The listing video at the top of the screen, with the same tap / zoom
/// behaviour as the feed. Plays only while it is on screen ([visible]),
/// the page is not covered by another route and the app is in foreground.
class ListingVideoHeader extends ConsumerStatefulWidget {
  const ListingVideoHeader({
    super.key,
    required this.listing,
    required this.height,
    required this.visible,
    this.lent,
  });

  final ListingDetail listing;

  /// The feed's player for this video, when opened from the feed:
  /// used as is (no second download), continuing from where it was.
  final SharedVideo? lent;
  final double height;

  /// false once the user scrolled the video out of view.
  final ValueListenable<bool> visible;

  @override
  ConsumerState<ListingVideoHeader> createState() => _ListingVideoHeaderState();
}

class _ListingVideoHeaderState extends ConsumerState<ListingVideoHeader>
    with WidgetsBindingObserver {
  SharedVideo? _video;
  VideoPlayerController? get _player => _video?.controller;
  bool _routeVisible = true;
  bool _appActive = true;
  bool _pausedByUser = false;

  bool get _canPlay => _routeVisible && _appActive && widget.visible.value && !_pausedByUser;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.visible.addListener(_updatePlayback);

    final url = MediaUrl.resolve(ref.read(supabaseProvider), widget.listing.videoPath);
    if (url == null) return;
    final lent = widget.lent;
    final video = lent != null && lent.url == url && !lent.isDisposed ? lent.retain() : SharedVideo(url);
    _video = video;
    video.initialize().then((_) {
      if (!mounted) return;
      setState(() {});
      _updatePlayback();
    }).catchError((_) {});
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Off when a full-screen route (e.g. the photo viewer) covers this page.
    final visible = TickerMode.valuesOf(context).enabled;
    if (visible != _routeVisible) {
      _routeVisible = visible;
      _updatePlayback();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.visible.removeListener(_updatePlayback);
    _video?.release();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _appActive = state == AppLifecycleState.resumed;
    _updatePlayback();
  }

  void _updatePlayback() {
    final p = _player;
    if (p == null || !p.value.isInitialized) return;
    _canPlay ? p.play() : p.pause();
  }

  void _togglePause() {
    setState(() => _pausedByUser = !_pausedByUser);
    _updatePlayback();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: widget.height,
      width: double.infinity,
      child: FeedVideoView(
        controller: _player,
        coverUrl: MediaUrl.resolve(ref.read(supabaseProvider), widget.listing.coverPath),
        pausedByUser: _pausedByUser,
        onTogglePause: _togglePause,
        onZoom: () => ref
            .read(eventTrackerProvider)
            .track(AnalyticsEvent.zoom, listingId: widget.listing.id),
      ),
    );
  }
}
