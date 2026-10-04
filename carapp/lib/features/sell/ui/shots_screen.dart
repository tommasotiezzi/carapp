import 'package:flutter/material.dart';
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
import 'capture_screen.dart' show ShotImage;
import 'sell_labels.dart';

/// `/sell/shots` (screen 3): every step with its shot, tap to retake or
/// to add a missing one. "Crea il video" starts the video in the
/// background and opens "Dati e prezzo".
class ShotsScreen extends ConsumerWidget {
  const ShotsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final s = ref.watch(sellControllerProvider);
    final draft = s.draft;
    // No draft: just published (this page is leaving), or discarded.
    if (draft == null) return const Scaffold(backgroundColor: AppColors.surface);

    final done = s.steps.where((step) => draft.shots.containsKey(step.id)).length;
    final missing = draft.missingIn(s.steps);
    final ready = draft.readyIn(s.steps);
    final hasDefectsStep = s.steps.any((step) => step.id == 'defects');
    final blocker = missing.isNotEmpty
        ? t.shotsMissing(missing.map((step) => t.stepLabel(step.id)).join(', '))
        : draft.videosIn(s.steps).isEmpty
            ? t.shotsNeedVideo
            : null;

    void capture(CaptureStep step) =>
        context.push(AppRoutes.sellCapturePath(step: step.id, single: true));

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        leading: IconButton(
          tooltip: MaterialLocalizations.of(context).backButtonTooltip,
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.canPop() ? context.pop() : context.go(AppRoutes.sell),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(AppSpacing.page, 0, AppSpacing.page, AppSpacing.xl),
        children: [
          Text(t.shotsTitle, style: text.headlineSmall),
          const SizedBox(height: AppSpacing.xs),
          Text(t.shotsSubtitle(done, s.steps.length), style: text.bodyMedium),
          const SizedBox(height: AppSpacing.l),
          for (final step in s.steps) ...[
            _StepTile(
              step: step,
              shot: draft.shots[step.id],
              draftId: draft.id,
              onCapture: () => capture(step),
              onRetake: () => capture(step),
              onDelete: step.required
                  ? null
                  : () => ref.read(sellControllerProvider.notifier).removeShot(step.id),
            ),
            const SizedBox(height: AppSpacing.s),
          ],
          if (hasDefectsStep && !draft.shots.containsKey('defects')) ...[
            const SizedBox(height: AppSpacing.xs),
            Container(
              padding: const EdgeInsets.all(AppSpacing.m),
              decoration: BoxDecoration(
                color: AppColors.primarySoft,
                borderRadius: BorderRadius.circular(AppRadius.s),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.auto_awesome_outlined, size: 18, color: AppColors.primary),
                  const SizedBox(width: AppSpacing.s),
                  Expanded(child: Text(t.shotsDefectsTip, style: text.bodySmall)),
                ],
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.xl),
          _ExtraPhotos(draft: draft),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.page, AppSpacing.s, AppSpacing.page, AppSpacing.m),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (blocker != null) ...[
                Text(blocker, style: text.bodySmall?.copyWith(color: AppColors.danger), textAlign: TextAlign.center),
                const SizedBox(height: AppSpacing.s),
              ],
              FilledButton(
                onPressed: ready
                    ? () {
                        ref.read(sellControllerProvider.notifier).startMedia();
                        context.push(AppRoutes.sellDetails);
                      }
                    : null,
                child: Text(t.shotsCreate),
              ),
              const SizedBox(height: AppSpacing.s),
              Text(t.shotsCreateNote, style: text.bodySmall, textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }
}

/// "Foto aggiuntive": optional photos for the carousel (camera or
/// gallery), besides the steps. Tap a photo to remove it.
class _ExtraPhotos extends ConsumerWidget {
  const _ExtraPhotos({required this.draft});

  final SellDraft draft;

  static const _size = 76.0;

