import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/chat/ui/chat_screen.dart';
import '../../features/chat/ui/inbox_screen.dart';
import '../../features/feed/ui/feed_screen.dart';
import '../../features/legal/ui/consent_gate.dart';
import '../../features/listing/ui/listing_screen.dart';
import '../../features/onboarding/ui/dealer_signup_screen.dart';
import '../../features/onboarding/ui/intent_screen.dart';
import '../../features/onboarding/ui/preferences_screen.dart';
import '../../features/profile/ui/profile_screen.dart';
import '../../features/search/ui/search_screen.dart';
import '../../features/settings/ui/settings_screen.dart';
import '../media/shared_video.dart';
import '../widgets/placeholder_screen.dart';
import 'main_shell.dart';
import 'routes.dart';

final _rootKey = GlobalKey<NavigatorState>(debugLabel: 'root');

/// Full-screen page that slides up, used for onboarding.
Page<void> _modal(GoRouterState state, Widget child) =>
    MaterialPage<void>(key: state.pageKey, fullscreenDialog: true, child: child);

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    navigatorKey: _rootKey,
    initialLocation: AppRoutes.feed,
    debugLogDiagnostics: false,

    // The app always lands on the feed. Onboarding is never forced:
    // it opens over the feed on first launch and can be skipped.

    errorBuilder: (context, state) =>
        const PlaceholderScreen(title: 'Pagina non trovata'),

    routes: [
      // ---- Bottom navigation (state kept per tab) ----
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => ConsentGate(child: MainShell(shell: shell)),
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(
              path: AppRoutes.feed,
              builder: (_, __) => const FeedScreen(),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: AppRoutes.search,
              builder: (_, __) => const SearchScreen(),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: AppRoutes.inbox,
              builder: (_, _) => const InboxScreen(),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: AppRoutes.profile,
              builder: (_, __) => const ProfileScreen(),
            ),
          ]),
        ],
      ),

      // ---- Full screen, above the tabs ----
      GoRoute(
        path: AppRoutes.onboarding,
        parentNavigatorKey: _rootKey,
        pageBuilder: (_, state) => _modal(state, const IntentScreen()),
        routes: [
          GoRoute(
            path: 'preferences',
            parentNavigatorKey: _rootKey,
            builder: (_, state) => PreferencesScreen(
              editing: state.uri.queryParameters['edit'] == '1',
            ),
          ),
          GoRoute(
            path: 'dealer',
            parentNavigatorKey: _rootKey,
            builder: (_, __) => const DealerSignupScreen(),
          ),
        ],
      ),
      GoRoute(
        path: AppRoutes.sell,
        parentNavigatorKey: _rootKey,
        builder: (_, __) => const PlaceholderScreen(title: 'Cosa vuoi vendere?'),
      ),
      GoRoute(
        path: AppRoutes.listing,
        parentNavigatorKey: _rootKey,
        builder: (_, state) => ListingScreen(
          id: state.pathParameters['id']!,
          // Set when opened from the feed: the video already loaded there.
          lentVideo: state.extra is SharedVideo ? state.extra as SharedVideo : null,
        ),
      ),
      GoRoute(
        path: AppRoutes.shareShort,
        redirect: (_, state) =>
            AppRoutes.listingPath(state.pathParameters['id']!),
      ),
      GoRoute(
        path: AppRoutes.newChat,
        parentNavigatorKey: _rootKey,
        builder: (_, state) => ChatScreen(listingId: state.pathParameters['listingId']),
      ),
      GoRoute(
        path: AppRoutes.chat,
        parentNavigatorKey: _rootKey,
        builder: (_, state) => ChatScreen(conversationId: state.pathParameters['id']),
      ),
      GoRoute(
        path: AppRoutes.settings,
        parentNavigatorKey: _rootKey,
        builder: (_, _) => const SettingsScreen(),
      ),
      GoRoute(
        path: AppRoutes.dealerDashboard,
        parentNavigatorKey: _rootKey,
        builder: (_, __) => const PlaceholderScreen(title: 'Dashboard'),
      ),
    ],
  );
});