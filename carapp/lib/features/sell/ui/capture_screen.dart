import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/app_config.dart';
import '../../../core/router/routes.dart';
import '../../../core/theme/tokens.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../data/capture_step.dart';
import '../data/sell_draft.dart';
import '../data/sell_media.dart';
import '../state/sell_controller.dart';
import 'sell_labels.dart';
import 'silhouette.dart';

/// `/sell/capture` (screen 2): one step at a time, always a video (5 s,
/// stops by itself), with the step's outline over the camera. With
/// [photos] the same camera takes the guided carousel photos instead (one
/// per [PhotoSlot], all optional). After a shot it moves to the next one
/// still missing; with `single` (a retake from the summary) it goes back.
class CaptureScreen extends ConsumerStatefulWidget {
  const CaptureScreen({super.key, this.stepId, this.photos = false, this.single = false});

  /// Step id, or slot id with [photos].
  final String? stepId;
  final bool photos;
  final bool single;

  @override
  ConsumerState<CaptureScreen> createState() => _CaptureScreenState();
}

enum _CameraIssue { denied, failed }

/// What the camera is shooting: a video step or a photo slot.
class _Target {
  const _Target({required this.id, this.silhouette, this.plateTip = false, this.step});

  final String id;
  final String? silhouette;
  final bool plateTip;

  /// Video steps only.
  final CaptureStep? step;
}

