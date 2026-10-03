import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../../../core/theme/tokens.dart';

/// Full-screen video of one listing.
/// - shows the cover instantly, the video fades in once ready
/// - tap: pause / resume
/// - pinch or double tap: zoom on the paused frame; releasing resumes
class FeedVideoView extends StatefulWidget {
  const FeedVideoView({
    super.key,
    required this.controller,
    required this.coverUrl,
    required this.onZoom,
  });

  final VideoPlayerController? controller;
  final String? coverUrl;
  final VoidCallback onZoom;

  @override
  State<FeedVideoView> createState() => _FeedVideoViewState();
}

class _FeedVideoViewState extends State<FeedVideoView>
    with SingleTickerProviderStateMixin {
  final _transform = TransformationController();
  late final AnimationController _resetAnim;
  Animation<Matrix4>? _resetTween;
  bool _pausedByUser = false;
  bool _zooming = false;
  TapDownDetails? _doubleTapDetails;

  @override
  void initState() {
    super.initState();
    _resetAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    )..addListener(() {
        if (_resetTween != null) _transform.value = _resetTween!.value;
      });
  }

  @override
  void dispose() {
    _resetAnim.dispose();
    _transform.dispose();
    super.dispose();
  }

  VideoPlayerController? get _video => widget.controller;

  void _togglePause() {
    final v = _video;
    if (v == null || !v.value.isInitialized) return;
    setState(() {
      if (v.value.isPlaying) {
        v.pause();
        _pausedByUser = true;
      } else {
        v.play();
        _pausedByUser = false;
      }
    });
  }

  void _zoomStarted() {
    if (_zooming) return;
    _zooming = true;
    _video?.pause();
    widget.onZoom();
  }

  void _zoomEnded() {
    _zooming = false;
    _resetTween = Matrix4Tween(begin: _transform.value, end: Matrix4.identity())
        .animate(CurvedAnimation(parent: _resetAnim, curve: Curves.easeOut));
    _resetAnim.forward(from: 0);
    if (!_pausedByUser) _video?.play();
  }

  void _onDoubleTap() {
    final pos = _doubleTapDetails?.localPosition;
    if (pos == null) return;
    if (_transform.value != Matrix4.identity()) {
      _zoomEnded();
      return;
    }
    _zoomStarted();
    const scale = 2.2;
    _transform.value = Matrix4.identity()
      ..translate(-pos.dx * (scale - 1), -pos.dy * (scale - 1))
      ..scale(scale);
  }

  @override
  Widget build(BuildContext context) {
    final v = _video;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _togglePause,
      onDoubleTapDown: (d) => _doubleTapDetails = d,
      onDoubleTap: _onDoubleTap,
      child: InteractiveViewer(
        transformationController: _transform,
        minScale: 1,
        maxScale: 4,
        panEnabled: false,
        clipBehavior: Clip.hardEdge,
        onInteractionStart: (d) {
          if (d.pointerCount >= 2) _zoomStarted();
        },
        onInteractionEnd: (_) {
          if (_zooming) _zoomEnded();
        },
        child: Stack(
          fit: StackFit.expand,
          children: [
            const ColoredBox(color: AppColors.feedVideoPlaceholder),
            if (widget.coverUrl != null)
              CachedNetworkImage(
                imageUrl: widget.coverUrl!,
                fit: BoxFit.cover,
                fadeInDuration: Duration.zero,
                errorWidget: (_, __, ___) => const SizedBox.shrink(),
              ),
            if (v != null)
              ValueListenableBuilder<VideoPlayerValue>(
                valueListenable: v,
                builder: (context, value, _) {
                  final ready = value.isInitialized;
                  return AnimatedOpacity(
                    opacity: ready ? 1 : 0,
                    duration: const Duration(milliseconds: 180),
                    child: ready
                        ? FittedBox(
                            fit: BoxFit.cover,
                            clipBehavior: Clip.hardEdge,
                            child: SizedBox(
                              width: value.size.width,
                              height: value.size.height,
                              child: VideoPlayer(v),
                            ),
                          )
                        : const SizedBox.shrink(),
                  );
                },
              ),
            if (_pausedByUser)
              const Center(
                child: Icon(Icons.play_arrow_rounded, size: 84, color: Color(0xCCFFFFFF)),
              ),
            // Progress shows only while paused: during playback a bar at the
            // bottom edge reads like a loading indicator.
            if (v != null && _pausedByUser)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: VideoProgressIndicator(
                  v,
                  allowScrubbing: false,
                  padding: EdgeInsets.zero,
                  colors: const VideoProgressColors(
                    playedColor: Colors.white,
                    bufferedColor: Color(0x40FFFFFF),
                    backgroundColor: Color(0x1FFFFFFF),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}