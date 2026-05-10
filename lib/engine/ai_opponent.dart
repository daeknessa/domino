import '../engine/game_engine.dart';
import '../models/domino.dart';
import '../models/game_state.dart';
import '../models/player.dart';

class AIOpponent {
  static const String aiId = 'ai_bot';
  static const String aiName = 'AI Opponent';

  static Player get aiPlayer => const Player(id: aiId, name: aiName);

  /// Analyzes the game state and returns the next move for the AI.
  /// If [Domino] is returned, the AI will play it.
  /// If it returns null, the AI needs to draw or pass.
  static Future<Domino?> calculateBestMove(GameState state) async {
    // Add a small delay for realism (1.5 - 3 seconds)
    final delay = Duration(milliseconds: 1500 + (DateTime.now().millisecond % 1500));
    await Future.delayed(delay);

    final ai = state.players.firstWhere((p) => p.id == aiId);
    final hand = ai.hand;

    if (state.board.isEmpty) {
      // First move: play highest double or heaviest tile
      Domino? bestMove;
      int maxPips = -1;

      for (var domino in hand) {
        if (domino.isDouble && domino.totalPips > maxPips) {
          bestMove = domino;
          maxPips = domino.totalPips;
        }
      }

      if (bestMove == null) {
        for (var domino in hand) {
          if (domino.totalPips > maxPips) {
            bestMove = domino;
            maxPips = domino.totalPips;
          }
        }
      }
      return bestMove;
    }

    // Find all playable tiles
    final playableTiles = hand.where((d) => DominoGameEngine.canPlay(state, d)).toList();

    if (playableTiles.isEmpty) {
      return null; // AI must draw or pass
    }

    // Priority 1: Play doubles
    final doubles = playableTiles.where((d) => d.isDouble).toList();
    if (doubles.isNotEmpty) {
      // Play the highest double
      doubles.sort((a, b) => b.totalPips.compareTo(a.totalPips));
      return doubles.first;
    }

    // Priority 2: Play from the longest suit in hand
    // Count occurrences of each value in the AI's hand
    Map<int, int> suitCounts = {};
    for (var domino in hand) {
      suitCounts[domino.val1] = (suitCounts[domino.val1] ?? 0) + 1;
      if (!domino.isDouble) {
        suitCounts[domino.val2] = (suitCounts[domino.val2] ?? 0) + 1;
      }
    }

    // Find the playable tile that helps reduce the longest suit
    playableTiles.sort((a, b) {
      int scoreA = (suitCounts[a.val1] ?? 0) + (suitCounts[a.val2] ?? 0);
      int scoreB = (suitCounts[b.val1] ?? 0) + (suitCounts[b.val2] ?? 0);

      // Secondary sort: highest pip count
      if (scoreA == scoreB) {
        return b.totalPips.compareTo(a.totalPips);
      }
      return scoreB.compareTo(scoreA); // Descending order
    });

    return playableTiles.first;
  }
}
