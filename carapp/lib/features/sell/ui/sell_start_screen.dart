import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/routes.dart';
import '../../../core/supabase/supabase_client.dart';
import '../../../core/theme/tokens.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../../auth/ui/login_sheet.dart';
import '../data/sell_draft.dart';
import '../state/sell_controller.dart';

/// `/sell` (screen 1): auto or moto, what to prepare, start. Shows the
/// draft left on the phone, if any.
class SellStartScreen extends ConsumerStatefulWidget {
  const SellStartScreen({super.key});

  @override
  ConsumerState<SellStartScreen> createState() => _SellStartScreenState();
}

class _SellStartScreenState extends ConsumerState<SellStartScreen> {
  late final SellDraft? _saved = ref.read(sellControllerProvider.notifier).savedDraft();
  late String _category = _saved?.categoryId ?? 'car';
  bool _busy = false;

  void _close() => context.canPop() ? context.pop() : context.go(AppRoutes.feed);

  Future<void> _begin({required bool fresh}) async {
    if (_busy) return;
    final controller = ref.read(sellControllerProvider.notifier);
    if (ref.read(currentUserProvider) == null) {
      final ok = await showLoginSheet(context);
      if (!ok || !mounted) return;
    }
    setState(() => _busy = true);
    try {
      await controller.start(_category, fresh: fresh);
      if (!mounted) return;
      final s = ref.read(sellControllerProvider);
      final draft = s.draft!;
      // Resuming with every required shot done: straight to the summary.
      if (draft.missingIn(s.steps).isEmpty && draft.shots.isNotEmpty) {
        context.push(AppRoutes.sellShots);
      } else {
        context.push(AppRoutes.sellCapturePath());
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _restart() async {
    final t = AppLocalizations.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(t.sellRestartTitle),
        content: Text(t.sellRestartBody),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(MaterialLocalizations.of(context).cancelButtonLabel)),
          TextButton(onPressed: () => Navigator.pop(context, true), child: Text(t.sellRestart)),
        ],
      ),
    );
    if (ok == true && mounted) await _begin(fresh: true);
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final saved = _saved;

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.s, AppSpacing.s, AppSpacing.s, 0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: IconButton(
                  tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
                  icon: const Icon(Icons.close),
                  onPressed: _close,
                ),
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.page),
                children: [
                  Text(t.sellTitle, style: text.headlineSmall),
                  const SizedBox(height: AppSpacing.xs),
                  Text(t.sellSubtitle, style: text.bodyMedium),
                  const SizedBox(height: AppSpacing.xl),
                  Row(
                    children: [
                      Expanded(
                        child: _CategoryCard(
                          icon: Icons.directions_car_outlined,
                          title: t.sellCar,
                          subtitle: t.sellCarHint,
                          selected: _category == 'car',
                          onTap: () => setState(() => _category = 'car'),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.m),
                      Expanded(
                        child: _CategoryCard(
                          icon: Icons.two_wheeler,
                          title: t.sellMoto,
                          subtitle: t.sellMotoHint,
                          selected: _category == 'motorcycle',
                          onTap: () => setState(() => _category = 'motorcycle'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.l),
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.l),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceAlt,
                      borderRadius: BorderRadius.circular(AppRadius.m),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(t.sellBeforeTitle, style: text.titleSmall),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          _category == 'motorcycle' ? t.sellBeforeMoto : t.sellBeforeCar,
                          style: text.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                  if (saved != null) ...[
                    const SizedBox(height: AppSpacing.l),
                    Container(
                      key: const ValueKey('sell-draft'),
                      padding: const EdgeInsets.all(AppSpacing.l),
                      decoration: BoxDecoration(
                        border: Border.all(color: AppColors.primary),
                        borderRadius: BorderRadius.circular(AppRadius.m),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(t.sellDraftTitle, style: text.titleSmall),
                          const SizedBox(height: AppSpacing.xxs),
                          Text(
                            '${saved.categoryId == 'motorcycle' ? t.sellMoto : t.sellCar} · '
                            '${t.sellDraftBody(saved.shots.length)}',
                            style: text.bodyMedium,
                          ),
                          const SizedBox(height: AppSpacing.s),
                          Row(
                            children: [
                              TextButton(
                                onPressed: _busy ? null : _restart,
                                child: Text(t.sellRestart),
                              ),
                              const Spacer(),
                              FilledButton.tonal(
                                onPressed: _busy
                                    ? null
                                    : () {
                                        setState(() => _category = saved.categoryId);
                                        _begin(fresh: false);
                                      },
                                child: Text(t.sellResume),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.page, AppSpacing.s, AppSpacing.page, AppSpacing.l),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  FilledButton(
                    // Another category than the draft's: confirm before dropping it.
                    onPressed: _busy
                        ? null
                        : saved != null && saved.categoryId != _category
                            ? _restart
                            : () => _begin(fresh: false),
                    child: _busy
                        ? const SizedBox.square(
                            dimension: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : Text(saved != null && saved.categoryId == _category ? t.sellResume : t.sellStart),
                  ),
                  const SizedBox(height: AppSpacing.s),
                  Text(t.sellStartNote, style: text.bodySmall, textAlign: TextAlign.center),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryCard extends StatelessWidget {
  const _CategoryCard({
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
    final text = Theme.of(context).textTheme;
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: selected ? AppColors.primarySoft : AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.m),
          side: BorderSide(color: selected ? AppColors.primary : AppColors.border, width: selected ? 2 : 1),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.m),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxl),
            child: Column(
              children: [
                Icon(icon, size: 30, color: AppColors.ink),
                const SizedBox(height: AppSpacing.s),
                Text(title, style: text.titleMedium),
                const SizedBox(height: 2),
                Text(subtitle, style: text.bodySmall),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
