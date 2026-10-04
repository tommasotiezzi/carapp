import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/tokens.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../../auth/data/auth_repository.dart';
import '../../auth/ui/auth_messages.dart';
import '../data/account_repository.dart';

Future<T?> _sheet<T>(BuildContext context, Widget child) => showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => child,
    );

/// Email change: new address + current password.
Future<void> showChangeEmailSheet(BuildContext context) async {
  final t = AppLocalizations.of(context);
  final result = await _sheet<EmailChange>(context, const _ChangeEmailSheet());
  if (result == null || !context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
    content: Text(result == EmailChange.done ? t.settingsEmailChanged : t.settingsEmailConfirm),
  ));
}

/// Password change: current + new one.
Future<void> showChangePasswordSheet(BuildContext context) async {
  final t = AppLocalizations.of(context);
  final done = await _sheet<bool>(context, const _ChangePasswordSheet());
  if (done == true && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t.settingsPasswordChanged)));
  }
}

/// Returns true once the account is deleted and the user signed out.
Future<bool> showDeleteAccountSheet(BuildContext context) async =>
    await _sheet<bool>(context, const _DeleteAccountSheet()) ?? false;

/// One text field; returns the text, or null when dismissed.
Future<String?> showTextInputSheet(
  BuildContext context, {
  required String title,
  required String initial,
  int? maxLength,
}) =>
    _sheet<String>(context, _TextInputSheet(title: title, initial: initial, maxLength: maxLength));

/// Shared layout: title, body, fields, error, primary button.
class _SheetScaffold extends StatelessWidget {
  const _SheetScaffold({
    required this.title,
    required this.children,
    required this.actionLabel,
    required this.onAction,
    this.body,
    this.error,
    this.busy = false,
    this.danger = false,
  });

  final String title;
  final String? body;
  final List<Widget> children;
  final String? error;
  final String actionLabel;
  final VoidCallback? onAction;
  final bool busy;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.xl,
        right: AppSpacing.xl,
        bottom: MediaQuery.viewInsetsOf(context).bottom + AppSpacing.xl,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: text.headlineSmall),
            if (body != null) ...[
              const SizedBox(height: AppSpacing.s),
              Text(body!, style: text.bodyMedium),
            ],
            const SizedBox(height: AppSpacing.l),
            ...children,
            if (error != null) ...[
              const SizedBox(height: AppSpacing.s),
              Text(error!, style: const TextStyle(color: AppColors.danger, fontSize: 13)),
            ],
            const SizedBox(height: AppSpacing.l),
            FilledButton(
              onPressed: busy ? null : onAction,
              style: danger ? FilledButton.styleFrom(backgroundColor: AppColors.danger) : null,
              child: busy
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                    )
                  : Text(actionLabel),
            ),
          ],
        ),
      ),
    );
  }
}

class _PasswordField extends StatefulWidget {
  const _PasswordField({required this.controller, required this.label, this.newPassword = false});

  final TextEditingController controller;
  final String label;
  final bool newPassword;

  @override
  State<_PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<_PasswordField> {
  bool _show = false;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return TextField(
      controller: widget.controller,
      obscureText: !_show,
      autocorrect: false,
      enableSuggestions: false,
      autofillHints: [widget.newPassword ? AutofillHints.newPassword : AutofillHints.password],
      decoration: InputDecoration(
        labelText: widget.label,
        helperText: widget.newPassword ? t.loginPasswordHint(AuthRepository.minPasswordLength) : null,
        suffixIcon: IconButton(
          tooltip: _show ? t.loginHidePassword : t.loginShowPassword,
          icon: Icon(_show ? Icons.visibility_off : Icons.visibility),
          onPressed: () => setState(() => _show = !_show),
        ),
      ),
    );
  }
}

class _ChangeEmailSheet extends ConsumerStatefulWidget {
  const _ChangeEmailSheet();

  @override
  ConsumerState<_ChangeEmailSheet> createState() => _ChangeEmailSheetState();
}

