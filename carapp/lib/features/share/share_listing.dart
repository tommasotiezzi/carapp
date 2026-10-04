import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/analytics/event_tracker.dart';
import '../../core/config/app_config.dart';
import '../../core/config/env.dart';
import '../../core/utils/formatters.dart';
import '../../l10n/gen/app_localizations.dart';

/// The link sent when a listing is shared. With `app_config.share.base_url`
/// (the share site, see `site/`) it is `<base>/l/<id>`: it opens in any
/// browser, shows a preview in chats and opens the app. Without it, the
/// app link (works only where the app is installed).
String listingShareLink(AppConfig config, String listingId) {
  final base = config.shareBaseUrl;
  if (base != null) return '$base/l/$listingId';
  return '${Env.deepLinkScheme}://app/listing/$listingId';
}

/// "Volkswagen Golf · 2019 · € 14.900 · Milano"
String listingShareSummary({
  required String? makeName,
  required String? modelName,
  int? year,
  int? priceCents,
  String? city,
}) {
  String join(List<String?> parts, String separator) =>
      parts.whereType<String>().where((s) => s.trim().isNotEmpty).join(separator);
  return join([join([makeName, modelName], ' '), year?.toString(), Formatters.price(priceCents), city], ' · ');
}

/// The Share button (feed and listing): the phone's share sheet with a
/// short text and the link. A `share` event is tracked unless the sheet
/// was dismissed.
Future<void> shareListing(
  BuildContext context,
  WidgetRef ref, {
  required String listingId,
  required String summary,
}) async {
  final t = AppLocalizations.of(context);
  final messenger = ScaffoldMessenger.of(context);
  final tracker = ref.read(eventTrackerProvider);
  final config = ref.read(appConfigProvider).value ?? AppConfig.empty;
  final link = listingShareLink(config, listingId);

  // iPad shows the sheet as a popover anchored here.
  final box = context.findRenderObject() as RenderBox?;
  final origin = box != null && box.hasSize ? box.localToGlobal(Offset.zero) & box.size : null;

  try {
    final result = await SharePlus.instance.share(ShareParams(
      text: t.shareText(summary, t.appName, link),
      subject: summary,
      sharePositionOrigin: origin,
    ));
    if (result.status != ShareResultStatus.dismissed) {
      tracker.track(AnalyticsEvent.share, listingId: listingId);
    }
  } catch (_) {
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(t.shareError)));
  }
}
