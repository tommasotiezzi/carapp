import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/routes.dart';
import '../../../core/supabase/supabase_client.dart';
import '../../../core/theme/tokens.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../../auth/data/auth_repository.dart';
import '../../auth/ui/login_sheet.dart';
import '../../onboarding/state/onboarding_controller.dart';
import '../../saved/ui/saved_section.dart';

/// Minimal profile for now: login / logout, "Cosa cerco" and "Salvati".
/// Saved searches arrive with the filters step.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final user = ref.watch(currentUserProvider);
    final hasPrefs = !ref.watch(onboardingControllerProvider.select((s) => s.preferences.isEmpty));

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(AppSpacing.page, AppSpacing.xl, AppSpacing.page, AppSpacing.xl),
          children: [
            Row(
              children: [
                const CircleAvatar(
                  radius: 30,
                  backgroundColor: AppColors.placeholder,
                  child: Icon(Icons.person_outline, color: AppColors.inkSecondary, size: 28),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user == null ? t.profileGuestTitle : (user.email ?? ''),
                        style: text.titleLarge,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (user == null) Text(t.profileGuestSubtitle, style: text.bodyMedium),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xl),
            if (user == null)
              FilledButton(
                onPressed: () => showLoginSheet(context),
                child: Text(t.profileLogin),
              ),
            const SizedBox(height: AppSpacing.xl),
            _WhatILookForCard(loggedIn: user != null, hasPrefs: hasPrefs),
            if (user != null) ...[
              const SizedBox(height: AppSpacing.xxl),
              const SavedSection(),
              const SizedBox(height: AppSpacing.xxl),
              OutlinedButton(
                onPressed: () => ref.read(authRepositoryProvider).signOut(),
                child: Text(t.profileLogout),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// "Cosa cerco". Always visible; guests are asked to sign up first,
/// because preferences live on the account (and drive alerts).
class _WhatILookForCard extends StatelessWidget {
  const _WhatILookForCard({required this.loggedIn, required this.hasPrefs});

  final bool loggedIn;
  final bool hasPrefs;

  static const _editPath = '${AppRoutes.onboardingPreferences}?edit=1';

  Future<void> _signUpThenEdit(BuildContext context) async {
    final ok = await showLoginSheet(context);
    if (ok && context.mounted) context.push(_editPath);
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.l),
      decoration: BoxDecoration(
        color: AppColors.primarySoft,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(t.profileWhatILookFor, style: text.titleSmall)),
              if (loggedIn)
                TextButton(
                  onPressed: () => context.push(_editPath),
                  child: Text(hasPrefs ? t.profileEdit : t.profileSetPreferences),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          if (!loggedIn) ...[
            Text(t.profilePrefsGuest, style: text.bodyMedium),
            const SizedBox(height: AppSpacing.m),
            FilledButton(
              onPressed: () => _signUpThenEdit(context),
              child: Text(t.profilePrefsGuestCta),
            ),
          ] else if (!hasPrefs)
            Text(t.profileNoPreferences, style: text.bodyMedium),
        ],
      ),
    );
  }
}