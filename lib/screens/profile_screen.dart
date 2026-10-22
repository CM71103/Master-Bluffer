import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/firestore_service.dart';
import '../theme.dart';

/// Stats and saved game history, read live from Firestore.
/// Swiping a history entry (or tapping the bin) cancels/deletes it.
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final name = user?.isAnonymous == true
        ? 'Guest'
        : (user?.displayName?.isNotEmpty == true
            ? user!.displayName!
            : (user?.email ?? 'Player'));
    final fs = FirestoreService.instance;

    return Scaffold(
      appBar: AppBar(title: const Text('Profile & Stats')),
      body: ResponsiveBody(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
              const CircleAvatar(
                  radius: 36,
                  backgroundColor: kPrimary,
                  child: Icon(Icons.person, size: 40, color: Colors.white)),
              const SizedBox(height: 8),
              Text(name,
                  style: const TextStyle(
                      fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
              const SizedBox(height: 16),
              StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                stream: fs.statsStream(),
                builder: (context, snap) {
                  if (snap.hasError) {
                    return const Card(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Text('Could not load stats. Check Firestore access.'),
                      ),
                    );
                  }
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final d = snap.data?.data() ?? {};
                  final played = (d['gamesPlayed'] ?? 0) as int;
                  final wins = (d['wins'] ?? 0) as int;
                  final imp = (d['imposterWins'] ?? 0) as int;
                  final rate = played == 0 ? 0 : (wins * 100 / played).round();
                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(children: [
                        _statRow('Games Played', '$played'),
                        _statRow('Wins', '$wins'),
                        _statRow('Imposter Wins', '$imp'),
                        _statRow('Win Rate', '$rate%'),
                      ]),
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text('Game History',
                    style: TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
              ),
              const SizedBox(height: 8),
              StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: fs.historyStream(),
                  builder: (context, snap) {
                    if (snap.hasError) {
                      return const Center(
                          child: Text('Could not load history.',
                              style: TextStyle(color: Colors.grey)));
                    }
                    if (!snap.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final docs = snap.data!.docs;
                    if (docs.isEmpty) {
                      return const Center(
                          child: Text('No games yet. Go play one!',
                              style: TextStyle(color: Colors.grey)));
                    }
                    return Column(
                      children: List.generate(docs.length, (i) {
                        final doc = docs[i];
                        final g = doc.data();
                        final won = g['won'] == true;
                        final wasImp = g['wasImposter'] == true;
                        final ts = (g['playedAt'] as Timestamp?)?.toDate();
                        return Dismissible(
                          key: ValueKey(doc.id),
                          direction: DismissDirection.endToStart,
                          background: Container(
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.only(right: 20),
                            color: Colors.red.shade800,
                            child: const Icon(Icons.delete, color: Colors.white),
                          ),
                          onDismissed: (_) => fs.deleteGame(doc.id),
                          child: Card(
                            child: ListTile(
                              leading: Icon(
                                  won ? Icons.emoji_events : Icons.close,
                                  color: won ? Colors.green : Colors.red),
                              title: Text(
                                  '${won ? 'Won' : 'Lost'} as ${wasImp ? 'Imposter' : 'Team'}',
                                  style: const TextStyle(color: Colors.white)),
                              subtitle: Text(
                                  'Room ${g['roomCode']}  |  Word: ${g['teamWord']}'
                                  '${ts != null ? '\n${_fmt(ts)}' : ''}',
                                  style: const TextStyle(color: Colors.grey)),
                              isThreeLine: ts != null,
                              trailing: IconButton(
                                icon: const Icon(Icons.delete_outline, color: Colors.grey),
                                onPressed: () => fs.deleteGame(doc.id),
                              ),
                            ),
                          ),
                        );
                      }),
                    );
                  },
                ),
          ],
        ),
      ),
    );
  }

  static Widget _statRow(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(color: Colors.grey)),
            Text(value,
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
      );

  static String _fmt(DateTime d) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.day)}-${two(d.month)}-${d.year} ${two(d.hour)}:${two(d.minute)}';
  }
}
