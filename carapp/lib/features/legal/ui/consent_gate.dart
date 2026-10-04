import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/theme/tokens.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../../auth/data/auth_repository.dart';
import '../data/consents.dart';
import '../state/consent_providers.dart';
import 'consent_checks.dart';

/// Wraps the app shell: when a signed-in user has not accepted the
/// current Termini / Privacy (new account from another device, documents
/// updated), a sheet asks for it. It cannot be dismissed: accept, or sign
/// out. Guests are never asked (they accept when they sign up).
class ConsentGate extends ConsumerStatefulWidget {
  const ConsentGate({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<ConsentGate> createState() => _ConsentGateState();
}

class _ConsentGateState extends ConsumerState<ConsentGate> {
  bool _showing = false;

  @override
  void initState() {
    super.initState();
    ref.listenManual(consentNeededProvider, (_, needed) {
      if (needed) _show();
    }, fireImmediately: true);
  }

  Future<void> _show() async {
    if (_showing) return;
    _showing = true;
    // After the current frame: the listener can fire during a build.
    await Future<void>.delayed(Duration.zero);
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      isDismissible: false,
      enableDrag: false,
      builder: (_) => const PopScope(canPop: false, child: _ConsentSheet()),
    );
    _showing = false;
    // Still needed (e.g. the write failed): ask again.
    if (mounted && ref.read(consentNeededProvider)) _show();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class _ConsentSheet extends ConsumerStatefulWidget {
  const _ConsentSheet();

  @override
  ConsumerState<_ConsentSheet> createState() => _ConsentSheetState();
}

class _ConsentSheetState extends ConsumerState<_ConsentSheet> {
  bool _terms = false;
  bool _privacy = false;
  late bool _marketing =
      ref.read(currentConsentsProvider).value?[ConsentKind.marketingEmail]?.granted ?? false;
  bool _busy = false;
  String? _error;

  Future<void> _accept() async {
    final t = AppLocalizations.of(context);
    final repo = ref.read(consentRepositoryProvider);
    final config = ref.read(appConfigProvider).value ?? AppConfig.empty;
    final container = ProviderScope.containerOf(context, listen: false);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await repo.record(ConsentChoices(marketingEmail: _marketing), LegalVersions.of(config));
      container.invalidate(currentConsentsProvider);
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (mounted) setState(() => _error = t.errorBody);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _signOut() async {
    final auth = ref.read(authRepositoryProvider);
    Navigator.of(context).pop();
    await auth.signOut();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    // Accepted an older version before: say what changed.
    final updated = ref.watch(currentConsentsProvider).value?[ConsentKind.terms]?.granted ?? false;

    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.xl, AppSpacing.l, AppSpacing.xl, AppSpacing.xl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(updated ? t.consentUpdatedTitle : t.consentTitle, style: text.headlineSmall),
          const SizedBox(height: AppSpacing.s),
          Text(updated ? t.consentUpdatedBody : t.consentBody, style: text.bodyMedium),
          const SizedBox(height: AppSpacing.l),
          ConsentChecks(
            terms: _terms,
            privacy: _privacy,
            marketing: _marketing,
            onTerms: (v) => setState(() => _terms = v),
            onPrivacy: (v) => setState(() => _privacy = v),
            onMarketing: (v) => setState(() => _marketing = v),
          ),
          if (_error != null) ...[
            const SizedBox(height: AppSpacing.s),
            Text(_error!, style: const TextStyle(color: AppColors.danger, fontSize: 13)),
          ],
          const SizedBox(height: AppSpacing.l),
          FilledButton(
            onPressed: _busy || !ConsentChecks.requiredAccepted(terms: _terms, privacy: _privacy)
                ? null
                : _accept,
            child: _busy
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                  )
                : Text(t.consentAccept),
          ),
          TextButton(onPressed: _busy ? null : _signOut, child: Text(t.profileLogout)),
        ],
      ),
    );
  }
}
