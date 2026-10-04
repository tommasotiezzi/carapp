import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/routes.dart';
import '../../../core/supabase/supabase_client.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/user_avatar.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../../auth/ui/login_sheet.dart';
import '../../my_listings/state/my_listings_controller.dart';
import '../../my_listings/ui/my_listings_section.dart';
import '../../onboarding/data/buyer_preferences.dart';
import '../../onboarding/state/onboarding_controller.dart';
import '../../saved/ui/saved_section.dart';
import '../../settings/state/settings_providers.dart';

/// What the profile is built around.
enum ProfileRole {
  /// "Sto solo guardando", or no choice yet: a neutral profile that asks
  /// what the user needs.
  explorer,

  /// "Cosa cerco", Salvati.
  buyer,

  /// "I miei annunci" first (with the offer to the people who saved).
  seller,

  /// Chose "concessionario" but the VAT check is not done.
  dealerPending,

  /// A dealer account: the dealer's page and its listings.
  dealer,
}

/// The role: a dealer account is always a dealer; otherwise the intent
/// chosen on this phone, or the one saved on the account.
final profileRoleProvider = Provider<ProfileRole>((ref) {
  if (ref.watch(myDealerProvider).value != null) return ProfileRole.dealer;
  final local = ref.watch(onboardingControllerProvider.select((s) => s.intent));
  final saved = UserIntent.fromName(ref.watch(myProfileProvider).value?.intent);
  return switch (local ?? saved) {
    UserIntent.buy => ProfileRole.buyer,
    UserIntent.sell => ProfileRole.seller,
    UserIntent.dealer => ProfileRole.dealerPending,
    UserIntent.browse || null => ProfileRole.explorer,
  };
});

/// Profile: a header (picture, name, role, settings) and a body for the
/// role: buyer (Cosa cerco, Salvati), seller (I miei annunci, Salvati),
/// dealer (its page, its listings), explorer (pick what you need).
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final role = ref.watch(profileRoleProvider);
    final hasPrefs = !ref.watch(onboardingControllerProvider.select((s) => s.preferences.isEmpty));
    final loggedIn = user != null;
    const gap = SizedBox(height: AppSpacing.xxl);

    final body = <Widget>[
      switch (role) {
        ProfileRole.explorer => const _NeedsCard(),
        ProfileRole.buyer => _WhatILookForCard(loggedIn: loggedIn, hasPrefs: hasPrefs),
        ProfileRole.seller => loggedIn ? const MyListingsSection() : const _SellerGuestCard(),
        ProfileRole.dealerPending => const _DealerPendingCard(),
        ProfileRole.dealer => const _DealerCard(),
      },
      if (loggedIn) ...[
        if (role == ProfileRole.dealer) ...[gap, const MyListingsSection()],
        // Anyone who sells something sees it, whatever the role.
        if (role == ProfileRole.buyer || role == ProfileRole.explorer || role == ProfileRole.dealerPending)
          const _CompactListings(),
        if (role != ProfileRole.dealer) ...[gap, const SavedSection()],
      ],
    ];

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(AppSpacing.page, AppSpacing.xl, AppSpacing.page, AppSpacing.xl),
          children: [
            _Header(role: role),
            const SizedBox(height: AppSpacing.xl),
            if (!loggedIn) ...[
              FilledButton(
                onPressed: () => showLoginSheet(context),
                child: Text(AppLocalizations.of(context).profileLogin),
              ),
              const SizedBox(height: AppSpacing.xl),
            ],
            ...body,
          ],
        ),
      ),
    );
  }
}

/// "I miei annunci" for buyers and explorers who also sell: only when
/// they have listings.
class _CompactListings extends ConsumerWidget {
  const _CompactListings();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final has = ref.watch(myListingsProvider.select((s) => s.value?.isNotEmpty ?? false));
    if (!has) return const SizedBox.shrink();
    return const Padding(
      padding: EdgeInsets.only(top: AppSpacing.xxl),
      child: MyListingsSection(compact: true),
    );
  }
}

