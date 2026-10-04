import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/config/app_config.dart';
import '../../../core/router/routes.dart';
import '../../../core/supabase/supabase_client.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/utils/formatters.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../../auth/data/auth_repository.dart';
import '../../auth/ui/login_sheet.dart';
import '../../legal/data/consents.dart';
import '../../legal/state/consent_providers.dart';
import '../../legal/ui/consent_checks.dart';
import '../data/account_repository.dart';
import '../state/settings_providers.dart';
import 'account_sheets.dart';

/// `/settings` (gear in the profile): account, optional info,
/// notifications, emails, legal documents, sign out, delete account.
/// Guests see the legal part and a sign-in prompt.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final user = ref.watch(currentUserProvider);

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(title: Text(t.settingsTitle)),
      body: ListView(
        padding: const EdgeInsets.only(bottom: AppSpacing.xxxl),
        children: [
          if (user == null)
            Padding(
              padding: const EdgeInsets.all(AppSpacing.page),
              child: Container(
                padding: const EdgeInsets.all(AppSpacing.l),
                decoration: BoxDecoration(
                  color: AppColors.primarySoft,
                  borderRadius: BorderRadius.circular(AppRadius.l),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(t.settingsGuest, style: Theme.of(context).textTheme.bodyLarge),
                    const SizedBox(height: AppSpacing.m),
                    FilledButton(onPressed: () => showLoginSheet(context), child: Text(t.profileLogin)),
                  ],
                ),
              ),
            )
          else ...[
            _Header(t.settingsAccount),
            _AccountSection(email: user.email ?? ''),
            _Header(t.settingsAboutYou),
            const _AboutYouSection(),
            _Header(t.settingsNotifications),
            const _NotificationsSection(),
            _Header(t.settingsEmails),
            const _EmailsSection(),
          ],
          _Header(t.settingsLegal),
          const _LegalSection(),
          if (user != null) ...[
            const Divider(height: AppSpacing.xxxl),
            ListTile(
              leading: const Icon(Icons.logout),
              title: Text(t.profileLogout),
              onTap: () async {
                await ref.read(authRepositoryProvider).signOut();
                if (context.mounted) context.pop();
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: AppColors.danger),
              title: Text(t.settingsDeleteAccount, style: const TextStyle(color: AppColors.danger)),
              onTap: () async {
                final deleted = await showDeleteAccountSheet(context);
                if (deleted && context.mounted) {
                  ScaffoldMessenger.of(context)
                      .showSnackBar(SnackBar(content: Text(t.settingsDeleted)));
                  context.go(AppRoutes.feed);
                }
              },
            ),
          ],
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(AppSpacing.page, AppSpacing.xl, AppSpacing.page, AppSpacing.xs),
        child: Text(
          text.toUpperCase(),
          style: Theme.of(context).textTheme.labelMedium?.copyWith(letterSpacing: 0.6),
        ),
      );
}

/// Shows [message] for failed writes; settings never fail silently.
Future<void> _guarded(BuildContext context, Future<void> Function() action) async {
  final t = AppLocalizations.of(context);
  final messenger = ScaffoldMessenger.of(context);
  try {
    await action();
  } catch (_) {
    messenger.showSnackBar(SnackBar(content: Text(t.searchError)));
  }
}

class _AccountSection extends StatelessWidget {
  const _AccountSection({required this.email});

  final String email;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return Column(
      children: [
        ListTile(
          leading: const Icon(Icons.alternate_email),
          title: Text(t.settingsEmail),
          subtitle: Text(email),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => showChangeEmailSheet(context),
        ),
        ListTile(
          leading: const Icon(Icons.lock_outline),
          title: Text(t.loginPasswordLabel),
          subtitle: const Text('••••••••'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => showChangePasswordSheet(context),
        ),
      ],
    );
  }
}

/// Optional info: never asked in onboarding, never required.
class _AboutYouSection extends ConsumerWidget {
  const _AboutYouSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final profile = ref.watch(myProfileProvider).value ?? const MyProfile();
    final controller = ref.read(myProfileProvider.notifier);