class _CaptureScreenState extends ConsumerState<CaptureScreen>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  CameraController? _camera;
  _CameraIssue? _issue;
  late final AnimationController _progress = AnimationController(vsync: this);
  Timer? _stopTimer;

  String? _stepId;
  bool _recording = false;
  bool _saving = false;
  bool _torch = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final s = ref.read(sellControllerProvider);
    if (s.draft == null) {
      // Opened without a draft (e.g. the app was restarted here).
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.go(AppRoutes.sell);
      });
      return;
    }
    final targets = _targetsOf(s);
    _stepId = widget.stepId ?? targets.where((x) => !_isDone(s, x.id)).firstOrNull?.id ?? targets.first.id;
    _initCamera();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopTimer?.cancel();
    _progress.dispose();
    _camera?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final camera = _camera;
    if (state == AppLifecycleState.inactive || state == AppLifecycleState.paused) {
      if (camera == null) return;
      // An interrupted clip is thrown away: it would be shorter than 5 s.
      _stopTimer?.cancel();
      _progress.stop();
      _camera = null;
      camera.dispose();
      if (mounted) setState(() => _recording = false);
    } else if (state == AppLifecycleState.resumed && _camera == null && _stepId != null) {
      _initCamera();
    }
  }

  // ---- steps ----------------------------------------------------------

  bool get _photoMode => widget.photos;

  List<_Target> _targetsOf(SellState s) => _photoMode
      ? [for (final slot in s.slots) _Target(id: slot.id, silhouette: slot.silhouette, plateTip: slot.plateTip)]
      : [for (final step in s.steps) _Target(id: step.id, silhouette: step.silhouette, plateTip: step.plateTip, step: step)];

  bool _isDone(SellState s, String id) =>
      _photoMode ? s.draft!.photoFor(id) != null : s.draft!.shots.containsKey(id);

  /// The next target without a shot, after the current one, then from the
  /// start (skipped ones).
  _Target? _nextMissing() {
    final s = ref.read(sellControllerProvider);
    final targets = _targetsOf(s);
    final i = targets.indexWhere((x) => x.id == _stepId);
    for (var k = 1; k <= targets.length; k++) {
      final target = targets[(i + k) % targets.length];
      if (target.id != _stepId && !_isDone(s, target.id)) return target;
    }
    return null;
  }

  void _advance() {
    if (widget.single) {
      context.pop();
      return;
    }
    final next = _nextMissing();
    if (next == null) {
      _openShots();
    } else {
      setState(() => _stepId = next.id);
    }
  }

  void _openShots() {
    if (widget.single) {
      context.pop();
    } else {
      context.pushReplacement(AppRoutes.sellShots);
    }
  }

  void _close() {
    final hasShots = ref.read(sellControllerProvider).draft?.shots.isNotEmpty ?? false;
    if (hasShots && !widget.single && !_photoMode) {
      _openShots();
    } else {
      context.canPop() ? context.pop() : context.go(AppRoutes.sell);
    }
  }

  // ---- camera ---------------------------------------------------------

  Future<void> _initCamera() async {
    setState(() => _issue = null);
    final config = ref.read(appConfigProvider).value ?? AppConfig.empty;
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) throw CameraException('NoCamera', null);
      final back = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );
      final camera = CameraController(
        back,
        ResolutionPreset.veryHigh, // 1080p
        enableAudio: true, // the engine sound is part of the listing
        fps: config.mediaValue('video_fps', 30),
        videoBitrate: config.mediaValue('video_bitrate_kbps', 4500) * 1000,
      );
      await camera.initialize();
      await camera.lockCaptureOrientation(DeviceOrientation.portraitUp);
      if (!mounted) {
        await camera.dispose();
        return;
      }
      setState(() {
        _camera = camera;
        _torch = false;
      });
    } on CameraException catch (e) {
      if (!mounted) return;
      final denied = e.code.contains('AccessDenied') || e.code.contains('AccessRestricted');
      setState(() => _issue = denied ? _CameraIssue.denied : _CameraIssue.failed);
    }
  }

  Future<void> _toggleTorch() async {
    final camera = _camera;
    if (camera == null) return;
    final on = !_torch;
    try {
      await camera.setFlashMode(on ? FlashMode.torch : FlashMode.off);
      if (mounted) setState(() => _torch = on);
    } on CameraException {
      // No torch on this camera.
    }
  }

  Future<void> _shoot() async {
    final camera = _camera;
    if (camera == null || !camera.value.isInitialized || _saving || _recording) return;
    HapticFeedback.mediumImpact();

    if (_photoMode) {
      setState(() => _saving = true);
      try {
        final file = await camera.takePicture();
        await _save(file.path);
      } on CameraException {
        _failed();
      }
      return;
    }

    final seconds = ref.read(sellControllerProvider).steps.firstWhere((x) => x.id == _stepId).seconds;
    try {
      await camera.startVideoRecording();
    } on CameraException {
      _failed();
      return;
    }
    if (!mounted) return;
    setState(() => _recording = true);
    _progress
      ..duration = Duration(seconds: seconds)
      ..forward(from: 0);
    _stopTimer = Timer(Duration(seconds: seconds), _stopRecording);
  }

  Future<void> _stopRecording() async {
    final camera = _camera;
    if (camera == null || !_recording) return;
    setState(() {
      _recording = false;
      _saving = true;
    });
    try {
      final file = await camera.stopVideoRecording();
      await _save(file.path);
    } on CameraException {
      _failed();
    }
  }

  Future<void> _save(String path) async {
    final controller = ref.read(sellControllerProvider.notifier);
    final id = _stepId!;
    try {
      if (_photoMode) {
        await controller.addPhoto(id, path, fromCamera: true);
      } else {
        await controller.addClip(id, path);
      }
    } catch (_) {
      _failed();
      return;
    }
    if (!mounted) return;
    setState(() => _saving = false);
    HapticFeedback.lightImpact();
    _advance();
  }

  void _failed() {
    if (!mounted) return;
    setState(() {
      _saving = false;
      _recording = false;
    });
    _progress.reset();
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(AppLocalizations.of(context).captureSaveError)));
  }

  // ---- UI -------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final s = ref.watch(sellControllerProvider);
    final draft = s.draft;
    if (draft == null || _stepId == null) {
      return const Scaffold(backgroundColor: AppColors.feedBackground);
    }
    final targets = _targetsOf(s);
    final index = targets.indexWhere((x) => x.id == _stepId).clamp(0, targets.length - 1);
    final target = targets[index];
    final step = target.step;
    final seconds = step?.seconds ?? 0;
    final next = _recording || _saving ? null : _nextMissing();
    String label(String id) => _photoMode ? t.photoSlotLabel(id) : t.stepLabel(id);
    final done = {for (final x in targets) if (_isDone(s, x.id)) x.id};

    return PopScope(
      canPop: !_recording,
      child: Scaffold(
        backgroundColor: AppColors.feedBackground,
        body: Column(
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _Preview(camera: _camera, issue: _issue, onRetry: _initCamera),
                  if (_camera != null) Silhouette(name: target.silhouette),
                  const _TopScrim(),
                  SafeArea(
                    bottom: false,
                    child: Column(
                      children: [
                        _TopBar(
                          stepLabel: _photoMode
                              ? t.capturePhotoOf(index + 1, targets.length)
                              : t.captureStepOf(index + 1, targets.length),
                          torch: _torch,
                          onClose: _recording ? null : _close,
                          onTorch: _camera == null ? null : _toggleTorch,
                        ),
                        _Segments(ids: [for (final x in targets) x.id], current: index, done: done),
                        const SizedBox(height: AppSpacing.l),
                        Text(
                          label(target.id),
                          style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: AppSpacing.xxs),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
                          child: Text(
                            step == null ? t.photoSlotHint(target.id) : t.stepInstruction(step, draft.categoryId),
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: AppColors.onFeedSecondary, fontSize: 14),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: AppSpacing.l,
                    child: Center(
                      child: AnimatedBuilder(
                        animation: _progress,
                        builder: (context, _) => _StatusPill(
                          text: _recording
                              ? t.captureRecording(
                                  (seconds * (1 - _progress.value)).ceil().clamp(1, seconds),
                                )
                              : target.plateTip
                                  ? t.capturePlateTip
                                  : t.captureHoldStill,
                          live: _recording,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            _BottomPanel(
              photo: _photoMode,
              seconds: seconds,
              recording: _recording,
              saving: _saving,
              progress: _progress,
              enabled: _camera != null,
              lastShot: _lastShot(_photoMode ? draft.photos : draft.shots.values),
              draftId: draft.id,
              doneCount: done.length,
              total: targets.length,
              nextLabel: next == null ? t.captureLast : t.captureNext(label(next.id).toLowerCase()),
              onShoot: _shoot,
              onSkip: _recording || _saving ? null : _advance,
              onShots: _recording || _saving || (draft.shots.isEmpty && !_photoMode) ? null : _openShots,
            ),
          ],
        ),
      ),
    );
  }

  static Shot? _lastShot(Iterable<Shot> shots) {
    Shot? last;
    for (final shot in shots) {
      if (last == null || (shot.takenAt ?? DateTime(0)).isAfter(last.takenAt ?? DateTime(0))) last = shot;
    }
    return last;
  }
}

class _Preview extends StatelessWidget {
  const _Preview({required this.camera, required this.issue, required this.onRetry});

  final CameraController? camera;
  final _CameraIssue? issue;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final c = camera;
    if (issue != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xxl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.no_photography_outlined, color: Colors.white, size: 40),
              const SizedBox(height: AppSpacing.m),
              Text(
                issue == _CameraIssue.denied ? t.captureCameraDenied : t.captureCameraError,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 15),
              ),
              const SizedBox(height: AppSpacing.l),
              OutlinedButton(
                onPressed: onRetry,
                style: OutlinedButton.styleFrom(foregroundColor: Colors.white),
                child: Text(t.commonRetry),
              ),
            ],
          ),
        ),
      );
    }
    if (c == null || !c.value.isInitialized) {
      return const ColoredBox(color: AppColors.feedVideoPlaceholder);
    }
    // Fill the area (crop), like the final 9:16 video.
    return LayoutBuilder(
      builder: (context, box) {
        final portraitAspect = 1 / c.value.aspectRatio;
        return ClipRect(
          child: FittedBox(
            fit: BoxFit.cover,
            child: SizedBox(
              width: box.maxWidth,
              height: box.maxWidth / portraitAspect,
              child: CameraPreview(c),
            ),
          ),
        );
      },
    );
  }
}

