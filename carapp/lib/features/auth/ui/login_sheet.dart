import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/tokens.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../../onboarding/state/onboarding_controller.dart';
import '../data/auth_repository.dart';

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

  String _message(AppLocalizations t, AuthFailure f) => switch (f) {
        AuthFailure.invalidCredentials => t.loginErrorCredentials,
        AuthFailure.emailTaken => t.loginErrorExists,
        AuthFailure.weakPassword => t.loginErrorWeak,
        AuthFailure.emailNotConfirmed => t.loginErrorNotConfirmed,
        AuthFailure.rateLimited => t.loginErrorRateLimit,
        AuthFailure.generic => t.loginErrorGeneric,
      };

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

    setState(() {
      _busy = true;
      _error = null;
    });
    final auth = ref.read(authRepositoryProvider);
    try {
      if (_signUp) {
        final result = await auth.signUp(email: email, password: password);
        if (result == SignUpResult.confirmEmail) {
          if (mounted) setState(() => _confirmEmailSent = true);
          return;
        }
      } else {
        await auth.signIn(email: email, password: password);
      }
      TextInput.finishAutofillContext();
      // Push what the user chose in onboarding to their account.
      await ref.read(onboardingControllerProvider.notifier).syncIfLoggedIn();
      if (mounted) Navigator.of(context).pop(true);
    } on AuthFailureException catch (e) {
      if (mounted) setState(() => _error = _message(t, e.failure));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
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
          : AutofillGroup(
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
                  if (_error != null) ...[
                    const SizedBox(height: AppSpacing.s),
                    Text(_error!, style: const TextStyle(color: AppColors.danger, fontSize: 13)),
                  ],
                  const SizedBox(height: AppSpacing.l),
                  FilledButton(
                    onPressed: _busy ? null : _submit,
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
                  if (_signUp)
                    Text(t.loginTerms, textAlign: TextAlign.center, style: text.bodySmall),
                ],
              ),
            ),
    );
  }
}
