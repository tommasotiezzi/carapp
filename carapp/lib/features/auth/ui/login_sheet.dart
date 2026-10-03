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
  final _codeCtrl = TextEditingController();
  bool _codeSent = false;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _codeCtrl.dispose();
    super.dispose();
  }

  Future<void> _sendCode() async {
    final t = AppLocalizations.of(context);
    final email = _emailCtrl.text;
    if (!AuthRepository.isValidEmail(email)) {
      setState(() => _error = t.loginErrorEmail);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(authRepositoryProvider).sendCode(email);
      if (!mounted) return;
      setState(() => _codeSent = true);
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = t.loginErrorSend);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _verify() async {
    final t = AppLocalizations.of(context);
    final code = _codeCtrl.text.trim();
    if (code.length < 6) {
      setState(() => _error = t.loginErrorCode);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(authRepositoryProvider).verifyCode(email: _emailCtrl.text, code: code);
      // Push what the user chose in onboarding to their new account.
      await ref.read(onboardingControllerProvider.notifier).syncIfLoggedIn();
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = t.loginErrorCode);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;

    return Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.xl,
        right: AppSpacing.xl,
        bottom: MediaQuery.viewInsetsOf(context).bottom + AppSpacing.xl,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            _codeSent ? t.loginCodeTitle : (widget.title ?? t.loginTitle),
            style: text.headlineSmall,
          ),
          const SizedBox(height: AppSpacing.s),
          Text(
            _codeSent
                ? t.loginCodeSubtitle(_emailCtrl.text.trim())
                : (widget.subtitle ?? t.loginSubtitle),
            style: text.bodyMedium?.copyWith(fontSize: 15),
          ),
          const SizedBox(height: AppSpacing.xl),
          if (!_codeSent)
            TextField(
              controller: _emailCtrl,
              autofocus: true,
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _busy ? null : _sendCode(),
              decoration: InputDecoration(labelText: t.loginEmailLabel),
            )
          else
            TextField(
              controller: _codeCtrl,
              autofocus: true,
              keyboardType: TextInputType.number,
              autofillHints: const [AutofillHints.oneTimeCode],
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(8),
              ],
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _busy ? null : _verify(),
              style: const TextStyle(fontSize: 22, letterSpacing: 6, fontWeight: FontWeight.w700),
              decoration: InputDecoration(labelText: t.loginCodeLabel),
            ),
          if (_error != null) ...[
            const SizedBox(height: AppSpacing.s),
            Text(_error!, style: const TextStyle(color: AppColors.danger, fontSize: 13)),
          ],
          const SizedBox(height: AppSpacing.l),
          FilledButton(
            onPressed: _busy ? null : (_codeSent ? _verify : _sendCode),
            child: _busy
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                  )
                : Text(_codeSent ? t.loginVerify : t.loginSendCode),
          ),
          if (_codeSent)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton(
                  onPressed: _busy
                      ? null
                      : () => setState(() {
                            _codeSent = false;
                            _codeCtrl.clear();
                            _error = null;
                          }),
                  child: Text(t.loginChangeEmail),
                ),
                TextButton(
                  onPressed: _busy ? null : _sendCode,
                  child: Text(t.loginResend),
                ),
              ],
            )
          else ...[
            const SizedBox(height: AppSpacing.m),
            Text(
              t.loginTerms,
              textAlign: TextAlign.center,
              style: text.bodySmall,
            ),
          ],
        ],
      ),
    );
  }
}