import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// Selectable pill used in onboarding, filters and preferences.
/// Selected = solid blue; unselected = white with border; dashed = "+ Altre".
class Pill extends StatelessWidget {
  const Pill({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.dashed = false,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final bool dashed;

  @override
  Widget build(BuildContext context) {
    final background = selected ? AppColors.primary : AppColors.surface;
    final foreground = selected ? Colors.white : AppColors.ink;
    final borderColor = selected
        ? AppColors.primary
        : (dashed ? AppColors.borderStrong : AppColors.border);

    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: background,
        shape: StadiumBorder(side: BorderSide(color: borderColor)),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 40),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              child: Text(
                label,
                style: TextStyle(
                  fontFamily: AppFonts.body,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: foreground,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Wraps pills on multiple lines with the standard spacing.
class PillWrap extends StatelessWidget {
  const PillWrap({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) =>
      Wrap(spacing: AppSpacing.s, runSpacing: AppSpacing.s, children: children);
}

/// Section label above a group of pills.
class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.s),
        child: Text(
          text,
          style: const TextStyle(
            fontFamily: AppFonts.body,
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: AppColors.inkSecondary,
          ),
        ),
      );
}