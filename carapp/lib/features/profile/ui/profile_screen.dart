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

/// Minimal profile for now: login / logout and "Cosa cerco".
/// Saved listings and searches arrive with step 3.
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
            Container(
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
                      TextButton(
                        onPressed: () => context.push('${AppRoutes.onboardingPreferences}?edit=1'),
                        child: Text(hasPrefs ? t.profileEdit : t.profileSetPreferences),
                      ),
                    ],
                  ),
                  if (!hasPrefs) Text(t.profileNoPreferences, style: text.bodyMedium),
                ],
              ),
            ),
            if (user != null) ...[
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