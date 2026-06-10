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
import '../features/events/screens/live_room_screen.dart';
import '../features/notifications/screens/notifications_screen.dart';
import '../features/settings/screens/settings_screen.dart';
import '../features/write/screens/write_screen.dart';
import '../features/explore/screens/explore_screen.dart';
import '../features/sparks/screens/create_spark_screen.dart';
import '../features/saved/screens/saved_posts_screen.dart';
import '../shared/widgets/app_shell.dart';

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
        GoRoute(path: '/dms', builder: (_, __) => const DmsListScreen()),
        GoRoute(path: '/notifications', builder: (_, __) => const NotificationsScreen()),
        GoRoute(path: '/profile', builder: (_, __) => const ProfileScreen()),
      ],
    ),

    // Detail routes (outside shell for full-screen)
    GoRoute(path: '/post/:id', builder: (_, state) => PostDetailScreen(postId: state.pathParameters['id']!)),
    GoRoute(path: '/profile/:id', builder: (_, state) => ProfileScreen(userId: state.pathParameters['id'])),
    GoRoute(path: '/dms/:userId', builder: (_, state) => ChatScreen(otherUserId: state.pathParameters['userId']!)),
    GoRoute(path: '/events/create', builder: (_, __) => const EventCreateScreen()),
    GoRoute(path: '/events/:id', builder: (_, state) => EventDetailScreen(eventId: state.pathParameters['id']!)),
    GoRoute(path: '/events/:id/live', builder: (_, state) => LiveRoomScreen(eventId: state.pathParameters['id']!)),
    GoRoute(path: '/settings', builder: (_, __) => const SettingsScreen()),
    GoRoute(path: '/write', builder: (_, __) => const WriteScreen()),
    GoRoute(path: '/explore', builder: (_, __) => const ExploreScreen()),
    GoRoute(path: '/sparks/create', builder: (_, __) => const CreateSparkScreen()),
    GoRoute(path: '/saved', builder: (_, __) => const SavedPostsScreen()),
  ],
);
