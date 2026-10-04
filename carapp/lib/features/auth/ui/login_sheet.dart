import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/theme/tokens.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../../legal/data/consents.dart';
import '../../legal/state/consent_providers.dart';
import '../../legal/ui/consent_checks.dart';
import '../../onboarding/state/onboarding_controller.dart';
import '../data/auth_repository.dart';
import 'auth_messages.dart';

/// Opens the login sheet. Returns true when the user is signed in.
/// Use it anywhere an action needs an account (save, contact, dealer...).
Future<bool> showLoginSheet(BuildContext context, {String? title, String? subtitle}) async {
  final result = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _LoginSheet(title: title, subtitle: subtitle),
  );
  return result ?? false;
}

class _LoginSheet extends ConsumerStatefulWidget {
  const _LoginSheet({this.title, this.subtitle});

  final String? title;
  final String? subtitle;

  @override
  ConsumerState<_LoginSheet> createState() => _LoginSheetState();
}

class _LoginSheetState extends ConsumerState<_LoginSheet> {
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _signUp = false;
  bool _showPassword = false;

  // Sign up only: Termini + age and Privacy are required, promos optional.
  bool _terms = false;
  bool _privacy = false;
  bool _marketing = false;
  bool _busy = false;
  String? _error;

  /// Shown instead of the form when Supabase asks to confirm the email.
  bool _confirmEmailSent = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final t = AppLocalizations.of(context);
    final email = _emailCtrl.text;
    final password = _passwordCtrl.text;

    if (!AuthRepository.isValidEmail(email)) {
      setState(() => _error = t.loginErrorEmail);
      return;
    }
    if (password.isEmpty ||
        (_signUp && password.length < AuthRepository.minPasswordLength)) {
      setState(() => _error = t.loginErrorPassword(AuthRepository.minPasswordLength));
      return;
    }
    if (_signUp && !ConsentChecks.requiredAccepted(terms: _terms, privacy: _privacy)) {
      setState(() => _error = t.consentRequired);
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });
    // Read before awaiting: the sheet may be dismissed meanwhile, and
    // `ref` is unusable once the widget is gone.
    final auth = ref.read(authRepositoryProvider);
    final onboarding = ref.read(onboardingControllerProvider.notifier);
    final consents = ref.read(consentRepositoryProvider);
    final gateHold = ref.read(consentGateHoldProvider.notifier);
    final container = ProviderScope.containerOf(context, listen: false);
    final versions = LegalVersions.of(ref.read(appConfigProvider).value ?? AppConfig.empty);
    final choices = ConsentChecks.requiredAccepted(terms: _terms, privacy: _privacy)
        ? ConsentChoices(marketingEmail: _marketing)
        : null;
    // The consent sheet waits while we record what was ticked here.
    gateHold.set(true);
    try {
      if (_signUp) {
        final result = await auth.signUp(email: email, password: password);
        if (result == SignUpResult.confirmEmail) {
          // No session until the email is confirmed: keep the choices on
          // the phone, recorded at the first sign in.
          await consents.keepPending(email, choices!, versions);
          if (mounted) setState(() => _confirmEmailSent = true);
          return;
        }
        await _quietly(() => consents.record(choices!, versions));
      } else {
        await auth.signIn(email: email, password: password);
        await _quietly(consents.flushPending);
      }
      container.invalidate(currentConsentsProvider);
      TextInput.finishAutofillContext();
      // Push what the user chose in onboarding to their account.
      await onboarding.syncIfLoggedIn();
      if (mounted) Navigator.of(context).pop(true);
    } on AuthFailureException catch (e) {
      if (mounted) setState(() => _error = authFailureMessage(t, e.failure));
    } finally {
      gateHold.set(false);
      if (mounted) setState(() => _busy = false);
    }
  }

  /// A failed consent write must not fail the login: the consent sheet
  /// asks again right after.
  static Future<void> _quietly(Future<void> Function() write) async {
    try {
      await write();
    } catch (_) {}
  }

  void _switchMode() => setState(() {
        _signUp = !_signUp;
        _error = null;
      });

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;

    final title = _signUp ? t.loginSignUpTitle : (widget.title ?? t.loginTitle);
    final subtitle = widget.subtitle ?? t.loginSubtitle;

    return Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.xl,
        right: AppSpacing.xl,
        bottom: MediaQuery.viewInsetsOf(context).bottom + AppSpacing.xl,
      ),
      child: _confirmEmailSent
          ? Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(t.loginConfirmTitle, style: text.headlineSmall),
                const SizedBox(height: AppSpacing.s),
                Text(
                  t.loginConfirmBody(_emailCtrl.text.trim()),
                  style: text.bodyMedium?.copyWith(fontSize: 15),
                ),
                const SizedBox(height: AppSpacing.xl),
                FilledButton(
                  onPressed: () => setState(() {
                    _confirmEmailSent = false;
                    _signUp = false;
                  }),
                  child: Text(t.loginSignIn),
                ),
              ],
            )
          : SingleChildScrollView(
              child: AutofillGroup(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(title, style: text.headlineSmall),
                  const SizedBox(height: AppSpacing.s),
                  Text(subtitle, style: text.bodyMedium?.copyWith(fontSize: 15)),
                  const SizedBox(height: AppSpacing.xl),
                  TextField(
                    controller: _emailCtrl,
                    autofocus: true,
                    keyboardType: TextInputType.emailAddress,
                    autocorrect: false,
                    autofillHints: const [AutofillHints.email],
                    textInputAction: TextInputAction.next,
                    decoration: InputDecoration(labelText: t.loginEmailLabel),
                  ),
                  const SizedBox(height: AppSpacing.m),
                  TextField(
                    controller: _passwordCtrl,
                    obscureText: !_showPassword,
                    autocorrect: false,
                    enableSuggestions: false,
                    autofillHints: [
                      _signUp ? AutofillHints.newPassword : AutofillHints.password,
                    ],
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _busy ? null : _submit(),
                    decoration: InputDecoration(
                      labelText: t.loginPasswordLabel,
                      helperText: _signUp
                          ? t.loginPasswordHint(AuthRepository.minPasswordLength)
                          : null,
                      suffixIcon: IconButton(
                        tooltip: _showPassword ? t.loginHidePassword : t.loginShowPassword,
                        icon: Icon(_showPassword ? Icons.visibility_off : Icons.visibility),
                        onPressed: () => setState(() => _showPassword = !_showPassword),
                      ),
                    ),
                  ),
                  if (_signUp) ...[
                    const SizedBox(height: AppSpacing.m),
                    ConsentChecks(
                      terms: _terms,
                      privacy: _privacy,
                      marketing: _marketing,
                      onTerms: (v) => setState(() => _terms = v),
                      onPrivacy: (v) => setState(() => _privacy = v),
                      onMarketing: (v) => setState(() => _marketing = v),
                    ),
                  ],
                  if (_error != null) ...[
                    const SizedBox(height: AppSpacing.s),
                    Text(_error!, style: const TextStyle(color: AppColors.danger, fontSize: 13)),
                  ],
                  const SizedBox(height: AppSpacing.l),
                  FilledButton(
                    onPressed: _busy ||
                            (_signUp &&
                                !ConsentChecks.requiredAccepted(terms: _terms, privacy: _privacy))
                        ? null
                        : _submit,
                    child: _busy
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                          )
                        : Text(_signUp ? t.loginSignUp : t.loginSignIn),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  TextButton(
                    onPressed: _busy ? null : _switchMode,
                    child: Text(_signUp ? t.loginToSignIn : t.loginToSignUp),
                  ),
                ],
              ),
              ),
            ),
    );
  }
}
