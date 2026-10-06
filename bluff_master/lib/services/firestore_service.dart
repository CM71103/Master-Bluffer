import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// All Firestore access lives here.
///   rooms/{code}                    - room created / joined records
///   users/{uid}                     - stats (gamesPlayed, wins, imposterWins)
///   users/{uid}/games/{autoId}      - one document per finished game
class FirestoreService {
  FirestoreService._();
  static final FirestoreService instance = FirestoreService._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  String? lastRoomSaveError;

  DocumentReference<Map<String, dynamic>>? get _userDoc =>
      _uid == null ? null : _db.collection('users').doc(_uid);

  /// Saves the room booking. Returns false if Firestore rejected the write.
  Future<bool> saveRoom({
    required String code,
    required String playerName,
    required bool isHost,
  }) async {
    lastRoomSaveError = null;
    final uid = _uid;
    if (uid == null) {
      lastRoomSaveError = 'Sign in before saving a room.';
      return false;
    }
    try {
      final room = _db.collection('rooms').doc(code);
      await _db.runTransaction((transaction) async {
        final snapshot = await transaction.get(room);
        final previous = snapshot.data() ?? {};
        final existing = previous['members'] as List<dynamic>? ?? [];
        // Rejoining from another tab must not duplicate the user's membership.
        final members = existing
            .where((member) => member is Map && member['uid'] != uid)
            .toList()
          ..add({'uid': uid, 'name': playerName});
        transaction.set(room, {
          'code': code,
          if (isHost) 'hostUid': uid,
          if (isHost) 'hostName': playerName,
          if (!snapshot.exists) 'createdAt': FieldValue.serverTimestamp(),
          'members': members,
          'playerCount': members.length,
          'lastActivity': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      });
      return true;
    } on FirebaseException catch (e) {
      debugPrint('Firestore room save failed: ${e.code}: ${e.message}');
      lastRoomSaveError = e.code == 'permission-denied'
          ? 'Permission denied. Check Firestore rules for signed-in users.'
          : 'Firestore error: ${e.code}';
      return false;
    } catch (e) {
      debugPrint('Firestore room save failed: $e');
      lastRoomSaveError = 'Could not save room. Check the app logs and network.';
      return false;
    }
  }

  /// Removes the current user's membership from a room on leaving.
  Future<void> leaveRoom(String code) async {
    final uid = _uid;
    if (uid == null) return;
    try {
      final room = _db.collection('rooms').doc(code);
      await _db.runTransaction((transaction) async {
        final snapshot = await transaction.get(room);
        if (!snapshot.exists) return;
        final data = snapshot.data() ?? {};
        final members = (data['members'] as List<dynamic>? ?? [])
            .where((member) => member is Map && member['uid'] != uid)
            .toList();
        if (members.length == (data['members'] as List<dynamic>? ?? []).length) return;
        transaction.update(room, {
          'members': members,
          'playerCount': members.length,
          'lastActivity': FieldValue.serverTimestamp(),
        });
      });
    } catch (e) {
      debugPrint('Firestore room leave failed: $e');
    }
  }

  /// Saves a finished game for the current user and updates their stats.
  Future<void> saveGameResult({
    required String roomCode,
    required bool wasImposter,
    required bool won,
    required String imposterName,
    required String teamWord,
    required String imposterWord,
  }) async {
    final user = _userDoc;
    if (user == null) return;
    try {
      final batch = _db.batch();
      batch.set(user.collection('games').doc(), {
        'roomCode': roomCode,
        'wasImposter': wasImposter,
        'won': won,
        'imposterName': imposterName,
        'teamWord': teamWord,
        'imposterWord': imposterWord,
        'playedAt': FieldValue.serverTimestamp(),
      });
      batch.set(user, {
        'gamesPlayed': FieldValue.increment(1),
        'wins': FieldValue.increment(won ? 1 : 0),
        'imposterWins': FieldValue.increment(wasImposter && won ? 1 : 0),
      }, SetOptions(merge: true));
      await batch.commit();
    } catch (e) {
      debugPrint('Firestore game result save failed: $e');
      rethrow;
    }
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>>? statsStream() =>
      _userDoc?.snapshots();

  Stream<QuerySnapshot<Map<String, dynamic>>>? historyStream() => _userDoc
      ?.collection('games')
      .orderBy('playedAt', descending: true)
      .limit(50)
      .snapshots();

  /// Removes a saved game and its stats using the values actually stored.
  Future<void> deleteGame(String gameId) async {
    final user = _userDoc;
    if (user == null) return;
    final game = user.collection('games').doc(gameId);
    await _db.runTransaction((transaction) async {
      final saved = await transaction.get(game);
      if (!saved.exists) return; // Never decrement twice for the same game.
      final data = saved.data() ?? {};
      final won = data['won'] == true;
      final wasImposter = data['wasImposter'] == true;
      transaction.delete(game);
      transaction.set(user, {
        'gamesPlayed': FieldValue.increment(-1),
        'wins': FieldValue.increment(won ? -1 : 0),
        'imposterWins': FieldValue.increment(wasImposter && won ? -1 : 0),
      }, SetOptions(merge: true));
    });
  }
}