    String genderLabel(Gender g) => switch (g) {
          Gender.female => t.genderFemale,
          Gender.male => t.genderMale,
          Gender.other => t.genderOther,
          Gender.undisclosed => t.genderUndisclosed,
        };

    Widget clear(VoidCallback onClear) => IconButton(
          tooltip: t.settingsRemove,
          icon: const Icon(Icons.close, size: 20),
          onPressed: onClear,
        );

    return Column(
      children: [
        ListTile(
          leading: const Icon(Icons.badge_outlined),
          title: Text(t.settingsDisplayName),
          subtitle: Text(profile.displayName ?? t.settingsAdd),
          trailing: const Icon(Icons.chevron_right),
          onTap: () async {
            final name = await showTextInputSheet(
              context,
              title: t.settingsDisplayName,
              initial: profile.displayName ?? '',
              maxLength: MyProfile.maxDisplayName,
            );
            if (name == null || !context.mounted) return;
            final value = name.trim().isEmpty ? null : name.trim();
            await _guarded(
              context,
              () => controller.edit(
                MyProfile(displayName: value, birthDate: profile.birthDate, gender: profile.gender),
                {'display_name': value},
              ),
            );
          },
        ),
        ListTile(
          leading: const Icon(Icons.cake_outlined),
          title: Text(t.settingsBirthDate),
          subtitle: Text(
            profile.birthDate == null ? t.settingsOptional : Formatters.date(profile.birthDate!),
          ),
          trailing: profile.birthDate == null
              ? const Icon(Icons.chevron_right)
              : clear(() => _guarded(
                    context,
                    () => controller.edit(
                      MyProfile(displayName: profile.displayName, gender: profile.gender),
                      {'birth_date': null},
                    ),
                  )),
          onTap: () async {
            final latest = MyProfile.latestBirthDate(DateTime.now());
            final picked = await showDatePicker(
              context: context,
              initialDate: profile.birthDate ?? DateTime(latest.year - 6),
              firstDate: DateTime(1900),
              lastDate: latest,
              helpText: t.settingsBirthDate,
            );
            if (picked == null || !context.mounted) return;
            await _guarded(
              context,
              () => controller.edit(
                MyProfile(displayName: profile.displayName, birthDate: picked, gender: profile.gender),
                {'birth_date': picked.toIso8601String().substring(0, 10)},
              ),
            );
          },
        ),
        ListTile(
          leading: const Icon(Icons.person_outline),
          title: Text(t.settingsGender),
          subtitle: Text(profile.gender == null ? t.settingsOptional : genderLabel(profile.gender!)),
          trailing: profile.gender == null
              ? const Icon(Icons.chevron_right)
              : clear(() => _guarded(
                    context,
                    () => controller.edit(
                      MyProfile(displayName: profile.displayName, birthDate: profile.birthDate),
                      {'gender': null},
                    ),
                  )),
          onTap: () async {
            final picked = await showModalBottomSheet<Gender>(
              context: context,
              useSafeArea: true,
              builder: (_) => SafeArea(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final g in Gender.values)
                      ListTile(
                        title: Text(genderLabel(g)),
                        trailing: g == profile.gender
                            ? const Icon(Icons.check, color: AppColors.primary)
                            : null,
                        onTap: () => Navigator.of(context).pop(g),
                      ),
                  ],
                ),
              ),
            );
            if (picked == null || !context.mounted) return;
            await _guarded(
              context,
              () => controller.edit(
                MyProfile(displayName: profile.displayName, birthDate: profile.birthDate, gender: picked),
                {'gender': picked.dbName},
              ),
            );
          },
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.page),
          child: Text(t.settingsAboutYouNote, style: Theme.of(context).textTheme.bodySmall),
        ),
      ],
    );
  }
}

