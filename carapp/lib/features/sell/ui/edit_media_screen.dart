import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/tokens.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../data/sell_repository.dart';
import '../state/sell_controller.dart';
import 'shots_screen.dart';

/// `/listing/:id/media`: "Foto e video" of a listing already online. The
/// summary of the sell flow on its own draft ([mediaEditControllerProvider]):
/// the online photos to keep, replace or remove, the video to shoot again
/// or keep. Leaving with changes asks first (and drops them).
class EditMediaScreen extends ConsumerStatefulWidget {
  const EditMediaScreen({super.key, required this.listingId});

  final String listingId;

  @override
  ConsumerState<EditMediaScreen> createState() => _EditMediaScreenState();
}

class _EditMediaScreenState extends ConsumerState<EditMediaScreen> {
  Object? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    final controller = ref.read(mediaEditControllerProvider.notifier);
    final current = ref.read(mediaEditControllerProvider).draft;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      if (current?.id != widget.listingId) await controller.startEdit(widget.listingId);
      if (mounted) setState(() => _loading = false);
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = e;
        });
      }
    }
  }

  Future<void> _leave() async {
    final t = AppLocalizations.of(context);
    final controller = ref.read(mediaEditControllerProvider.notifier);
    final router = GoRouter.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(t.editMediaLeaveTitle),
        content: Text(t.editMediaLeaveBody),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(t.editMediaStay)),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(t.editMediaLeave, style: const TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await controller.discard();
    router.pop();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final draft = ref.watch(mediaEditControllerProvider.select((s) => s.draft));

    if (_loading || _error != null || draft == null || draft.id != widget.listingId) {
      final notEditable = _error is PublishException &&
          (_error! as PublishException).failure == PublishFailure.notEditable;
      return Scaffold(
        backgroundColor: AppColors.surface,
        appBar: AppBar(),
        body: Center(
          child: _error == null
              ? const CircularProgressIndicator()
              : Padding(
                  padding: const EdgeInsets.all(AppSpacing.xxl),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(notEditable ? t.editListingNotFound : t.errorBody, textAlign: TextAlign.center),
                      const SizedBox(height: AppSpacing.l),
                      FilledButton(
                        onPressed: notEditable ? () => context.pop() : _start,
                        child: Text(notEditable ? t.commonClose : t.commonRetry),
                      ),
                    ],
                  ),
                ),
        ),
      );
    }

    return PopScope(
      canPop: !draft.hasEdits,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _leave();
      },
      child: ShotsScreen(provider: mediaEditControllerProvider),
    );
  }
}