class _Header extends ConsumerWidget {
  const _Header({required this.role});

  final ProfileRole role;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final user = ref.watch(currentUserProvider);
    final profile = ref.watch(myProfileProvider).value;
    final dealer = ref.watch(myDealerProvider).value;
    final name = (role == ProfileRole.dealer ? dealer?.displayName : profile?.displayName)?.trim();
    final title = user == null
        ? t.profileGuestTitle
        : (name != null && name.isNotEmpty ? name : (user.email ?? ''));

    final roleLabel = switch (role) {
      ProfileRole.explorer => t.profileRoleExplorer,
      ProfileRole.buyer => t.profileRoleBuyer,
      ProfileRole.seller => t.profileRoleSeller,
      ProfileRole.dealerPending || ProfileRole.dealer => t.profileRoleDealer,
    };

    return Row(
      children: [
        user == null
            ? const CircleAvatar(
                radius: 30,
                backgroundColor: AppColors.placeholder,
                child: Icon(Icons.person_outline, color: AppColors.inkSecondary, size: 28),
              )
            : UserAvatar(path: profile?.avatarPath, name: title, radius: 30, dealer: role == ProfileRole.dealer),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: text.titleLarge, maxLines: 1, overflow: TextOverflow.ellipsis),
              if (user == null) Text(t.profileGuestSubtitle, style: text.bodyMedium),
              if (role != ProfileRole.explorer)
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        roleLabel,
                        style: text.bodyMedium?.copyWith(color: AppColors.inkSecondary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    // A dealer account stays a dealer.
                    if (role != ProfileRole.dealer)
                      TextButton(
                        key: const ValueKey('change-role'),
                        style: TextButton.styleFrom(
                          minimumSize: Size.zero,
                          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s, vertical: 4),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        onPressed: () => showNeedsSheet(context),
                        child: Text(t.profileRoleChange),
                      ),
                  ],
                ),
            ],
          ),
        ),
        IconButton(
          tooltip: t.settingsTitle,
          icon: const Icon(Icons.settings_outlined),
          onPressed: () => context.push(AppRoutes.settings),
        ),
      ],
    );
  }
}

/// The choices of the neutral profile (and of "Cambia").
List<(UserIntent, IconData, String, String)> _needs(AppLocalizations t) => [
      (UserIntent.buy, Icons.search, t.profileNeedBuy, t.profileNeedBuyBody),
      (UserIntent.sell, Icons.directions_car_outlined, t.profileNeedSell, t.profileNeedSellBody),
      (UserIntent.dealer, Icons.storefront_outlined, t.profileNeedDealer, t.profileNeedDealerBody),
    ];

/// Saves the choice (phone first, then the account) and, for a dealer,
/// opens the VAT check.
Future<void> _choose(BuildContext context, WidgetRef ref, UserIntent intent) async {
  final controller = ref.read(onboardingControllerProvider.notifier);
  final router = GoRouter.of(context);
  controller.setIntent(intent);
  await controller.savePreferences();
  if (intent == UserIntent.dealer) router.push(AppRoutes.onboardingDealer);
}

/// "Sto solo guardando": no role imposed, the user picks what they need.
class _NeedsCard extends ConsumerWidget {
  const _NeedsCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    return Container(
      key: const ValueKey('needs-card'),
      padding: const EdgeInsets.all(AppSpacing.l),
      decoration: BoxDecoration(
        color: AppColors.primarySoft,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(t.profileNeedsTitle, style: text.titleMedium),
          const SizedBox(height: AppSpacing.m),
          for (final (intent, icon, title, body) in _needs(t)) ...[
            Material(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadius.m),
              child: ListTile(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.m)),
                leading: Icon(icon, color: AppColors.primary),
                title: Text(title, style: text.titleSmall),
                subtitle: Text(body),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _choose(context, ref, intent),
              ),
            ),
            const SizedBox(height: AppSpacing.s),
          ],
        ],
      ),
    );
  }
}

