import 'package:flutter/widgets.dart';

/// Closes every onboarding screen and returns to whatever was underneath
/// (usually the feed), so the feed resumes exactly where the user was.
void exitOnboarding(BuildContext context) {
  Navigator.of(context, rootNavigator: true).popUntil((route) => route.isFirst);
}