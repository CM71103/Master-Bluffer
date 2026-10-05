import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'screens/splash_screen.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'screens/lobby_screen.dart';
import 'screens/game_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/leaderboard_screen.dart';
import 'services/notification_service.dart';
import 'firebase_options.dart';
import 'theme.dart';

void main() async {
  // Must run before anything that talks to native code (Firebase, notifications).
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  } catch (e) {
    debugPrint('Firebase FAILED $e');
  }
  await NotificationService.instance.init();
  runApp(const BluffMasterApp());
}

class BluffMasterApp extends StatelessWidget {
  const BluffMasterApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Bluff Master',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      home: const SplashScreen(),
      routes: {
        '/auth': (context) => const AuthGate(),
        '/login': (context) => const LoginScreen(),
        '/home': (context) => const HomeScreen(),
        '/lobby': (context) => const LobbyScreen(),
        '/game': (context) => const GameScreen(),
        '/profile': (context) => const ProfileScreen(),
        '/leaderboard': (context) => const LeaderboardScreen(),
      },
    );
  }
}

/// Listens to Firebase Auth. Because Firebase restores the saved user on
/// start-up, a logged-in user lands on Home after an app restart, and signing
/// out switches back to Login automatically.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        return snapshot.hasData ? const HomeScreen() : const LoginScreen();
      },
    );
  }
}