/// "Cambia": the same choices plus "Sto solo guardando".
Future<void> showNeedsSheet(BuildContext context) => showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => Consumer(
        builder: (sheetContext, ref, _) {
          final t = AppLocalizations.of(sheetContext);
          final current = ref.read(onboardingControllerProvider).intent;
          final options = [
            ..._needs(t),
            (UserIntent.browse, Icons.visibility_outlined, t.profileNeedBrowse, t.profileNeedBrowseBody),
          ];
          return SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(title: Text(t.profileNeedsTitle, style: Theme.of(sheetContext).textTheme.titleMedium)),
                for (final (intent, icon, title, body) in options)
                  ListTile(
                    leading: Icon(icon),
                    title: Text(title),
                    subtitle: Text(body),
                    trailing: current == intent ? const Icon(Icons.check, color: AppColors.primary) : null,
                    onTap: () {
                      Navigator.pop(sheetContext);
                      // The profile's context: the sheet is closing.
                      if (context.mounted) _choose(context, ref, intent);
                    },
                  ),
              ],
            ),
          );
        },
      ),
    );

/// A guest who wants to sell: sign in, then the listings live here.
class _SellerGuestCard extends StatelessWidget {
  const _SellerGuestCard();

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.l),
      decoration: BoxDecoration(color: AppColors.primarySoft, borderRadius: BorderRadius.circular(18)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(t.myListingsTitle, style: text.titleSmall),
          const SizedBox(height: AppSpacing.xs),
          Text(t.profileSellerGuest, style: text.bodyMedium),
          const SizedBox(height: AppSpacing.m),
          FilledButton(onPressed: () => context.push(AppRoutes.sell), child: Text(t.myListingsSell)),
        ],
      ),
    );
  }
}

/// Chose "concessionario" without finishing the VAT check.
class _DealerPendingCard extends StatelessWidget {
  const _DealerPendingCard();

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.l),
      decoration: BoxDecoration(color: AppColors.primarySoft, borderRadius: BorderRadius.circular(18)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(t.profileDealerPendingTitle, style: text.titleSmall),
          const SizedBox(height: AppSpacing.xs),
          Text(t.profileDealerPendingBody, style: text.bodyMedium),
          const SizedBox(height: AppSpacing.m),
          FilledButton(
            onPressed: () => context.push(AppRoutes.onboardingDealer),
            child: Text(t.profileDealerPendingCta),
          ),
        ],
      ),
    );
  }
}

/// A dealer account: totals over its listings and its public page.
class _DealerCard extends ConsumerWidget {
  const _DealerCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final dealer = ref.watch(myDealerProvider).value;
    final listings = ref.watch(myListingsProvider).value ?? const [];
    final active = listings.where((l) => l.isActive).toList();
    final saves = active.fold<int>(0, (sum, l) => sum + l.saves);
    final chats = listings.fold<int>(0, (sum, l) => sum + l.chats);

    Widget stat(String value, String label) => Expanded(
          child: Column(
            children: [
              Text(value, style: text.headlineSmall),
              Text(label, style: text.bodySmall, textAlign: TextAlign.center),
            ],
          ),
        );

    return Container(
      key: const ValueKey('dealer-card'),
      padding: const EdgeInsets.all(AppSpacing.l),
      decoration: BoxDecoration(color: AppColors.primarySoft, borderRadius: BorderRadius.circular(18)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              stat('${active.length}', t.profileDealerActive),
              stat('$saves', t.profileDealerSaves),
              stat('$chats', t.profileDealerChats),
            ],
          ),
          if (dealer != null) ...[
            const SizedBox(height: AppSpacing.m),
            OutlinedButton.icon(
              onPressed: () => context.push(AppRoutes.sellerPagePath(id: dealer.id, dealer: true)),
              icon: const Icon(Icons.storefront_outlined, size: 18),
              label: Text(t.profileDealerPage),
            ),
          ],
        ],
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
