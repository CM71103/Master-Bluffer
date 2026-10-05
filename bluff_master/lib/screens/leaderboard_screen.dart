import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/api_service.dart';
import '../theme.dart';

/// Three tabs backed by MongoDB (through the Node server):
/// leaderboard, my games (with delete) and recent games from everyone.
class LeaderboardScreen extends StatelessWidget {
  const LeaderboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Leaderboard'),
          bottom: const TabBar(tabs: [
            Tab(text: 'Top Players'),
            Tab(text: 'My Games'),
            Tab(text: 'Recent'),
          ]),
        ),
        body: const ResponsiveBody(
          child: TabBarView(children: [
            _TopPlayers(),
            _MyGames(),
            _RecentGames(),
          ]),
        ),
      ),
    );
  }
}

/// Loads a list once, shows spinner / error / empty states, supports refresh.
class _Loader extends StatefulWidget {
  final Future<List<Map<String, dynamic>>> Function() load;
  final String emptyText;
  final Widget Function(
      BuildContext, List<Map<String, dynamic>>, Future<void> Function()) builder;
  const _Loader(
      {required this.load, required this.emptyText, required this.builder});

  @override
  State<_Loader> createState() => _LoaderState();
}

class _LoaderState extends State<_Loader> {
  late Future<List<Map<String, dynamic>>> _future = widget.load();

  Future<void> _refresh() async {
    setState(() => _future = widget.load());
    await _future.catchError((_) => <Map<String, dynamic>>[]);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.cloud_off, size: 48, color: Colors.grey),
                const SizedBox(height: 8),
                const Text('Could not reach the server.',
                    style: TextStyle(color: Colors.grey)),
                TextButton(onPressed: _refresh, child: const Text('Retry')),
              ],
            ),
          );
        }
        final items = snap.data ?? [];
        if (items.isEmpty) {
          return Center(
              child: Text(widget.emptyText,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.grey)));
        }
        return RefreshIndicator(
            onRefresh: _refresh, child: widget.builder(context, items, _refresh));
      },
    );
  }
}

String _date(dynamic iso) {
  final d = DateTime.tryParse('$iso')?.toLocal();
  if (d == null) return '';
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(d.day)}-${two(d.month)}-${d.year} ${two(d.hour)}:${two(d.minute)}';
}

class _TopPlayers extends StatelessWidget {
  const _TopPlayers();

  @override
  Widget build(BuildContext context) {
    final me = FirebaseAuth.instance.currentUser?.uid;
    return _Loader(
      load: ApiService.instance.leaderboard,
      emptyText: 'No games recorded yet.\nPlay a round to appear here!',
      builder: (context, items, _) => ListView.builder(
        padding: const EdgeInsets.all(16),
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: items.length,
        itemBuilder: (context, i) {
          final p = items[i];
          final isMe = p['uid'] == me;
          final rank = i + 1;
          final medal = rank == 1
              ? Colors.amber
              : rank == 2
                  ? Colors.blueGrey.shade200
                  : rank == 3
                      ? Colors.brown.shade300
                      : kPrimary;
          return Card(
            color: isMe ? Colors.deepPurple.shade700 : null,
            child: ListTile(
              leading: CircleAvatar(
                  backgroundColor: medal,
                  child: Text('$rank',
                      style: const TextStyle(
                          color: Colors.black, fontWeight: FontWeight.bold))),
              title: Text('${p['name']}${isMe ? ' (You)' : ''}',
                  style: const TextStyle(color: Colors.white)),
              subtitle: Text('${p['played']} games played',
                  style: const TextStyle(color: Colors.grey)),
              trailing: Text('${p['wins']} wins',
                  style: const TextStyle(
                      color: kAccent, fontWeight: FontWeight.bold, fontSize: 16)),
            ),
          );
        },
      ),
    );
  }
}

class _MyGames extends StatelessWidget {
  const _MyGames();

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    return _Loader(
      load: () => ApiService.instance.myHistory(uid),
      emptyText: 'You have no saved games yet.',
      builder: (context, items, refresh) => ListView.builder(
        padding: const EdgeInsets.all(16),
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: items.length,
        itemBuilder: (context, i) {
          final g = items[i];
          final won = g['won'] == true;
          return Card(
            child: ListTile(
              leading: Icon(won ? Icons.emoji_events : Icons.close,
                  color: won ? Colors.green : Colors.red),
              title: Text(
                  '${won ? 'Won' : 'Lost'} as ${g['wasImposter'] == true ? 'Imposter' : 'Team'}',
                  style: const TextStyle(color: Colors.white)),
              subtitle: Text(
                  'Room ${g['roomCode']}  |  Word: ${g['teamWord']}\n${_date(g['playedAt'])}',
                  style: const TextStyle(color: Colors.grey)),
              isThreeLine: true,
              trailing: IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.grey),
                onPressed: () async {
                  try {
                    await ApiService.instance.deleteGame(g['id'], uid);
                    await refresh();
                  } catch (_) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Could not delete.')));
                    }
                  }
                },
              ),
            ),
          );
        },
      ),
    );
  }
}

class _RecentGames extends StatelessWidget {
  const _RecentGames();

  @override
  Widget build(BuildContext context) {
    return _Loader(
      load: ApiService.instance.recentGames,
      emptyText: 'No games yet.',
      builder: (context, items, _) => ListView.builder(
        padding: const EdgeInsets.all(16),
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: items.length,
        itemBuilder: (context, i) {
          final g = items[i];
          final team = g['winner'] == 'team';
          return Card(
            child: ListTile(
              leading: Icon(team ? Icons.groups : Icons.theater_comedy,
                  color: team ? Colors.green : Colors.red),
              title: Text(team ? 'Team won' : 'Imposter won',
                  style: const TextStyle(color: Colors.white)),
              subtitle: Text(
                  'Imposter: ${g['imposterName']}  |  ${g['playerCount']} players\n${_date(g['playedAt'])}',
                  style: const TextStyle(color: Colors.grey)),
              isThreeLine: true,
            ),
          );
        },
      ),
    );
  }
}
