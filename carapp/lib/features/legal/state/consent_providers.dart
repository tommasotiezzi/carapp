import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/supabase/supabase_client.dart';
import '../data/consents.dart';

/// The signed-in user's latest consent per kind; empty for guests.
final currentConsentsProvider = FutureProvider<Map<ConsentKind, ConsentState>>((ref) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return const {};
  return ref.read(consentRepositoryProvider).fetchCurrent();
});

/// True while the login sheet is signing in and recording the consents
/// ticked at sign up: the consent sheet must not open over it meanwhile.
class ConsentGateHold extends Notifier<bool> {
  @override
  bool build() => false;

  void set(bool hold) => state = hold;
}

final consentGateHoldProvider = NotifierProvider<ConsentGateHold, bool>(ConsentGateHold.new);

/// The consent sheet must be shown. Never blocks on errors (e.g. the
/// consents table not migrated yet): the app stays usable.
final consentNeededProvider = Provider<bool>((ref) {
  if (ref.watch(currentUserIdProvider) == null) return false;
  if (ref.watch(consentGateHoldProvider)) return false;
  final current = ref.watch(currentConsentsProvider);
  if (!current.hasValue || current.isLoading) return false;
  final config = ref.watch(appConfigProvider).value ?? AppConfig.empty;
  return consentNeeded(current.value!, LegalVersions.of(config));
});
