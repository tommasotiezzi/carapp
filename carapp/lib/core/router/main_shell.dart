import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/gen/app_localizations.dart';
import '../theme/tokens.dart';
import 'routes.dart';

/// Bottom navigation: Home, Cerca, Vendi (opens a full-screen flow), Inbox, Profilo.
/// Always dark, on every tab, like TikTok.
class MainShell extends StatelessWidget {
  const MainShell({super.key, required this.shell});

  final StatefulNavigationShell shell;

  // Visual slots: 0 home, 1 search, 2 sell, 3 inbox, 4 profile.
  // Shell branches: 0 feed, 1 search, 2 inbox, 3 profile.
  static int _branchFor(int slot) => slot > 2 ? slot - 1 : slot;
  static int _slotFor(int branch) => branch >= 2 ? branch + 1 : branch;

  void _onTap(BuildContext context, int slot) {
    if (slot == 2) {
      context.push(AppRoutes.sell);
      return;
    }
    final branch = _branchFor(slot);
    // Tapping the current tab again returns to its first page.
    shell.goBranch(branch, initialLocation: branch == shell.currentIndex);
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: AppColors.feedBackground,
      body: shell,
      bottomNavigationBar: _BottomBar(
        selectedSlot: _slotFor(shell.currentIndex),
        onTap: (slot) => _onTap(context, slot),
        labels: [t.navHome, t.navSearch, t.navSell, t.navInbox, t.navProfile],
      ),
    );
  }
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({
    required this.selectedSlot,
    required this.onTap,
    required this.labels,
  });

  final int selectedSlot;
  final ValueChanged<int> onTap;
  final List<String> labels;

  static const _icons = [
    Icons.home_outlined,
    Icons.search,
    Icons.add,
    Icons.chat_bubble_outline,
    Icons.person_outline,
  ];
  static const _activeIcons = [
    Icons.home,
    Icons.search,
    Icons.add,
    Icons.chat_bubble,
    Icons.person,
  ];

  @override
  Widget build(BuildContext context) {
    const active = Colors.white;
    const inactive = Color(0xFFA7AEB7);

    return DecoratedBox(
      decoration: const BoxDecoration(
        color: AppColors.feedBackground,
        border: Border(top: BorderSide(color: Color(0x14FFFFFF))),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 60,
          child: Row(
            children: List.generate(5, (slot) {
              final selected = slot == selectedSlot;
              final isSell = slot == 2;
              final color = selected ? active : inactive;

              return Expanded(
                child: Semantics(
                  button: true,
                  selected: selected,
                  label: labels[slot],
                  child: InkResponse(
                    onTap: () => onTap(slot),
                    radius: 32,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (isSell)
                          Container(
                            width: 44,
                            height: 30,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(9),
                            ),
                            child: const Icon(Icons.add, size: 20, color: AppColors.ink),
                          )
                        else
                          Icon(
                            selected ? _activeIcons[slot] : _icons[slot],
                            size: 24,
                            color: color,
                          ),
                        const SizedBox(height: 3),
                        Text(
                          labels[slot],
                          style: TextStyle(
                            fontFamily: AppFonts.body,
                            fontSize: 11,
                            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                            color: color,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}
