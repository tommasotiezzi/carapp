import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/config/app_config.dart';
import '../../../core/theme/tokens.dart';
import '../../../l10n/gen/app_localizations.dart';

/// Opens a legal document (Termini, Privacy) in the browser.
Future<void> openLegalUrl(BuildContext context, WidgetRef ref, String key) async {
  final t = AppLocalizations.of(context);
  final messenger = ScaffoldMessenger.of(context);
  final url = (ref.read(appConfigProvider).value ?? AppConfig.empty).legalUrl(key);
  final uri = url == null ? null : Uri.tryParse(url);
  final opened = uri != null && await launchUrl(uri, mode: LaunchMode.externalApplication);
  if (!opened) messenger.showSnackBar(SnackBar(content: Text(t.legalOpenError)));
}

/// The three choices of sign up (and of the consent sheet):
/// age + Termini (required), Privacy read (required), promo emails
/// (optional, off by default).
class ConsentChecks extends ConsumerWidget {
  const ConsentChecks({
    super.key,
    required this.terms,
    required this.privacy,
    required this.marketing,
    required this.onTerms,
    required this.onPrivacy,
    required this.onMarketing,
  });

  final bool terms;
  final bool privacy;
  final bool marketing;
  final ValueChanged<bool> onTerms;
  final ValueChanged<bool> onPrivacy;
  final ValueChanged<bool> onMarketing;

  static bool requiredAccepted({required bool terms, required bool privacy}) => terms && privacy;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _CheckRow(
          value: terms,
          onChanged: onTerms,
          label: t.consentTermsAge(14),
          linkLabel: t.legalRead,
          onLink: () => openLegalUrl(context, ref, 'terms_url'),
        ),
        _CheckRow(
          value: privacy,
          onChanged: onPrivacy,
          label: t.consentPrivacy,
          linkLabel: t.legalRead,
          onLink: () => openLegalUrl(context, ref, 'privacy_policy_url'),
        ),
        _CheckRow(value: marketing, onChanged: onMarketing, label: t.consentMarketing),
      ],
    );
  }
}

class _CheckRow extends StatelessWidget {
  const _CheckRow({
    required this.value,
    required this.onChanged,
    required this.label,
    this.linkLabel,
    this.onLink,
  });

  final bool value;
  final ValueChanged<bool> onChanged;
  final String label;
  final String? linkLabel;
  final VoidCallback? onLink;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return InkWell(
      onTap: () => onChanged(!value),
      borderRadius: BorderRadius.circular(AppRadius.s),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxs),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Checkbox(
              value: value,
              onChanged: (v) => onChanged(v ?? false),
              activeColor: AppColors.primary,
            ),
            Expanded(child: Text(label, style: text.bodyMedium?.copyWith(color: AppColors.ink))),
            if (linkLabel != null)
              TextButton(
                onPressed: onLink,
                style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                child: Text(linkLabel!),
              ),
          ],
        ),
      ),
    );
  }
}
