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
          _Photos(draft: draft, slots: s.slots),
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

/// The carousel photos, all optional: one tile per [PhotoSlot] (taken
/// with the guided camera or picked from the gallery), then "Altre foto".
class _Photos extends ConsumerWidget {
  const _Photos({required this.draft, required this.slots});

  final SellDraft draft;
  final List<PhotoSlot> slots;

  static const _extraSize = 76.0;

  Future<List<String>> _pick(WidgetRef ref, {required bool camera, required int limit}) {
    final maxSide = (ref.read(appConfigProvider).value ?? AppConfig.empty).mediaValue('photo_max_long_side', 2560);
    return ref.read(photoPickerProvider)(camera: camera, limit: limit, maxSide: maxSide);
  }

  void _error(ScaffoldMessengerState messenger, String text) => messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text)));

  /// A slot: guided camera, gallery, or remove.
  Future<void> _slotActions(BuildContext context, WidgetRef ref, PhotoSlot slot) async {
    final t = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final controller = ref.read(sellControllerProvider.notifier);
    final taken = draft.photoFor(slot.id);
    final choice = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text(t.photoSlotLabel(slot.id), style: Theme.of(context).textTheme.titleSmall),
              subtitle: Text(t.photoSlotHint(slot.id)),
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: Text(t.photosShootGuided),
              onTap: () => Navigator.pop(context, 'camera'),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: Text(t.extraPhotosGallery),
              onTap: () => Navigator.pop(context, 'gallery'),
            ),
            if (taken != null)
              ListTile(
                leading: const Icon(Icons.delete_outline, color: AppColors.danger),
                title: Text(t.shotsDelete, style: const TextStyle(color: AppColors.danger)),
                onTap: () => Navigator.pop(context, 'delete'),
              ),
          ],
        ),
      ),
    );
    if (!context.mounted || choice == null) return;
    switch (choice) {
      case 'camera':
        context.push(AppRoutes.sellCapturePath(step: slot.id, photos: true, single: true));
      case 'delete':
        await controller.removePhoto(taken!.file);
      case 'gallery':
        try {
          final paths = await _pick(ref, camera: false, limit: 1);
          if (paths.isNotEmpty) await controller.addPhoto(slot.id, paths.first, fromCamera: false);
        } catch (_) {
          _error(messenger, t.extraPhotosError);
        }
    }
  }

  Future<void> _addExtra(BuildContext context, WidgetRef ref) async {
    final t = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final controller = ref.read(sellControllerProvider.notifier);
    final room = SellDraft.maxExtras - draft.extraPhotos.length;

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
      final paths = await _pick(ref, camera: source == 'camera', limit: room);
      if (paths.isEmpty) return;
      final added = await controller.addExtraPhotos(paths);
      if (added < paths.length) _error(messenger, t.extraPhotosLimit(SellDraft.maxExtras));
    } catch (_) {
      _error(messenger, t.extraPhotosError);
    }
  }

  Future<void> _removeExtra(BuildContext context, WidgetRef ref, Shot shot) async {
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
    if (remove == true) await controller.removePhoto(shot.file);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final extras = draft.extraPhotos;
    final full = extras.length >= SellDraft.maxExtras;
    final anyMissing = slots.any((slot) => draft.photoFor(slot.id) == null);

    return Column(
      key: const ValueKey('photos'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(t.photosTitle, style: text.titleMedium),
        const SizedBox(height: 2),
        Text(t.photosHint, style: text.bodySmall),
        const SizedBox(height: AppSpacing.m),
        if (anyMissing) ...[
          OutlinedButton.icon(
            onPressed: () => context.push(AppRoutes.sellCapturePath(photos: true)),
            icon: const Icon(Icons.photo_camera_outlined),
            label: Text(t.photosShootGuided),
          ),
          const SizedBox(height: AppSpacing.m),
        ],
        GridView.count(
          crossAxisCount: 3,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: AppSpacing.s,
          crossAxisSpacing: AppSpacing.s,
          childAspectRatio: 0.78,
          children: [
            for (final slot in slots)
              _SlotTile(
                label: t.photoSlotLabel(slot.id),
                shot: draft.photoFor(slot.id),
                draftId: draft.id,
                onTap: () => _slotActions(context, ref, slot),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.l),
        Text(t.photosOther, style: text.titleSmall),
        const SizedBox(height: 2),
        Text(t.extraPhotosHint(SellDraft.maxExtras), style: text.bodySmall),
        const SizedBox(height: AppSpacing.s),
        Wrap(
          spacing: AppSpacing.s,
          runSpacing: AppSpacing.s,
          children: [
            for (final shot in extras)
              InkWell(
                borderRadius: BorderRadius.circular(AppRadius.s),
                onTap: () => _removeExtra(context, ref, shot),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.s),
                  child: Container(
                    width: _extraSize,
                    height: _extraSize,
                    color: AppColors.placeholder,
                    child: ShotImage(draftId: draft.id, file: shot.file, width: _extraSize),
                  ),
                ),
              ),
            if (!full)
              InkWell(
                borderRadius: BorderRadius.circular(AppRadius.s),
                onTap: () => _addExtra(context, ref),
                child: CustomPaint(
                  painter: _DashedBorder(radius: AppRadius.s),
                  child: SizedBox(
                    width: _extraSize,
                    height: _extraSize,
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

/// One suggested photo: its picture, or a dashed "+" with the name.
class _SlotTile extends StatelessWidget {
  const _SlotTile({required this.label, required this.shot, required this.draftId, required this.onTap});

  final String label;
  final Shot? shot;
  final String draftId;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final s = shot;
    return InkWell(
      borderRadius: BorderRadius.circular(AppRadius.s),
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: s == null
                ? CustomPaint(
                    painter: _DashedBorder(radius: AppRadius.s),
                    child: const Center(child: Icon(Icons.add_a_photo_outlined, color: AppColors.inkSecondary)),
                  )
                : Stack(
                    fit: StackFit.expand,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(AppRadius.s),
                        child: ColoredBox(
                          color: AppColors.placeholder,
                          child: ShotImage(draftId: draftId, file: s.file, width: 120),
                        ),
                      ),
                      const Positioned(
                        right: 4,
                        top: 4,
                        child: Icon(Icons.check_circle, color: AppColors.primary, size: 20),
                      ),
                    ],
                  ),
          ),
          const SizedBox(height: 4),
          Text(label, style: text.labelSmall, maxLines: 2, overflow: TextOverflow.ellipsis),
        ],
      ),
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
            t.shotsVideo(step.seconds),
            if (engineOn) t.shotsEngineOn,
          ].join(' · ');
    final preview = s?.thumb;

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