class _TopScrim extends StatelessWidget {
  const _TopScrim();

  @override
  Widget build(BuildContext context) => const IgnorePointer(
        child: Align(
          alignment: Alignment.topCenter,
          child: SizedBox(
            height: 220,
            width: double.infinity,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xB3000000), Color(0x00000000)],
                ),
              ),
            ),
          ),
        ),
      );
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.stepLabel, required this.torch, this.onClose, this.onTorch});

  final String stepLabel;
  final bool torch;
  final VoidCallback? onClose;
  final VoidCallback? onTorch;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s, vertical: AppSpacing.xs),
      child: Row(
        children: [
          _GlassButton(
            icon: Icons.close,
            tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
            onTap: onClose,
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.m, vertical: AppSpacing.xs),
            decoration: BoxDecoration(
              color: AppColors.glassFill,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: AppColors.glassBorder),
            ),
            child: Text(
              stepLabel,
              style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
          const Spacer(),
          _GlassButton(
            icon: torch ? Icons.flash_on : Icons.flash_off,
            tooltip: t.captureTorch,
            onTap: onTorch,
          ),
        ],
      ),
    );
  }
}

class _GlassButton extends StatelessWidget {
  const _GlassButton({required this.icon, required this.tooltip, this.onTap});

  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: AppColors.glassFill,
        shape: const CircleBorder(side: BorderSide(color: AppColors.glassBorder)),
        child: IconButton(
          tooltip: tooltip,
          icon: Icon(icon, color: onTap == null ? AppColors.onFeedSecondary : Colors.white, size: 20),
          onPressed: onTap,
        ),
      );
}

