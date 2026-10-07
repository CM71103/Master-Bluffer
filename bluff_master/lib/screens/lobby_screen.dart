import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/socket_service.dart';
import '../services/firestore_service.dart';
import '../services/notification_service.dart';
import '../theme.dart';

class LobbyScreen extends StatefulWidget {
  const LobbyScreen({super.key});

  @override
  State<LobbyScreen> createState() => _LobbyScreenState();
}

class _LobbyScreenState extends State<LobbyScreen> {
  final SocketService _socket = SocketService.instance;
  final TextEditingController _codeController = TextEditingController();

  String? _roomCode;
  List<dynamic> _players = [];
  bool _isHost = false;
  bool _joined = false;
  bool _connecting = false;
  String? _error;
  Timer? _roomRequestTimer;

  String get _playerName {
    final user = FirebaseAuth.instance.currentUser;
    if (user?.isAnonymous == true) return 'Guest';
    final n = user?.displayName;
    return (n != null && n.isNotEmpty ? n : (user?.email ?? 'Player')).toString();
  }

  @override
  void initState() {
    super.initState();
    _socket.connect();
    _setupListeners();
  }

  void _setupListeners() {
    _socket.onRoomCreated((data) {
      if (!mounted) return;
      _roomRequestTimer?.cancel();
      setState(() {
        _roomCode = data['code'] as String;
        _isHost = true;
        _joined = true;
        _players = (data['players'] as List).toList();
        _error = null;
        _connecting = false;
      });
      _socket.roomCode = _roomCode;
      _confirmRoom(isHost: true);
    });

    _socket.onRoomJoined((data) {
      if (!mounted) return;
      _roomRequestTimer?.cancel();
      setState(() {
        _roomCode = data['code'] as String;
        _isHost = data['hostId'] == _socket.playerId;
        _joined = true;
        _players = (data['players'] as List).toList();
        _error = null;
        _connecting = false;
      });
      _socket.roomCode = _roomCode;
      _confirmRoom(isHost: false);
    });

    _socket.onPlayersUpdated((data) {
      if (!mounted) return;
      setState(() => _players = data);
    });

    _socket.onHostChanged((data) {
      if (!mounted) return;
      setState(() => _isHost = data['hostId'] == _socket.playerId);
    });

    _socket.onError((data) {
      if (!mounted) return;
      _roomRequestTimer?.cancel();
      setState(() {
        _connecting = false;
        _error = (data['message'] as String?) ?? 'Something went wrong';
      });
    });

    // The server sends the role just before the phase change, so listen for it
    // here; SocketService remembers it for the game screen.
    _socket.onRoleAssigned((_) {});

    _socket.onPhaseChange((data) {
      if (!mounted) return;
      if (data['phase'] == 'word-reveal') {
        _socket.players = _players;
        NotificationService.instance
            .show('Game started!', 'Room $_roomCode - check your secret role.');
        Navigator.pushNamed(context, '/game').then((_) {
          // The game screen replaced our socket listeners; restore them.
          if (!mounted) return;
          _setupListeners();
          final latest = _socket.currentPlayers;
          if (latest != null) setState(() => _players = latest);
        });
      }
    });
  }

