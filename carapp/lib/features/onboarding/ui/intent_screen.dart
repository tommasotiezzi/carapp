import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/routes.dart';
import '../../../core/theme/tokens.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../../auth/ui/login_sheet.dart';
import '../data/buyer_preferences.dart';
import '../state/onboarding_controller.dart';
import 'onboarding_exit.dart';

/// "Cosa vuoi fare?" Opens over the feed on first launch; always skippable.
class IntentScreen extends ConsumerWidget {
  const IntentScreen({super.key});

  Future<void> _continue(BuildContext context, WidgetRef ref, UserIntent intent) async {
    final controller = ref.read(onboardingControllerProvider.notifier);
    final router = GoRouter.of(context);

    switch (intent) {
      case UserIntent.buy:
        router.push(AppRoutes.onboardingPreferences);
      case UserIntent.dealer:
        router.push(AppRoutes.onboardingDealer);
      case UserIntent.sell:
        await controller.complete();
        if (!context.mounted) return;
        exitOnboarding(context);
        router.push(AppRoutes.sell);
      case UserIntent.browse:
        await controller.complete();
        if (context.mounted) exitOnboarding(context);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final selected = ref.watch(onboardingControllerProvider.select((s) => s.intent));
    final controller = ref.read(onboardingControllerProvider.notifier);

    final options = [
      (UserIntent.buy, Icons.search, t.intentBuy, t.intentBuySubtitle),
      (UserIntent.sell, Icons.directions_car_outlined, t.intentSell, t.intentSellSubtitle),
      (UserIntent.dealer, Icons.storefront_outlined, t.intentDealer, t.intentDealerSubtitle),
      (UserIntent.browse, Icons.visibility_outlined, t.intentBrowse, t.intentBrowseSubtitle),
    ];

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.xl, AppSpacing.s, AppSpacing.xl, AppSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () async {
                    await controller.skip();
                    if (context.mounted) exitOnboarding(context);
                  },
                  child: Text(t.commonSkip),
                ),
              ),
              const SizedBox(height: AppSpacing.l),
              Text(t.onboardingTitle, style: text.displaySmall),
              const SizedBox(height: AppSpacing.s),
              Text(t.onboardingSubtitle, style: text.bodyMedium?.copyWith(fontSize: 15)),
              const SizedBox(height: AppSpacing.xxl),
              for (final (intent, icon, title, subtitle) in options) ...[
                _IntentCard(
                  icon: icon,
                  title: title,
                  subtitle: subtitle,
                  selected: selected == intent,
                  onTap: () => controller.setIntent(intent),
                ),
                const SizedBox(height: AppSpacing.m),
              ],
              const Spacer(),
              FilledButton(
                onPressed: selected == null ? null : () => _continue(context, ref, selected),
                child: Text(t.commonContinue),
              ),
              const SizedBox(height: AppSpacing.s),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(t.onboardingHaveAccount, style: text.bodyMedium),
                  TextButton(
                    onPressed: () async {
                      final ok = await showLoginSheet(context);
                      if (ok) {
                        await controller.skip();
                        if (context.mounted) exitOnboarding(context);
                      }
                    },
                    child: Text(t.onboardingLogin),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _IntentCard extends StatelessWidget {
  const _IntentCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: selected ? AppColors.primarySoft : AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(
            color: selected ? AppColors.primary : AppColors.border,
            width: selected ? 2 : 1,
          ),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.l, vertical: 16),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: selected ? AppColors.primary : AppColors.surfaceAlt,
                    borderRadius: BorderRadius.circular(AppRadius.m),
                  ),
                  child: Icon(icon, color: selected ? Colors.white : AppColors.ink),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: AppColors.ink,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: const TextStyle(fontSize: 13, color: AppColors.inkSecondary),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}