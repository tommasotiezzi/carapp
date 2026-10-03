import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:video_player/video_player.dart';

import '../../../core/analytics/event_tracker.dart';
import '../../../core/config/app_config.dart';
import '../../../core/media/media_url.dart';
import '../../../core/router/routes.dart';
import '../../../core/supabase/supabase_client.dart';
import '../../../core/theme/tokens.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../../onboarding/state/onboarding_controller.dart';
import '../data/feed_item.dart';
import '../state/feed_controller.dart';
import 'feed_overlay.dart';
import 'feed_video_view.dart';

class FeedScreen extends ConsumerWidget {
  const FeedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final feed = ref.watch(feedControllerProvider);

    return Scaffold(
      backgroundColor: AppColors.feedBackground,
      body: feed.when(
        loading: () => const _FeedLoading(),
        error: (e, _) => _FeedMessage(
          title: 'Qualcosa è andato storto',
          body: 'Controlla la connessione e riprova.',
          actionLabel: 'Riprova',
          onAction: () => ref.read(feedControllerProvider.notifier).refresh(),
        ),
        data: (state) => state.items.isEmpty
            ? _FeedMessage(
                title: 'Ancora nessun annuncio',
                body: 'Torna tra poco: stiamo caricando le prime auto.',
                actionLabel: 'Aggiorna',
                onAction: () => ref.read(feedControllerProvider.notifier).refresh(),
              )
            : _FeedPager(items: state.items),
      ),
    );
  }
}

/// Vertical pager. Keeps at most 3 video players alive
/// (previous, current, next): the next one is already buffering
/// when the user swipes.
class _FeedPager extends ConsumerStatefulWidget {
  const _FeedPager({required this.items});

  final List<FeedItem> items;

  @override
  ConsumerState<_FeedPager> createState() => _FeedPagerState();
}

