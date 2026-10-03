import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/supabase/supabase_client.dart';
import '../../../core/theme/tokens.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../../auth/ui/login_sheet.dart';
import '../../dealer/data/dealer_repository.dart';
import '../state/onboarding_controller.dart';
import 'onboarding_exit.dart';

/// "Il tuo salone": login first, then VAT number + display name.
class DealerSignupScreen extends ConsumerStatefulWidget {
  const DealerSignupScreen({super.key});

  @override
  ConsumerState<DealerSignupScreen> createState() => _DealerSignupScreenState();
}

class _DealerSignupScreenState extends ConsumerState<DealerSignupScreen> {
  final _vatCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _vatCtrl.dispose();
    _nameCtrl.dispose();
    super.dispose();
  }

  String _message(AppLocalizations t, DealerSignupError e) => switch (e) {
        DealerSignupError.invalidVat => t.dealerErrorInvalidVat,
        DealerSignupError.vatTaken => t.dealerErrorTaken,
        DealerSignupError.viesUnavailable => t.dealerErrorVies,
        DealerSignupError.generic => t.dealerErrorGeneric,
      };

  Future<void> _submit() async {
    final t = AppLocalizations.of(context);
    final vat = DealerRepository.normalizeItalianVat(_vatCtrl.text);
    if (vat == null) {
      setState(() => _error = t.dealerErrorInvalidVat);
      return;
    }
    if (_nameCtrl.text.trim().isEmpty) {
      setState(() => _error = t.dealerErrorGeneric);
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(dealerRepositoryProvider).signUp(
            vatNumber: vat,
            displayName: _nameCtrl.text,
          );
      await ref.read(onboardingControllerProvider.notifier).complete(keepPreferences: false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t.dealerCreated)));
      exitOnboarding(context);
    } on DealerSignupException catch (e) {
      if (mounted) setState(() => _error = _message(t, e.error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final loggedIn = ref.watch(currentUserProvider) != null;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s),
                child: IconButton(
                  tooltip: MaterialLocalizations.of(context).backButtonTooltip,
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () => context.pop(),
                ),
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(AppSpacing.xl, AppSpacing.s, AppSpacing.xl, AppSpacing.xl),
                children: [
                  Text(t.dealerTitle, style: text.headlineMedium),
                  const SizedBox(height: AppSpacing.s),
                  Text(t.dealerSubtitle, style: text.bodyMedium?.copyWith(fontSize: 15)),
                  const SizedBox(height: AppSpacing.xxl),
                  if (!loggedIn) ...[
                    Text(t.dealerLoginNeeded, style: text.bodyLarge),
                    const SizedBox(height: AppSpacing.l),
                    FilledButton(
                      onPressed: () => showLoginSheet(context),
                      child: Text(t.dealerLoginCta),
                    ),
                  ] else ...[
                    TextField(
                      controller: _vatCtrl,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9ITit\s]')),
                        LengthLimitingTextInputFormatter(16),
                      ],
                      decoration: InputDecoration(
                        labelText: t.dealerVatLabel,
                        prefixText: 'IT ',
                      ),
                    ),
                    const SizedBox(height: AppSpacing.l),
                    TextField(
                      controller: _nameCtrl,
                      textCapitalization: TextCapitalization.words,
                      maxLength: 60,
                      decoration: InputDecoration(labelText: t.dealerNameLabel, counterText: ''),
                    ),
                    const SizedBox(height: AppSpacing.l),
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.l),
                      decoration: BoxDecoration(
                        color: AppColors.primarySoft,
                        borderRadius: BorderRadius.circular(AppRadius.l),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(t.dealerTrialTitle, style: text.titleSmall),
                          const SizedBox(height: AppSpacing.xs),
                          Text(t.dealerTrialBody, style: text.bodyMedium),
                        ],
                      ),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: AppSpacing.m),
                      Text(_error!, style: const TextStyle(color: AppColors.danger, fontSize: 14)),
                    ],
                  ],
                ],
              ),
            ),
            if (loggedIn)
              Padding(
                padding: const EdgeInsets.fromLTRB(AppSpacing.xl, AppSpacing.s, AppSpacing.xl, AppSpacing.l),
                child: FilledButton(
                  onPressed: _busy ? null : _submit,
                  child: _busy
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                        )
                      : Text(t.dealerCta),
                ),
              ),
          ],
        ),
      ),
    );
  }
}