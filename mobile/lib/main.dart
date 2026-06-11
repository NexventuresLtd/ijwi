import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'core/supabase.dart';
import 'core/theme.dart';
import 'core/theme_notifier.dart';
import 'core/router.dart';
import 'core/notifications.dart';
import 'shared/widgets/splash_screen.dart';
import 'shared/widgets/onboarding_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );
  await initSupabase();
  await themeNotifier.init();
  await initNotifications();
  runApp(const IjwiApp());
}

class IjwiApp extends StatefulWidget {
  const IjwiApp({super.key});
  @override
  State<IjwiApp> createState() => _IjwiAppState();
}

enum _AppState { splash, onboarding, ready }

class _IjwiAppState extends State<IjwiApp> {
  _AppState _state = _AppState.splash;
  bool _needsOnboarding = false;

  @override
  void initState() {
    super.initState();
    themeNotifier.addListener(_onThemeChange);
    _checkOnboarding();
  }

  @override
  void dispose() {
    themeNotifier.removeListener(_onThemeChange);
    super.dispose();
  }

  void _onThemeChange() => setState(() {});

  Future<void> _checkOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    _needsOnboarding = !(prefs.getBool('ijwi_onboarded') ?? false);
  }

  void _splashDone() {
    setState(() => _state = _needsOnboarding ? _AppState.onboarding : _AppState.ready);
    if (!_needsOnboarding) startNotificationListener();
  }

  void _onboardingDone() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('ijwi_onboarded', true);
    setState(() => _state = _AppState.ready);
    startNotificationListener();
  }

  @override
  Widget build(BuildContext context) {
    switch (_state) {
      case _AppState.splash:
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: IjwiTheme.dark(),
          home: SplashScreen(onComplete: _splashDone),
        );
      case _AppState.onboarding:
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: IjwiTheme.dark(),
          home: OnboardingScreen(onComplete: _onboardingDone),
        );
      case _AppState.ready:
        return MaterialApp.router(
          title: 'Ijwi',
          debugShowCheckedModeBanner: false,
          theme: IjwiTheme.light(),
          darkTheme: IjwiTheme.dark(),
          themeMode: themeNotifier.mode,
          routerConfig: router,
        );
    }
  }
}