  /// Saves the room to Firebase, then shows the confirmation message and a
  /// device notification with the room details.
  Future<void> _confirmRoom({required bool isHost}) async {
    final code = _roomCode!;
    final saved = await FirestoreService.instance.saveRoom(
      code: code,
      playerName: _playerName,
      isHost: isHost,
    );
    NotificationService.instance.show(
      isHost ? 'Room created' : 'Room joined',
      'Room $code is ready. Share the code with your friends!',
    );
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: kCard,
        icon: const Icon(Icons.check_circle, color: Colors.green, size: 48),
        title: Text(isHost ? 'Room Created!' : 'Room Joined!'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _detail('Room code', code),
            _detail('Role', isHost ? 'Host' : 'Player'),
            _detail('Playing as', _playerName),
            _detail('Players in room', '${_players.length}'),
            _detail('Saved to cloud', saved ? 'Yes' : 'No'),
            if (!saved)
              Text(
                FirestoreService.instance.lastRoomSaveError ?? 'Unknown save error',
                style: const TextStyle(color: Colors.orangeAccent),
              ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK')),
        ],
      ),
    );
  }

  Widget _detail(String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(k, style: const TextStyle(color: Colors.grey)),
            const SizedBox(width: 16),
            Flexible(
                child: Text(v,
                    textAlign: TextAlign.right,
                    style: const TextStyle(fontWeight: FontWeight.bold))),
          ],
        ),
      );

  Future<void> _createRoom() async {
    if (!await _connectForRoom()) return;
    _beginRoomRequest('Creating room...');
    _socket.createRoom(_playerName, uid: FirebaseAuth.instance.currentUser?.uid);
  }

  Future<void> _joinRoom() async {
    final code = _codeController.text.trim().toUpperCase();
    if (code.length != 6) {
      setState(() => _error = 'Room code must be 6 characters');
      return;
    }
    if (!await _connectForRoom()) return;
    _beginRoomRequest('Joining room...');
    _socket.joinRoom(code, _playerName, uid: FirebaseAuth.instance.currentUser?.uid);
  }

  void _beginRoomRequest(String status) {
    setState(() => _error = status);
    _roomRequestTimer?.cancel();
    _roomRequestTimer = Timer(const Duration(seconds: 20), () {
      if (!mounted || !_connecting) return;
      setState(() {
        _connecting = false;
        _error = 'The server did not confirm the room within 20 seconds. '
            'Please try again.';
      });
    });
  }

  Future<bool> _connectForRoom() async {
    if (_connecting) return false;
    setState(() {
      _connecting = true;
      _error = 'Connecting to server...';
    });
    final connected = await _socket.waitForConnection();
    if (!mounted) return false;
    setState(() {
      _connecting = connected;
      _error = connected
          ? null
          : 'Cannot reach game server: ${_socket.lastConnectionError ?? 'connection timed out'}. Check internet and try again.';
    });
    return connected;
  }

  void _toggleReady() => _socket.toggleReady();

  void _startGame() => _socket.startGame();

  @override
  void dispose() {
    _roomRequestTimer?.cancel();
    // Leaving the lobby screen means leaving the room.
    if (_joined) {
      final code = _socket.roomCode;
      if (code != null) FirestoreService.instance.leaveRoom(code);
      _socket.leaveRoom();
    }
    _codeController.dispose();
    super.dispose();
  }

  bool get _iAmReady =>
      _players.any((p) => p['id'] == _socket.playerId && p['isReady'] == true);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Lobby'),
        actions: [
          if (_joined)
            TextButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.exit_to_app, color: Colors.white70),
              label: const Text('Leave', style: TextStyle(color: Colors.white70)),
            ),
        ],
      ),
      body: ResponsiveBody(
        child: ListView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.all(16),
          children: [
              if (!_joined)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Text('Playing as: $_playerName',
                            style: const TextStyle(color: Colors.grey)),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _codeController,
                                textCapitalization: TextCapitalization.characters,
                                maxLength: 6,
                                inputFormatters: [
                                  FilteringTextInputFormatter.allow(RegExp('[a-zA-Z]'))
                                ],
                                style: const TextStyle(
                                    color: Colors.white, letterSpacing: 4),
                                decoration: const InputDecoration(
                                  labelText: 'Room Code',
                                  counterText: '',
                                  prefixIcon: Icon(Icons.key),
                                ),
                                onSubmitted: (_) => _joinRoom(),
                              ),
                            ),
                            const SizedBox(width: 8),
                            SizedBox(
                              width: 90,
                              child: ElevatedButton(
                                  onPressed: _connecting ? null : _joinRoom, child: const Text('Join')),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        OutlinedButton(
                            onPressed: _connecting ? null : _createRoom,
                            child: const Text('Create New Room')),
                        if (_error != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                             child: Text(_error!,
                                 style: TextStyle(color: _connecting
                                     ? Colors.white70 : Colors.redAccent)),
                          ),
                      ],
                    ),
                  ),
                ),
              if (_roomCode != null) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.deepPurple.shade900,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      const Text('Room Code', style: TextStyle(color: Colors.grey)),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(_roomCode!,
                              style: const TextStyle(
                                  fontSize: 32,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                  letterSpacing: 6)),
                          IconButton(
                            tooltip: 'Copy code',
                            icon: const Icon(Icons.copy, color: Colors.white70),
                            onPressed: () {
                              Clipboard.setData(ClipboardData(text: _roomCode!));
                              ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Room code copied')));
                            },
                          ),
                        ],
                      ),
                      Text('Players (${_players.length}/10) - share this code with friends',
                          style: const TextStyle(color: Colors.grey, fontSize: 12)),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                ...List.generate(_players.length, (index) {
                      final player = _players[index];
                      final isMe = player['id'] == _socket.playerId;
                      final isReady = player['isReady'] == true;
                      return Card(
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: isReady ? Colors.green : Colors.grey,
                            child: Text((player['name'] as String)[0].toUpperCase(),
                                style: const TextStyle(color: Colors.white)),
                          ),
                          title: Text('${player['name']}${isMe ? ' (You)' : ''}',
                              style: const TextStyle(color: Colors.white)),
                          subtitle: Text(isReady ? 'Ready' : 'Not Ready',
                              style: TextStyle(
                                  color: isReady ? Colors.green : Colors.grey)),
                        ),
                      );
                    }),
                Padding(
                  padding: const EdgeInsets.only(bottom: 16, top: 8),
                  child: Column(
                    children: [
                      OutlinedButton.icon(
                        icon: Icon(_iAmReady ? Icons.check_circle : Icons.circle_outlined),
                        label: Text(_iAmReady ? 'Not Ready' : "I'm Ready"),
                        onPressed: _toggleReady,
                      ),
                      if (_isHost)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: ElevatedButton(
                            onPressed: _players.length >= 2 ? _startGame : null,
                            child: const Text('Start Game',
                                style: TextStyle(fontSize: 18)),
                          ),
                        )
                      else
                        const Padding(
                          padding: EdgeInsets.only(top: 12),
                          child: Text('Waiting for host to start...',
                              style: TextStyle(color: Colors.grey)),
                        ),
                      if (_error != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(_error!,
                              style: const TextStyle(color: Colors.redAccent)),
                        ),
                    ],
                  ),
                ),
              ],
          ],
        ),
      ),
    );
  }
}
