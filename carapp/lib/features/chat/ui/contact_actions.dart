import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/router/routes.dart';
import '../../../core/supabase/supabase_client.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../../auth/ui/login_sheet.dart';
import '../../listing/data/listing_detail.dart';
import '../data/chat_repository.dart';
import '../state/inbox_controller.dart';

/// Guests sign in first. false = stop (sheet closed, or own listing).
Future<bool> _readyToContact(BuildContext context, WidgetRef ref, ListingDetail listing) async {
  if (ref.read(currentUserProvider) == null) {
    final ok = await showLoginSheet(context);
    if (!ok || !context.mounted) return false;
  }
  if (ref.read(currentUserIdProvider) == listing.ownerId) {
    _show(context, AppLocalizations.of(context).contactOwnListing);
    return false;
  }
  return true;
}

void _show(BuildContext context, String message) => ScaffoldMessenger.of(context)
  ..hideCurrentSnackBar()
  ..showSnackBar(SnackBar(content: Text(message)));

/// "Contatta": opens the chat about [listing] if the user already has
/// one (known from the Inbox, else one small lookup), otherwise the new
/// chat screen, where the first message creates it.
Future<void> contactSeller(BuildContext context, WidgetRef ref, ListingDetail listing) async {
  if (!await _readyToContact(context, ref, listing) || !context.mounted) return;

  final repo = ref.read(chatRepositoryProvider);
  final known = ref.read(inboxProvider).value?.forListing(listing.id);
  try {
    final id = known?.id ?? await repo.conversationIdForListing(listing.id);
    if (!context.mounted) return;
    context.push(id != null ? AppRoutes.chatPath(id) : AppRoutes.newChatPath(listing.id));
  } catch (_) {
    if (context.mounted) _show(context, AppLocalizations.of(context).contactError);
  }
}

/// The WhatsApp button: asks for the number (signed-in users only, the
/// call counts as a contact) and opens WhatsApp with a first message.
Future<void> openWhatsapp(BuildContext context, WidgetRef ref, ListingDetail listing) async {
  if (!await _readyToContact(context, ref, listing) || !context.mounted) return;

  final t = AppLocalizations.of(context);
  final repo = ref.read(chatRepositoryProvider);
  try {
    final number = await repo.sellerWhatsapp(listing.id);
    if (!context.mounted) return;
    final digits = number == null ? null : whatsappDigits(number);
    if (digits == null) {
      _show(context, t.whatsappNoNumber);
      return;
    }
    final uri = Uri.https('wa.me', '/$digits', {
      'text': t.whatsappPrefill(listing.title, t.appName),
    });
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && context.mounted) _show(context, t.whatsappError);
  } catch (_) {
    if (context.mounted) _show(context, t.whatsappError);
  }
}

/// wa.me wants the full international number, digits only.
/// "+39 333 123 4567", "0039…" and Italian numbers without prefix
/// ("333 1234567") all become "393331234567". null if unusable.
String? whatsappDigits(String raw) {
  final trimmed = raw.trim();
  var digits = trimmed.replaceAll(RegExp(r'\D'), '');
  if (trimmed.startsWith('+')) {
    // already international
  } else if (digits.startsWith('00')) {
    digits = digits.substring(2);
  } else if (digits.length >= 9 && digits.length <= 10 && (digits.startsWith('3') || digits.startsWith('0'))) {
    digits = '39$digits'; // Italian mobile (3…) or landline (0…)
  }
  return digits.length >= 8 && digits.length <= 15 ? digits : null;
}
