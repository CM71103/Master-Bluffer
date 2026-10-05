import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// All Firestore access lives here.
///   rooms/{code}                    - room created / joined records
///   users/{uid}                     - stats (gamesPlayed, wins, imposterWins)
///   users/{uid}/games/{autoId}      - one document per finished game
class FirestoreService {
  FirestoreService._();
  static final FirestoreService instance = FirestoreService._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  DocumentReference<Map<String, dynamic>>? get _userDoc =>
      _uid == null ? null : _db.collection('users').doc(_uid);

  /// Saves the room booking. Returns false if Firestore rejected the write.
  Future<bool> saveRoom({
    required String code,
    required String playerName,
    required bool isHost,
    required int playerCount,
  }) async {
    final uid = _uid;
    if (uid == null) return false;
    try {
      await _db.collection('rooms').doc(code).set({
        'code': code,
        if (isHost) 'hostUid': uid,
        if (isHost) 'hostName': playerName,
        if (isHost) 'createdAt': FieldValue.serverTimestamp(),
        'members': FieldValue.arrayUnion([
          {'uid': uid, 'name': playerName},
        ]),
        'playerCount': playerCount,
        'lastActivity': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      return true;
    } catch (_) {
      return false;
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
    } catch (_) {}
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>>? statsStream() =>
      _userDoc?.snapshots();

  Stream<QuerySnapshot<Map<String, dynamic>>>? historyStream() => _userDoc
      ?.collection('games')
      .orderBy('playedAt', descending: true)
      .limit(50)
      .snapshots();

  /// "Cancel" a saved game record and take it out of the stats.
  Future<void> deleteGame(String gameId,
      {required bool won, required bool wasImposter}) async {
    final user = _userDoc;
    if (user == null) return;
    final batch = _db.batch();
    batch.delete(user.collection('games').doc(gameId));
    batch.set(user, {
      'gamesPlayed': FieldValue.increment(-1),
      'wins': FieldValue.increment(won ? -1 : 0),
      'imposterWins': FieldValue.increment(wasImposter && won ? -1 : 0),
    }, SetOptions(merge: true));
    await batch.commit();
  }
}