/// One bar per step: blue = done, white = current, grey = to do.
class _Segments extends StatelessWidget {
  const _Segments({required this.ids, required this.current, required this.done});

  final List<String> ids;
  final int current;
  final Set<String> done;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.l, vertical: AppSpacing.xs),
        child: Row(
          children: [
            for (var i = 0; i < ids.length; i++) ...[
              if (i > 0) const SizedBox(width: 4),
              Expanded(
                child: Container(
                  height: 3,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(2),
                    color: i == current
                        ? Colors.white
                        : done.contains(ids[i])
                            ? AppColors.primary
                            : const Color(0x40FFFFFF),
                  ),
                ),
              ),
            ],
          ],
        ),
      );
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.text, required this.live});

  final String text;
  final bool live;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.m, vertical: AppSpacing.xs),
        decoration: BoxDecoration(
          color: const Color(0xCC000000),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: live ? const Color(0xFFEF4444) : AppColors.primary,
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            Text(text, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
          ],
        ),
      );
}

class _BottomPanel extends ConsumerWidget {
  const _BottomPanel({
    required this.photo,
    required this.seconds,
    required this.recording,
    required this.saving,
    required this.progress,
    required this.enabled,
    required this.lastShot,
    required this.draftId,
    required this.doneCount,
    required this.total,
    required this.nextLabel,
    required this.onShoot,
    this.onSkip,
    this.onShots,
  });

  /// Guided photos instead of the video steps.
  final bool photo;
  final int seconds;
  final bool recording;
  final bool saving;
  final Animation<double> progress;
  final bool enabled;
  final Shot? lastShot;
  final String draftId;
  final int doneCount;
  final int total;
  final String nextLabel;
  final VoidCallback onShoot;
  final VoidCallback? onSkip;
  final VoidCallback? onShots;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final busy = recording || saving;

