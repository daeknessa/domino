import 'dart:math';

import '../models/domino.dart';
import '../models/game_state.dart';
import '../models/player.dart';

class DominoGameEngine {
  static const int maxPip = 6;
  static const int initialHandSize = 7;

  /// Generates the standard 28 dominoes.
  static List<Domino> generateBones() {
    final List<Domino> bones = [];
    for (int i = 0; i <= maxPip; i++) {
      for (int j = i; j <= maxPip; j++) {
        bones.add(Domino(val1: i, val2: j, id: '\${i}_\$j'));
      }
    }
    return bones;
  }

  /// Starts a new game given a host and an opponent (or AI).
  static GameState startNewGame({
    required String gameId,
    required GameMode mode,
    required Player host,
    required Player opponent,
  }) {
    final bones = generateBones();
    bones.shuffle(Random());

    final hostHand = bones.sublist(0, initialHandSize);
    final opponentHand = bones.sublist(initialHandSize, initialHandSize * 2);
    final boneyard = bones.sublist(initialHandSize * 2);

    final updatedHost = host.copyWith(hand: hostHand);
    final updatedOpponent = opponent.copyWith(hand: opponentHand);
    final players = [updatedHost, updatedOpponent];

    // Determine who goes first based on highest double.
    String firstPlayerId = _determineFirstPlayer(players);

    return GameState(
      id: gameId,
      mode: mode,
      status: GameStatus.playing,
      players: players,
      boneyard: boneyard,
      currentPlayerId: firstPlayerId,
    );
  }

  static String _determineFirstPlayer(List<Player> players) {
    int maxDoubleValue = -1;
    String firstPlayerId = players.first.id;

    for (var player in players) {
      for (var domino in player.hand) {
        if (domino.isDouble && domino.val1 > maxDoubleValue) {
          maxDoubleValue = domino.val1;
          firstPlayerId = player.id;
        }
      }
    }

    if (maxDoubleValue == -1) {
      // Fallback if no doubles: heaviest tile
      int maxPips = -1;
      for (var player in players) {
        for (var domino in player.hand) {
          if (domino.totalPips > maxPips) {
            maxPips = domino.totalPips;
            firstPlayerId = player.id;
          }
        }
      }
    }

    return firstPlayerId;
  }

  /// Checks if a domino can be played on the current board.
  static bool canPlay(GameState state, Domino domino) {
    if (state.board.isEmpty) return true;
    return domino.contains(state.headValue!) || domino.contains(state.tailValue!);
  }

  /// Returns true if a player has at least one valid move.
  static bool hasValidMove(GameState state, String playerId) {
    final player = state.players.firstWhere((p) => p.id == playerId);
    for (var domino in player.hand) {
      if (canPlay(state, domino)) return true;
    }
    return false;
  }

  /// Plays a domino on a specified side (if applicable).
  /// [onHead] indicates if it should be attached to the headValue end.
  static GameState playDomino(GameState state, Domino domino, {bool onHead = true}) {
    if (!canPlay(state, domino)) throw Exception('Invalid move');

    final playerIndex = state.players.indexWhere((p) => p.id == state.currentPlayerId);
    final player = state.players[playerIndex];

    final updatedHand = List<Domino>.from(player.hand)..remove(domino);
    final updatedPlayer = player.copyWith(hand: updatedHand);

    final updatedPlayers = List<Player>.from(state.players);
    updatedPlayers[playerIndex] = updatedPlayer;

    final updatedBoard = List<Domino>.from(state.board)..add(domino);

    int? newHead = state.headValue;
    int? newTail = state.tailValue;

    if (state.board.isEmpty) {
      newHead = domino.val1;
      newTail = domino.val2;
    } else {
      if (onHead && domino.contains(state.headValue!)) {
        newHead = domino.getOtherValue(state.headValue!);
      } else if (!onHead && domino.contains(state.tailValue!)) {
        newTail = domino.getOtherValue(state.tailValue!);
      } else if (domino.contains(state.headValue!)) {
        newHead = domino.getOtherValue(state.headValue!);
      } else if (domino.contains(state.tailValue!)) {
        newTail = domino.getOtherValue(state.tailValue!);
      } else {
        throw Exception('Invalid move logic error');
      }
    }

    GameState newState = state.copyWith(
      board: updatedBoard,
      players: updatedPlayers,
      headValue: newHead,
      tailValue: newTail,
    );

    // Check Win Condition (Domino)
    if (updatedHand.isEmpty) {
      return newState.copyWith(winnerId: player.id, status: GameStatus.finished);
    }

    return _advanceTurn(newState);
  }

  /// Draws a domino from the boneyard for the current player.
  static GameState drawDomino(GameState state) {
    if (state.mode == GameMode.block || state.boneyard.isEmpty) {
      throw Exception('Cannot draw');
    }

    final playerIndex = state.players.indexWhere((p) => p.id == state.currentPlayerId);
    final player = state.players[playerIndex];

    final domino = state.boneyard.first;
    final updatedBoneyard = List<Domino>.from(state.boneyard)..removeAt(0);

    final updatedHand = List<Domino>.from(player.hand)..add(domino);
    final updatedPlayer = player.copyWith(hand: updatedHand);

    final updatedPlayers = List<Player>.from(state.players);
    updatedPlayers[playerIndex] = updatedPlayer;

    return state.copyWith(
      boneyard: updatedBoneyard,
      players: updatedPlayers,
    );
  }

  /// Passes the turn when the player has no moves.
  static GameState passTurn(GameState state) {
    return _advanceTurn(state);
  }

  static GameState _advanceTurn(GameState state) {
    final nextPlayerIndex = (state.players.indexWhere((p) => p.id == state.currentPlayerId) + 1) % state.players.length;
    final nextPlayerId = state.players[nextPlayerIndex].id;

    // Check for blocked game (both players cannot move and boneyard is empty/block mode)
    final bool p1CanMove = hasValidMove(state, state.players[0].id) || (state.mode == GameMode.draw && state.boneyard.isNotEmpty);
    final bool p2CanMove = hasValidMove(state, state.players[1].id) || (state.mode == GameMode.draw && state.boneyard.isNotEmpty);

    if (!p1CanMove && !p2CanMove) {
      // Game is blocked
      int p1Points = _calculatePips(state.players[0].hand);
      int p2Points = _calculatePips(state.players[1].hand);

      String? winnerId;
      if (p1Points < p2Points) {
        winnerId = state.players[0].id;
      } else if (p2Points < p1Points) {
        winnerId = state.players[1].id;
      }
      // If tie, winnerId remains null (draw game)

      return state.copyWith(
        status: GameStatus.finished,
        isBlocked: true,
        winnerId: winnerId,
        clearWinnerId: winnerId == null,
      );
    }

    return state.copyWith(currentPlayerId: nextPlayerId);
  }

  static int _calculatePips(List<Domino> hand) {
    int total = 0;
    for (var d in hand) {
      total += d.totalPips;
    }
    return total;
  }
}
