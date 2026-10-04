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
  static const sellCapture = '/sell/capture';
  static const sellShots = '/sell/shots';
  static const sellDetails = '/sell/shots/details';
  static const sellDone = '/sell/done/:id';
  static const listing = '/listing/:id';
  static const editListing = '/listing/:id/edit';
  static const chat = '/chat/:id';
  static const newChat = '/chat/new/:listingId';
  static const archivedChats = '/chats/archived';
  static const dealerDashboard = '/dealer';
  static const settings = '/settings';
  static const dealerPage = '/dealers/:id';
  static const sellerPage = '/seller/:id';

  /// Short share link: https://<domain>/l/<id> -> /listing/<id>
  static const shareShort = '/l/:id';

  static String listingPath(String id) => '/listing/$id';
  static String editListingPath(String id) => '/listing/$id/edit';
  static String chatPath(String id) => '/chat/$id';

  /// [step] null = the first step still missing; [single] = retake one
  /// step and come back to the summary.
  /// Video steps, or with [photos] the guided carousel photos ([step] =
  /// the slot to start from).
  static String sellCapturePath({String? step, bool photos = false, bool single = false}) {
    final query = {'step': ?step, if (photos) 'photos': '1', if (single) 'single': '1'};
    return Uri(path: sellCapture, queryParameters: query.isEmpty ? null : query).toString();
  }
  static String sellDonePath(String listingId) => '/sell/done/$listingId';

  /// Public page of a seller: a dealer (dealers.id) or a private seller
  /// (profiles.id).
  static String sellerPagePath({required String id, required bool dealer}) =>
      dealer ? '/dealers/$id' : '/seller/$id';
  static String newChatPath(String listingId) => '/chat/new/$listingId';

  /// Reachable without completing onboarding (a shared link must open
  /// straight on the listing, even on first launch).
  static bool isPublicDeepLink(String location) =>
      location.startsWith('/listing/') || location.startsWith('/l/');
}
