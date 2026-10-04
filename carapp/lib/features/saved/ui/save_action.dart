import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase/supabase_client.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../../auth/ui/login_sheet.dart';
import '../state/saved_controller.dart';

/// The Save button action, shared by the feed and the listing screen.
/// Guests get the login sheet first; after login the listing is saved
/// (never un-saved, even if it was already saved from another device).
Future<void> toggleSave(
  BuildContext context,
  WidgetRef ref, {
  required String listingId,
  required int? priceCents,
}) async {
  final t = AppLocalizations.of(context);
  final saved = !ref.read(isSavedProvider(listingId));

  if (ref.read(currentUserProvider) == null) {
    final ok = await showLoginSheet(context);
    if (!ok || !context.mounted) return;
  }

  final messenger = ScaffoldMessenger.of(context);
  void show(String message) => messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));

  try {
    await ref
        .read(savedControllerProvider.notifier)
        .setSaved(listingId: listingId, saved: saved, priceCents: priceCents);
    show(saved ? t.savedAdded : t.savedRemoved);
  } catch (_) {
    show(t.savedError);
  }
}