class _ChangeEmailSheetState extends ConsumerState<_ChangeEmailSheet> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final t = AppLocalizations.of(context);
    if (!AuthRepository.isValidEmail(_email.text)) {
      setState(() => _error = t.loginErrorEmail);
      return;
    }
    final repo = ref.read(accountRepositoryProvider);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final result = await repo.changeEmail(password: _password.text, newEmail: _email.text);
      if (mounted) Navigator.of(context).pop(result);
    } on AuthFailureException catch (e) {
      if (mounted) setState(() => _error = authFailureMessage(t, e.failure));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return _SheetScaffold(
      title: t.settingsChangeEmail,
      error: _error,
      busy: _busy,
      actionLabel: t.commonSave,
      onAction: _submit,
      children: [
        TextField(
          controller: _email,
          autofocus: true,
          keyboardType: TextInputType.emailAddress,
          autocorrect: false,
          autofillHints: const [AutofillHints.email],
          decoration: InputDecoration(labelText: t.settingsNewEmail),
        ),
        const SizedBox(height: AppSpacing.m),
        _PasswordField(controller: _password, label: t.settingsCurrentPassword),
      ],
    );
  }
}

class _ChangePasswordSheet extends ConsumerStatefulWidget {
  const _ChangePasswordSheet();

  @override
  ConsumerState<_ChangePasswordSheet> createState() => _ChangePasswordSheetState();
}

class _ChangePasswordSheetState extends ConsumerState<_ChangePasswordSheet> {
  final _current = TextEditingController();
  final _next = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final t = AppLocalizations.of(context);
    if (_next.text.length < AuthRepository.minPasswordLength) {
      setState(() => _error = t.loginErrorPassword(AuthRepository.minPasswordLength));
      return;
    }
    final repo = ref.read(accountRepositoryProvider);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await repo.changePassword(current: _current.text, next: _next.text);
      if (mounted) Navigator.of(context).pop(true);
    } on AuthFailureException catch (e) {
      if (mounted) setState(() => _error = authFailureMessage(t, e.failure));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return _SheetScaffold(
      title: t.settingsChangePassword,
      error: _error,
      busy: _busy,
      actionLabel: t.commonSave,
      onAction: _submit,
      children: [
        _PasswordField(controller: _current, label: t.settingsCurrentPassword),
        const SizedBox(height: AppSpacing.m),
        _PasswordField(controller: _next, label: t.settingsNewPassword, newPassword: true),
      ],
    );
  }
}

class _DeleteAccountSheet extends ConsumerStatefulWidget {
  const _DeleteAccountSheet();

  @override
  ConsumerState<_DeleteAccountSheet> createState() => _DeleteAccountSheetState();
}

class _DeleteAccountSheetState extends ConsumerState<_DeleteAccountSheet> {
  final _password = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final t = AppLocalizations.of(context);
    final repo = ref.read(accountRepositoryProvider);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await repo.deleteAccount(_password.text);
      if (mounted) Navigator.of(context).pop(true);
    } on AuthFailureException catch (e) {
      if (mounted) setState(() => _error = authFailureMessage(t, e.failure));
    } catch (_) {
      if (mounted) setState(() => _error = t.loginErrorGeneric);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return _SheetScaffold(
      title: t.settingsDeleteTitle,
      body: t.settingsDeleteBody,
      error: _error,
      busy: _busy,
      danger: true,
      actionLabel: t.settingsDeleteCta,
      onAction: _submit,
      children: [_PasswordField(controller: _password, label: t.settingsCurrentPassword)],
    );
  }
}

class _TextInputSheet extends StatefulWidget {
  const _TextInputSheet({required this.title, required this.initial, this.maxLength});

  final String title;
  final String initial;
  final int? maxLength;

  @override
  State<_TextInputSheet> createState() => _TextInputSheetState();
}

class _TextInputSheetState extends State<_TextInputSheet> {
  late final _ctrl = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return _SheetScaffold(
      title: widget.title,
      actionLabel: t.commonSave,
      onAction: () => Navigator.of(context).pop(_ctrl.text),
      children: [
        TextField(
          controller: _ctrl,
          autofocus: true,
          maxLength: widget.maxLength,
          textCapitalization: TextCapitalization.words,
        ),
      ],
    );
  }
}