class _NotificationsSection extends ConsumerWidget {
  const _NotificationsSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final pushReady = (ref.watch(appConfigProvider).value ?? AppConfig.empty).flag('push_enabled');
    final prefs = ref.watch(notificationPrefsProvider);
    final controller = ref.read(notificationPrefsProvider.notifier);

    String label(String type) => switch (type) {
          'new_message' => t.notifNewMessage,
          'price_drop' => t.notifPriceDrop,
          'listing_sold' => t.notifListingSold,
          'saved_search_match' => t.notifSavedSearch,
          'new_contact' => t.notifNewContact,
          'listing_expiring' => t.notifListingExpiring,
          _ => type,
        };

    Widget toggle(String type) => SwitchListTile(
          title: Text(label(type)),
          value: prefs.value?[type] ?? true,
          onChanged: prefs.hasValue ? (v) => _guarded(context, () => controller.set(type, v)) : null,
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SwitchListTile(
          secondary: const Icon(Icons.notifications_outlined),
          title: Text(t.settingsPush),
          subtitle: Text(pushReady ? t.settingsPushOn : t.settingsPushSoon),
          value: pushReady,
          onChanged: null, // OS permission + FCM/APNs come with notifications
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.page, AppSpacing.s, AppSpacing.page, 0),
          child: Text(t.settingsForBuyers, style: text.titleSmall),
        ),
        for (final type in buyerNotificationTypes) toggle(type),
        Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.page, AppSpacing.s, AppSpacing.page, 0),
          child: Text(t.settingsForSellers, style: text.titleSmall),
        ),
        for (final type in sellerNotificationTypes) toggle(type),
      ],
    );
  }
}

class _EmailsSection extends ConsumerWidget {
  const _EmailsSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final consents = ref.watch(currentConsentsProvider);
    final on = consents.value?[ConsentKind.marketingEmail]?.granted ?? false;

    return SwitchListTile(
      secondary: const Icon(Icons.mail_outline),
      title: Text(t.consentMarketing),
      subtitle: Text(t.settingsMarketingNote),
      value: on,
      onChanged: consents.hasValue
          ? (v) => _guarded(context, () async {
                final container = ProviderScope.containerOf(context, listen: false);
                await ref.read(consentRepositoryProvider).set(ConsentKind.marketingEmail, v);
                container.invalidate(currentConsentsProvider);
              })
          : null,
    );
  }
}

class _LegalSection extends ConsumerWidget {
  const _LegalSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final consents = ref.watch(currentConsentsProvider).value ?? const {};
    final config = ref.watch(appConfigProvider).value ?? AppConfig.empty;
    final support = config.legalUrl('support_email');

    String? acceptedOn(ConsentKind kind, String Function(String) label) {
      final at = consents[kind]?.granted == true ? consents[kind]?.at : null;
      return at == null ? null : label(Formatters.date(at.toLocal()));
    }

    final termsOn = acceptedOn(ConsentKind.terms, t.settingsAcceptedOn);
    final privacyOn = acceptedOn(ConsentKind.privacy, t.settingsReadOn);

    return Column(
      children: [
        ListTile(
          leading: const Icon(Icons.description_outlined),
          title: Text(t.legalTerms),
          subtitle: termsOn == null ? null : Text(termsOn),
          trailing: const Icon(Icons.open_in_new, size: 20),
          onTap: () => openLegalUrl(context, ref, 'terms_url'),
        ),
        ListTile(
          leading: const Icon(Icons.privacy_tip_outlined),
          title: Text(t.legalPrivacy),
          subtitle: privacyOn == null ? null : Text(privacyOn),
          trailing: const Icon(Icons.open_in_new, size: 20),
          onTap: () => openLegalUrl(context, ref, 'privacy_policy_url'),
        ),
        if (support != null)
          ListTile(
            leading: const Icon(Icons.support_agent),
            title: Text(t.settingsSupport),
            subtitle: Text(support),
            onTap: () => launchUrl(Uri(scheme: 'mailto', path: support)),
          ),
      ],
    );
  }
}
