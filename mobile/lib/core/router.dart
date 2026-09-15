import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../core/supabase.dart';
import '../features/auth/screens/login_screen.dart';
import '../features/auth/screens/signup_screen.dart';
import '../features/auth/screens/forgot_password_screen.dart';
import '../features/feed/screens/feed_screen.dart';
import '../features/feed/screens/post_detail_screen.dart';
import '../features/profile/screens/profile_screen.dart';
import '../features/dms/screens/dms_list_screen.dart';
import '../features/dms/screens/chat_screen.dart';
import '../features/events/screens/events_screen.dart';
import '../features/events/screens/event_detail_screen.dart';
import '../features/events/screens/event_create_screen.dart';
import '../features/events/screens/event_success_screen.dart';
import '../features/events/screens/event_booked_screen.dart';
import '../features/events/screens/event_checkout_screen.dart';
import '../features/events/screens/live_room_screen.dart';
import '../features/events/screens/my_events_screen.dart';
import '../features/events/screens/manage_event_screen.dart';
import '../features/events/screens/event_scanner_screen.dart';
import '../features/events/screens/my_ticket_detail_screen.dart';
import '../features/events/screens/wallet_screen.dart';
import '../features/events/screens/cashout_screen.dart';
import '../features/events/screens/cashout_success_screen.dart';
import '../features/events/screens/wallet_settings_screen.dart';
import '../features/events/screens/wallet_biometrics_screen.dart';
import '../features/events/screens/wallet_pin_screen.dart';
import '../features/events/screens/wallet_pattern_screen.dart';
import '../features/events/screens/security_reset_screen.dart';
import '../features/notifications/screens/notifications_screen.dart';
import '../features/settings/screens/settings_screen.dart';
import '../features/write/screens/write_screen.dart';
import '../features/write/screens/edit_post_screen.dart';
import '../shared/widgets/publish_success_screen.dart';
import '../features/explore/screens/explore_screen.dart';
import '../features/sparks/screens/create_spark_screen.dart';
import '../features/sparks/screens/sparks_viewer_screen.dart';
import '../features/saved/screens/saved_posts_screen.dart';
import '../features/privacy/screens/privacy_screen.dart';
import '../features/privacy/screens/blocked_users_screen.dart';
import '../features/notifications/screens/notification_prefs_screen.dart';
import '../features/essay/screens/create_essay_screen.dart';
import '../features/essay/screens/essay_reader_screen.dart';
import '../shared/widgets/app_shell.dart';
import '../features/camera/screens/custom_camera_screen.dart';

final _rootKey = GlobalKey<NavigatorState>();
final _shellKey = GlobalKey<NavigatorState>();

