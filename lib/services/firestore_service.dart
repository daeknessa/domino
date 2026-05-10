import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/game_state.dart';
import '../models/player.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // -- USERS --

  /// Streams the list of online users (excluding the current user).
  Stream<List<Player>> streamOnlineUsers(String currentUserId) {
    return _db
        .collection('users')
        .where('isOnline', isEqualTo: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .where((doc) => doc.id != currentUserId)
            .map((doc) => Player(id: doc.id, name: doc.data()['name'] ?? 'Unknown'))
            .toList());
  }

  /// Sets user status to online/offline.
  Future<void> updateUserStatus(String userId, String name, bool isOnline) async {
    await _db.collection('users').doc(userId).set({
      'name': name,
      'isOnline': isOnline,
      'lastSeen': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  // -- MATCHMAKING & GAMES --

  /// Creates a new game lobby in waiting state.
  Future<String> hostGame(GameMode mode, Player host) async {
    final docRef = await _db.collection('games').add({
      'mode': mode.index,
      'status': GameStatus.waiting.index,
      'hostId': host.id,
      'hostName': host.name,
      'createdAt': FieldValue.serverTimestamp(),
    });
    return docRef.id;
  }

  /// Joins an existing game.
  Future<void> joinGame(String gameId, Player opponent) async {
    await _db.collection('games').doc(gameId).update({
      'opponentId': opponent.id,
      'opponentName': opponent.name,
      'status': GameStatus.playing.index,
    });
  }

  /// Streams active waiting games.
  Stream<List<Map<String, dynamic>>> streamWaitingGames() {
    return _db
        .collection('games')
        .where('status', isEqualTo: GameStatus.waiting.index)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) {
              final data = doc.data();
              data['id'] = doc.id;
              return data;
            }).toList());
  }

  /// Initializes the actual GameState document once both players are ready.
  Future<void> updateGameState(GameState state) async {
    await _db.collection('games').doc(state.id).set(
          state.toJson(),
          SetOptions(merge: true),
        );
  }

  /// Streams the actual GameState.
  Stream<GameState> streamGameState(String gameId) {
    return _db.collection('games').doc(gameId).snapshots().map((doc) {
      if (!doc.exists) throw Exception('Game not found');
      return GameState.fromJson(doc.data()!..['id'] = doc.id);
    });
  }
}
