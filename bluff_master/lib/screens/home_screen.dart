import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/socket_service.dart';
import '../theme.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  Future<void> _logout(BuildContext context) async {
    SocketService.instance.disconnect();
    await FirebaseAuth.instance.signOut();
    // AuthGate (the root route) now shows the Login screen. Clear any
    // screens still on top so the user cannot go "back" into the app.
    if (context.mounted) Navigator.of(context).popUntil((r) => r.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final name = user?.isAnonymous == true
        ? 'Guest'
        : (user?.displayName?.isNotEmpty == true
            ? user!.displayName!
            : (user?.email ?? 'Player'));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Bluff Master'),
        actions: [
          IconButton(
            tooltip: 'Profile',
            icon: const Icon(Icons.account_circle),
            onPressed: () => Navigator.pushNamed(context, '/profile'),
          ),
          IconButton(
            tooltip: 'Logout',
            icon: const Icon(Icons.logout),
            onPressed: () => _logout(context),
          ),
        ],
      ),
      body: ResponsiveBody(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.theater_comedy, size: 90, color: kPrimary),
              const SizedBox(height: 16),
              Text('Welcome, $name',
                  style: const TextStyle(
                      fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
                  textAlign: TextAlign.center),
              const SizedBox(height: 8),
              const Text('Create a room or join friends with a code',
                  style: TextStyle(color: Colors.grey), textAlign: TextAlign.center),
              const SizedBox(height: 40),
              ElevatedButton.icon(
                icon: const Icon(Icons.meeting_room),
                label: const Text('Create / Join Room', style: TextStyle(fontSize: 17)),
                onPressed: () => Navigator.pushNamed(context, '/lobby'),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                icon: const Icon(Icons.bar_chart),
                label: const Text('My Stats & History', style: TextStyle(fontSize: 17)),
                onPressed: () => Navigator.pushNamed(context, '/profile'),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                icon: const Icon(Icons.leaderboard),
                label: const Text('Leaderboard', style: TextStyle(fontSize: 17)),
                onPressed: () => Navigator.pushNamed(context, '/leaderboard'),
              ),
            ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