  Future<void> _add(BuildContext context, WidgetRef ref) async {
    final t = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final controller = ref.read(sellControllerProvider.notifier);
    final pick = ref.read(extraPhotoPickerProvider);
    final maxSide = (ref.read(appConfigProvider).value ?? AppConfig.empty).mediaValue('photo_max_long_side', 2560);
    final room = SellDraft.maxExtras - draft.extras.length;

    final source = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: Text(t.extraPhotosCamera),
              onTap: () => Navigator.pop(context, 'camera'),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: Text(t.extraPhotosGallery),
              onTap: () => Navigator.pop(context, 'gallery'),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;
    try {
      final paths = await pick(camera: source == 'camera', limit: room, maxSide: maxSide);
      if (paths.isEmpty) return;
      final added = await controller.addExtraPhotos(paths);
      if (added < paths.length) {
        messenger
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(t.extraPhotosLimit(SellDraft.maxExtras))));
      }
    } catch (_) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(t.extraPhotosError)));
    }
  }

  Future<void> _remove(BuildContext context, WidgetRef ref, Shot shot) async {
    final t = AppLocalizations.of(context);
    final controller = ref.read(sellControllerProvider.notifier);
    final remove = await showModalBottomSheet<bool>(
      context: context,
      builder: (context) => SafeArea(
        child: ListTile(
          leading: const Icon(Icons.delete_outline, color: AppColors.danger),
          title: Text(t.shotsDelete, style: const TextStyle(color: AppColors.danger)),
          onTap: () => Navigator.pop(context, true),
        ),
      ),
    );
    if (remove == true) await controller.removeExtraPhoto(shot.file);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final extras = draft.extras;
    final full = extras.length >= SellDraft.maxExtras;

    return Column(
      key: const ValueKey('extra-photos'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(t.extraPhotosTitle, style: text.titleMedium),
        const SizedBox(height: 2),
        Text(t.extraPhotosHint(SellDraft.maxExtras), style: text.bodySmall),
        const SizedBox(height: AppSpacing.m),
        Wrap(
          spacing: AppSpacing.s,
          runSpacing: AppSpacing.s,
          children: [
            for (final shot in extras)
              InkWell(
                borderRadius: BorderRadius.circular(AppRadius.s),
                onTap: () => _remove(context, ref, shot),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.s),
                  child: Container(
                    width: _size,
                    height: _size,
                    color: AppColors.placeholder,
                    child: ShotImage(draftId: draft.id, file: shot.file, width: _size),
                  ),
                ),
              ),
            if (!full)
              InkWell(
                borderRadius: BorderRadius.circular(AppRadius.s),
                onTap: () => _add(context, ref),
                child: CustomPaint(
                  painter: _DashedBorder(radius: AppRadius.s),
                  child: SizedBox(
                    width: _size,
                    height: _size,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.add_a_photo_outlined, color: AppColors.inkSecondary),
                        const SizedBox(height: 4),
                        Text(t.extraPhotosAdd, style: text.labelSmall),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _StepTile extends StatelessWidget {
  const _StepTile({
    required this.step,
    required this.shot,
    required this.draftId,
    required this.onCapture,
    required this.onRetake,
    this.onDelete,
  });

  final CaptureStep step;
  final Shot? shot;
  final String draftId;
  final VoidCallback onCapture;
  final VoidCallback onRetake;
  final VoidCallback? onDelete;

  Future<void> _actions(BuildContext context) async {
    final t = AppLocalizations.of(context);
    final choice = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.videocam_outlined),
              title: Text(t.shotsRetake),
              onTap: () => Navigator.pop(context, 'retake'),
            ),
            if (onDelete != null)
              ListTile(
                leading: const Icon(Icons.delete_outline, color: AppColors.danger),
                title: Text(t.shotsDelete, style: const TextStyle(color: AppColors.danger)),
                onTap: () => Navigator.pop(context, 'delete'),
              ),
          ],
        ),
      ),
    );
    if (choice == 'retake') onRetake();
    if (choice == 'delete') onDelete?.call();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final s = shot;
    final engineOn = step.hint == 'engine_running_show_km';

    if (s == null && !step.required) {
      // Optional and not taken: dashed "+" row.
      return InkWell(
        borderRadius: BorderRadius.circular(AppRadius.m),
        onTap: onCapture,
        child: CustomPaint(
          painter: _DashedBorder(),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.m),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceAlt,
                    borderRadius: BorderRadius.circular(AppRadius.s),
                  ),
                  child: const Icon(Icons.add, color: AppColors.inkSecondary),
                ),
                const SizedBox(width: AppSpacing.m),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(t.stepLabel(step.id), style: text.titleSmall),
                      const SizedBox(height: 2),
                      Text(
                        step.id == 'defects' ? t.shotsOptionalDefects : t.shotsOptional,
                        style: text.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final subtitle = s == null
        ? t.shotsTodo
        : [
            s.kind == ShotKind.video ? t.shotsVideo(step.seconds) : t.shotsPhoto,
            if (engineOn && s.kind == ShotKind.video) t.shotsEngineOn,
          ].join(' · ');
    final preview = s == null ? null : (s.kind == ShotKind.photo ? s.file : s.thumb);

    return Material(
      color: AppColors.surfaceAlt,
      borderRadius: BorderRadius.circular(AppRadius.m),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.m),
        onTap: s == null ? onCapture : () => _actions(context),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.m),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.s),
                child: Container(
                  width: 52,
                  height: 52,
                  color: AppColors.placeholder,
                  child: preview == null
                      ? Icon(
                          s == null ? Icons.videocam_outlined : Icons.movie_outlined,
                          color: AppColors.inkMuted,
                        )
                      : ShotImage(draftId: draftId, file: preview, width: 52),
                ),
              ),
              const SizedBox(width: AppSpacing.m),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(t.stepLabel(step.id), style: text.titleSmall),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: text.bodySmall?.copyWith(color: s == null ? AppColors.danger : null),
                    ),
                  ],
                ),
              ),
              if (s != null)
                const Icon(Icons.check_circle, color: AppColors.primary)
              else
                const Icon(Icons.chevron_right, color: AppColors.inkMuted),
            ],
          ),
        ),
      ),
    );
  }
}

class _DashedBorder extends CustomPainter {
  _DashedBorder({this.radius = AppRadius.m});

  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.borderStrong
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    final path = Path()
      ..addRRect(RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(radius)));
    for (final metric in path.computeMetrics()) {
      var d = 0.0;
      while (d < metric.length) {
        canvas.drawPath(metric.extractPath(d, d + 6), paint);
        d += 10;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBorder oldDelegate) => oldDelegate.radius != radius;
}
