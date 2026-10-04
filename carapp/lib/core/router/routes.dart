/// Every path in the app. Deep links use the same paths.
class AppRoutes {
  AppRoutes._();

  // Tabs (inside the bottom navigation shell)
  static const feed = '/feed';
  static const search = '/search';
  static const inbox = '/inbox';
  static const profile = '/profile';

  // Full screen
  static const onboarding = '/onboarding';
  static const onboardingPreferences = '/onboarding/preferences';
  static const onboardingDealer = '/onboarding/dealer';
  static const sell = '/sell';
  static const listing = '/listing/:id';
  static const chat = '/chat/:id';
  static const dealerDashboard = '/dealer';
  static const settings = '/settings';

  /// Short share link: https://<domain>/l/<id> -> /listing/<id>
  static const shareShort = '/l/:id';

  static String listingPath(String id) => '/listing/$id';
  static String chatPath(String id) => '/chat/$id';

  /// Reachable without completing onboarding (a shared link must open
  /// straight on the listing, even on first launch).
  static bool isPublicDeepLink(String location) =>
      location.startsWith('/listing/') || location.startsWith('/l/');
}