class _FeedPagerState extends ConsumerState<_FeedPager>
    with WidgetsBindingObserver {
  final _pageController = PageController();
  final _players = <int, VideoPlayerController>{};
  int _current = 0;
  int _viewedThisSession = 0;
  bool _onboardingOpen = false;
  DateTime _shownAt = DateTime.now();

  // The current video plays only when all three allow it.
  bool _visible = true; // false on another tab or under a full-screen route
  bool _appActive = true;
  bool _pausedByUser = false;

  bool get _canPlay => _visible && _appActive && !_pausedByUser;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _syncPlayers();
    _trackView(_current);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // go_router turns tickers off for inactive tabs, and the Navigator does
    // the same for pages covered by a full-screen route (/sell, /listing...).
    final visible = TickerMode.of(context);
    if (visible != _visible) {
      _visible = visible;
      _updatePlayback();
    }
  }

  @override
  void didUpdateWidget(covariant _FeedPager oldWidget) {
    super.didUpdateWidget(oldWidget);
    // New page loaded: make sure the next video starts buffering.
    if (oldWidget.items.length != widget.items.length) _syncPlayers();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _trackWatchTime(_current);
    for (final p in _players.values) {
      p.dispose();
    }
    _pageController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _appActive = state == AppLifecycleState.resumed;
    _updatePlayback();
  }

  /// Plays or pauses the current video according to [_canPlay].
  void _updatePlayback() {
    final p = _players[_current];
    if (p == null || !p.value.isInitialized) return;
    _canPlay ? p.play() : p.pause();
  }

  void _togglePause() {
    setState(() => _pausedByUser = !_pausedByUser);
    _updatePlayback();
  }

  String? _videoUrl(int i) =>
      MediaUrl.resolve(ref.read(supabaseProvider), widget.items[i].videoPath);

  String? _coverUrl(int i) =>
      MediaUrl.resolve(ref.read(supabaseProvider), widget.items[i].coverPath);

  /// Create players for current ± 1, dispose everything else.
  void _syncPlayers() {
    final keep = {_current - 1, _current, _current + 1}
        .where((i) => i >= 0 && i < widget.items.length)
        .toSet();

    for (final i in _players.keys.where((i) => !keep.contains(i)).toList()) {
      _players.remove(i)?.dispose();
    }

    for (final i in keep) {
      if (_players.containsKey(i)) continue;
      final url = _videoUrl(i);
      if (url == null) continue;

      final player = VideoPlayerController.networkUrl(
        Uri.parse(url),
        videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
      );
      _players[i] = player;
      player
        ..setLooping(true)
        ..initialize().then((_) {
          if (!mounted || !_players.containsValue(player)) return;
          if (i == _current && _canPlay) player.play();
          setState(() {});
        }).catchError((_) {});
    }

    for (final entry in _players.entries) {
      if (entry.key == _current) {
        if (entry.value.value.isInitialized && _canPlay) entry.value.play();
      } else {
        entry.value
          ..pause()
          ..seekTo(Duration.zero);
      }
    }
  }

  void _onPageChanged(int index) {
    _trackWatchTime(_current);
    setState(() {
      _current = index;
      _pausedByUser = false;
    });
    _syncPlayers();
    _trackView(index);

    // Ask for the next page when 3 cards from the end.
    if (index >= widget.items.length - 3) {
      ref.read(feedControllerProvider.notifier).loadMore();
    }

    // After a few listings, offer onboarding (once, until done or skipped).
    _viewedThisSession++;
    final config = ref.read(appConfigProvider).value ?? AppConfig.empty;
    if (_viewedThisSession >= config.onboardingValue('show_after_listings', 4)) {
      _maybeShowOnboarding();
    }
  }

  /// Opens onboarding over the feed if the user has not done it yet.
  /// Returns true when it was shown, so the tapped action can wait.
  bool _maybeShowOnboarding() {
    if (_onboardingOpen || ref.read(onboardingControllerProvider).done) return false;
    _onboardingOpen = true;
    _players[_current]?.pause();
    context.push(AppRoutes.onboarding).then((_) {
      _onboardingOpen = false;
      if (mounted) _updatePlayback();
    });
    return true;
  }

  /// Every action button goes through here: first interaction = onboarding.
  void _interact(VoidCallback action) {
    if (_maybeShowOnboarding()) return;
    action();
  }

  void _trackView(int i) {
    if (i >= widget.items.length) return;
    _shownAt = DateTime.now();
    ref.read(eventTrackerProvider).track(AnalyticsEvent.view, listingId: widget.items[i].id);
  }

  void _trackWatchTime(int i) {
    if (i >= widget.items.length) return;
    final ms = DateTime.now().difference(_shownAt).inMilliseconds;
    ref.read(eventTrackerProvider).track(
          AnalyticsEvent.watchTime,
          listingId: widget.items[i].id,
          value: ms,
        );
  }

  void _openDetail(FeedItem item) {
    _players[_current]?.pause();
    ref.read(eventTrackerProvider).track(AnalyticsEvent.openDetail, listingId: item.id);
    context.push(AppRoutes.listingPath(item.id)).then((_) {
      if (mounted) _updatePlayback();
    });
  }

  void _comingSoon(String what) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(AppLocalizations.of(context).comingSoon(what))));
  }

  @override
  Widget build(BuildContext context) {
    return PageView.builder(
      controller: _pageController,
      scrollDirection: Axis.vertical,
      itemCount: widget.items.length,
      onPageChanged: _onPageChanged,
      itemBuilder: (context, i) {
        final item = widget.items[i];
        return GestureDetector(
          // Swipe left opens the listing, like TikTok opens the profile.
          onHorizontalDragEnd: (d) {
            if ((d.primaryVelocity ?? 0) < -300) _openDetail(item);
          },
          child: Stack(
            fit: StackFit.expand,
            children: [
              FeedVideoView(
                key: ValueKey(item.id),
                controller: _players[i],
                coverUrl: _coverUrl(i),
                pausedByUser: i == _current && _pausedByUser,
                onTogglePause: _togglePause,
                onZoom: () => ref
                    .read(eventTrackerProvider)
                    .track(AnalyticsEvent.zoom, listingId: item.id),
              ),
              SafeArea(
                bottom: false,
                child: FeedOverlay(
                  item: item,
                  onOpenDetail: () => _openDetail(item),
                  onSave: () => _interact(() => _comingSoon('Salva')),
                  onShare: () => _interact(() => _comingSoon('Condividi')),
                  onContact: () => _interact(() => _openDetail(item)),
                  onOpenFilters: () => _interact(() => _comingSoon('Filtri')),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _FeedLoading extends StatelessWidget {
  const _FeedLoading();

  @override
  Widget build(BuildContext context) {
    Widget bar(double w, double h) => Container(
          width: w,
          height: h,
          decoration: BoxDecoration(
            color: const Color(0x29FFFFFF),
            borderRadius: BorderRadius.circular(8),
          ),
        );

    return Stack(
      children: [
        const Positioned.fill(child: ColoredBox(color: AppColors.feedVideoPlaceholder)),
        Positioned(
          left: AppSpacing.page,
          bottom: 72,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              bar(140, 14),
              const SizedBox(height: 10),
              bar(240, 22),
              const SizedBox(height: 10),
              bar(190, 14),
              const SizedBox(height: 10),
              bar(110, 24),
            ],
          ),
        ),
        const Center(
          child: SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
          ),
        ),
      ],
    );
  }
}

class _FeedMessage extends StatelessWidget {
  const _FeedMessage({
    required this.title,
    required this.body,
    required this.actionLabel,
    required this.onAction,
  });

  final String title;
  final String body;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: AppFonts.display,
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                body,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.onFeedSecondary, fontSize: 15, height: 1.45),
              ),
              const SizedBox(height: 20),
              FilledButton(onPressed: onAction, child: Text(actionLabel)),
            ],
          ),
        ),
      ),
    );
  }
}