import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// Temporary screen used by the router until each feature is built.
class PlaceholderScreen extends StatelessWidget {
  const PlaceholderScreen({super.key, required this.title, this.dark = false});

  final String title;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: dark ? AppColors.feedBackground : AppColors.surface,
      body: Center(
        child: Text(
          title,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: dark ? Colors.white : AppColors.ink,
              ),
        ),
      ),
    );
  }
}