final router = GoRouter(
  navigatorKey: _rootKey,
  initialLocation: '/feed',
  redirect: (context, state) {
    final loggedIn = supabase.auth.currentUser != null;
    final onAuth = state.matchedLocation.startsWith('/auth');
    if (!loggedIn && !onAuth) return '/auth/login';
    if (loggedIn && onAuth) return '/feed';
    return null;
  },
  routes: [
    // Auth routes (no shell)
    GoRoute(path: '/auth/login', builder: (_, __) => const LoginScreen()),
    GoRoute(path: '/auth/signup', builder: (_, __) => const SignupScreen()),
    GoRoute(path: '/auth/forgot-password', builder: (_, __) => const ForgotPasswordScreen()),

    // Main app with bottom nav shell
    ShellRoute(
      navigatorKey: _shellKey,
      builder: (_, __, child) => AppShell(child: child),
      routes: [
        GoRoute(path: '/feed', builder: (_, __) => const FeedScreen()),
        GoRoute(path: '/events', builder: (_, __) => const EventsScreen()),
        GoRoute(path: '/my-events', builder: (_, __) => const MyEventsScreen()),
        GoRoute(path: '/dms', builder: (_, __) => const DmsListScreen()),

        GoRoute(path: '/notifications', builder: (_, __) => const NotificationsScreen()),
        GoRoute(path: '/profile', builder: (_, __) => const ProfileScreen()),
      ],
    ),

    // Detail routes (outside shell for full-screen)
    GoRoute(path: '/wallet', builder: (_, __) => const WalletScreen(), routes: [
      GoRoute(path: 'cashout', builder: (_, state) => CashoutScreen(availableBalance: state.extra as double), routes: [
        GoRoute(path: 'success', builder: (_, state) => CashoutSuccessScreen(amount: state.extra as double)),
      ]),
      GoRoute(path: 'settings', builder: (_, __) => const WalletSettingsScreen(), routes: [
        GoRoute(path: 'biometrics', builder: (_, __) => const WalletBiometricsScreen()),
        GoRoute(path: 'pin', builder: (_, __) => const WalletPinScreen()),
        GoRoute(path: 'pattern', builder: (_, __) => const WalletPatternScreen()),
      ]),
      GoRoute(path: 'security_reset', builder: (_, __) => const SecurityResetScreen()),
    ]),
    GoRoute(path: '/post/:id', builder: (_, state) => PostDetailScreen(postId: state.pathParameters['id']!)),
    GoRoute(path: '/profile/:id', builder: (_, state) => ProfileScreen(userId: state.pathParameters['id'])),
    GoRoute(path: '/dms/:userId', builder: (_, state) => ChatScreen(otherUserId: state.pathParameters['userId']!)),
    GoRoute(
      path: '/events/create', 
      builder: (context, state) => EventCreateScreen(
        type: state.uri.queryParameters['type'],
        eventId: state.uri.queryParameters['eventId'],
      ),
    ),
    GoRoute(path: '/events/success', builder: (_, __) => const EventSuccessScreen()),
    GoRoute(path: '/events/booked', builder: (_, __) => const EventBookedScreen()),
    GoRoute(path: '/events/:id/checkout', builder: (_, state) => EventCheckoutScreen(eventId: state.pathParameters['id']!)),
    GoRoute(path: '/events/:id', builder: (_, state) => EventDetailScreen(eventId: state.pathParameters['id']!)),
    GoRoute(path: '/events/:id/live', builder: (_, state) => LiveRoomScreen(eventId: state.pathParameters['id']!)),
    GoRoute(path: '/settings', builder: (_, __) => const SettingsScreen()),
    GoRoute(path: '/write', builder: (_, __) => const WriteScreen()),
    GoRoute(path: '/write/edit/:id', builder: (_, state) => EditPostScreen(postId: state.pathParameters['id']!)),
    GoRoute(path: '/publish-success/:id/:type', builder: (_, state) => PublishSuccessScreen(postId: state.pathParameters['id']!, type: state.pathParameters['type']!)),
    GoRoute(path: '/explore', builder: (_, state) => ExploreScreen(initialQuery: state.uri.queryParameters['q'])),
    GoRoute(path: '/sparks/create', builder: (_, __) => const CreateSparkScreen()),
    GoRoute(path: '/sparks', builder: (_, state) => SparksViewerScreen(
      initialIndex: int.tryParse(state.uri.queryParameters['i'] ?? '0') ?? 0,
      initialPostId: state.uri.queryParameters['id'],
    )),
    GoRoute(path: '/camera', builder: (_, state) => CustomCameraScreen(initialIsVideo: state.uri.queryParameters['video'] == 'true')),
    GoRoute(path: '/saved', builder: (_, __) => const SavedPostsScreen()),
    GoRoute(path: '/privacy', builder: (_, __) => const PrivacyScreen()),
    GoRoute(path: '/privacy/blocked-users', builder: (_, __) => const BlockedUsersScreen()),
    GoRoute(path: '/notification-prefs', builder: (_, __) => const NotificationPrefsScreen()),
    GoRoute(path: '/essay/create', builder: (_, __) => const CreateEssayScreen()),
    GoRoute(path: '/essay/:id', builder: (_, state) => EssayReaderScreen(essay: state.extra as Map<String, dynamic>)),
    GoRoute(path: '/my-events/:id', builder: (_, state) => ManageEventScreen(eventId: state.pathParameters['id']!)),
    GoRoute(path: '/my-events/:id/scan', builder: (_, state) => EventScannerScreen(eventId: state.pathParameters['id']!)),
    GoRoute(path: '/my-tickets/:id', builder: (_, state) => MyTicketDetailScreen(eventId: state.pathParameters['id']!)),
  ],
);