    return Container(
      color: const Color(0xFF111316),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.xxl, AppSpacing.m, AppSpacing.xxl, AppSpacing.m),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _ModeLabel(label: photo ? t.capturePhoto : t.captureVideo(seconds)),
              const SizedBox(height: AppSpacing.l),
              Row(
                children: [
                  _ShotsButton(
                    shot: lastShot,
                    draftId: draftId,
                    label: '$doneCount/$total',
                    tooltip: t.captureShots,
                    onTap: onShots,
                  ),
                  const Spacer(),
                  _Shutter(
                    photo: photo,
                    recording: recording,
                    saving: saving,
                    progress: progress,
                    onTap: enabled && !busy ? onShoot : null,
                  ),
                  const Spacer(),
                  SizedBox.square(
                    dimension: 52,
                    child: Material(
                      color: const Color(0xFF2A2E35),
                      shape: const CircleBorder(),
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: onSkip,
                        child: Center(
                          child: Text(
                            t.captureSkip,
                            style: TextStyle(
                              color: onSkip == null ? AppColors.onFeedSecondary : Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.s),
              Text(nextLabel, style: const TextStyle(color: AppColors.onFeedSecondary, fontSize: 12)),
            ],
          ),
        ),
      ),
    );
  }
}

/// "Video · 5 s" or "Foto": what the shutter takes (no choice: steps
/// are always videos).
class _ModeLabel extends StatelessWidget {
  const _ModeLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.l, vertical: AppSpacing.xs),
        decoration: BoxDecoration(color: const Color(0xFF2A2E35), borderRadius: BorderRadius.circular(999)),
        child: Text(
          label,
          style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700),
        ),
      );
}

class _Shutter extends StatelessWidget {
  const _Shutter({
    required this.photo,
    required this.recording,
    required this.saving,
    required this.progress,
    this.onTap,
  });

  final bool photo;
  final bool recording;
  final bool saving;
  final Animation<double> progress;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final video = !photo;
    return Semantics(
      button: true,
      label: video ? AppLocalizations.of(context).captureRecord : AppLocalizations.of(context).captureTakePhoto,
      child: GestureDetector(
        onTap: onTap,
        child: SizedBox.square(
          dimension: 80,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 4),
                ),
              ),
              if (recording)
                SizedBox.expand(
                  child: AnimatedBuilder(
                    animation: progress,
                    builder: (context, _) => CircularProgressIndicator(
                      value: progress.value,
                      strokeWidth: 4,
                      color: const Color(0xFFEF4444),
                      backgroundColor: Colors.transparent,
                    ),
                  ),
                ),
              if (saving)
                const SizedBox.square(
                  dimension: 28,
                  child: CircularProgressIndicator(strokeWidth: 3, color: Colors.white),
                )
              else
                AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: recording ? 30 : 62,
                  height: recording ? 30 : 62,
                  decoration: BoxDecoration(
                    color: video ? const Color(0xFFEF4444) : Colors.white,
                    borderRadius: BorderRadius.circular(recording ? 8 : 31),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ShotsButton extends ConsumerWidget {
  const _ShotsButton({
    required this.shot,
    required this.draftId,
    required this.label,
    required this.tooltip,
    this.onTap,
  });

  final Shot? shot;
  final String draftId;
  final String label;
  final String tooltip;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final preview = shot == null ? null : (shot!.kind == ShotKind.photo ? shot!.file : shot!.thumb);
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: const Color(0xFF2A2E35),
            borderRadius: BorderRadius.circular(AppRadius.s),
            border: Border.all(color: Colors.white54),
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (preview != null) ShotImage(draftId: draftId, file: preview, width: 52),
              Align(
                alignment: Alignment.bottomCenter,
                child: Container(
                  width: double.infinity,
                  color: const Color(0x99000000),
                  padding: const EdgeInsets.symmetric(vertical: 1),
                  child: Text(
                    label,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A file of the draft folder as an image (thumbnails, photos).
class ShotImage extends ConsumerWidget {
  const ShotImage({super.key, required this.draftId, required this.file, required this.width});

  final String draftId;
  final String file;
  final double width;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final path = ref.watch(draftFilePathProvider((draftId, file))).value;
    if (path == null) return const SizedBox.shrink();
    final ratio = MediaQuery.devicePixelRatioOf(context);
    return Image.file(
      File(path),
      fit: BoxFit.cover,
      cacheWidth: (width * ratio).round(),
      gaplessPlayback: true,
      errorBuilder: (_, _, _) => const SizedBox.shrink(),
    );
  }
}
